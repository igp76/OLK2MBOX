#!/usr/bin/env python3
"""Convert a legacy Outlook for Mac 15 profile cache to MBOX files.

Artifact-Version: 2.0.0
Release-Date: 2026-09-07
Stability: Stable
Change-Summary: Adopt the OLK2MBOX product name and output-file naming convention.
SPDX-FileCopyrightText: 2026 igp76
SPDX-License-Identifier: GPL-3.0-or-later

This is an independent, standard-library-only implementation for profiles that
contain Data/Outlook.sqlite and Data/Messages/*.olk15Message files.
"""

from __future__ import annotations

import argparse
import email.policy
import email.utils
import json
import os
import re
import shutil
import sqlite3
import struct
import sys
import time
from dataclasses import dataclass
from email.generator import BytesGenerator
from email.message import EmailMessage, Message
from email.parser import BytesParser
from pathlib import Path
from typing import BinaryIO, Iterable, Iterator, Sequence
from urllib.parse import quote, unquote


VERSION = "2.0.0"
RELEASE_DATE = "2026-09-07"
MAGIC = b"\xd0\x0d\x00\x00"
ENTITY_KIND = 1
BLOCK_KIND = 2
ENTITY_HEADER_SIZE = 40
BLOCK_HEADER_SIZE = 40
MESSAGE_CLASS_ID = 3
CONTENT_HEADERS = {
    "content-type",
    "content-transfer-encoding",
    "content-length",
    "mime-version",
}
INVALID_PATH_CHARS = re.compile(r"[/:\x00]")
HTML_MARKERS = ("<html", "<!doctype html", "<body", "<div", "<table")


class ConversionError(RuntimeError):
    """Raised when an Outlook record cannot be safely converted."""


@dataclass(frozen=True)
class Recipient:
    address: str
    name: str = ""
    recipient_type: int | None = None


@dataclass(frozen=True)
class FolderInfo:
    record_id: int
    parent_id: int
    account_uid: int
    name: str
    special_type: int


@dataclass
class MessageProperties:
    headers: str = ""
    subject: str = ""
    body: str = ""
    html_body: str = ""
    preview: str = ""
    message_id: str = ""
    in_reply_to: str = ""
    references: str = ""
    from_: list[Recipient] | None = None
    to: list[Recipient] | None = None
    cc: list[Recipient] | None = None
    bcc: list[Recipient] | None = None

    def __post_init__(self) -> None:
        self.from_ = self.from_ or []
        self.to = self.to or []
        self.cc = self.cc or []
        self.bcc = self.bcc or []


@dataclass
class ConversionStats:
    messages_seen: int = 0
    messages_written: int = 0
    messages_skipped: int = 0
    attachment_blocks_written: int = 0
    attachment_blocks_missing: int = 0
    attachment_blocks_failed: int = 0
    folders_written: int = 0
    bytes_written: int = 0


def log(message: str, *, quiet: bool = False) -> None:
    if not quiet:
        print(message, file=sys.stderr, flush=True)


def sanitize_component(value: str, fallback: str) -> str:
    """Return a safe, deterministic filesystem component."""
    cleaned = INVALID_PATH_CHARS.sub("_", value).strip()
    cleaned = cleaned.rstrip(".")
    if cleaned in {"", ".", ".."}:
        cleaned = fallback
    return cleaned[:240]


def locate_data_directory(profile_path: Path) -> tuple[Path, Path]:
    """Return (profile_root, data_directory) for a profile or Data path."""
    supplied = profile_path.expanduser().resolve()
    if (supplied / "Outlook.sqlite").is_file() and supplied.name == "Data":
        return supplied.parent, supplied
    data_dir = supplied / "Data"
    if (data_dir / "Outlook.sqlite").is_file():
        return supplied, data_dir
    raise ConversionError(
        f"No Outlook.sqlite database found below profile path: {supplied}"
    )


def open_database(data_dir: Path) -> sqlite3.Connection:
    """Open Outlook.sqlite in read-only mode, retaining WAL visibility."""
    db_path = data_dir / "Outlook.sqlite"
    uri = f"file:{quote(db_path.as_posix(), safe='/')}?mode=ro"
    connection = sqlite3.connect(uri, uri=True)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA query_only = ON")
    connection.execute("PRAGMA busy_timeout = 5000")
    return connection


def validate_database(connection: sqlite3.Connection) -> None:
    required = {"Mail", "Folders", "Blocks", "Mail_OwnedBlocks"}
    found = {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        )
    }
    missing = required - found
    if missing:
        raise ConversionError(
            "Unsupported Outlook database; missing tables: "
            + ", ".join(sorted(missing))
        )


def read_folders(connection: sqlite3.Connection) -> dict[int, FolderInfo]:
    rows = connection.execute(
        """
        SELECT Record_RecordID, Folder_ParentID, Record_AccountUID,
               COALESCE(Folder_Name, ''), Folder_SpecialFolderType
        FROM Folders
        """
    )
    return {
        int(row[0]): FolderInfo(
            record_id=int(row[0]),
            parent_id=int(row[1]),
            account_uid=int(row[2]),
            name=str(row[3]),
            special_type=int(row[4]),
        )
        for row in rows
    }


def _display_folder_name(folder: FolderInfo) -> str:
    if folder.parent_id == -2:
        if folder.account_uid == 0:
            return "On My Computer"
        return f"Exchange Account {folder.record_id}"
    if folder.name.startswith("Placeholder_"):
        placeholder_names = {
            1: "Inbox",
            2: "Outbox",
            3: "Sent Items",
            4: "Drafts",
            5: "Deleted Items",
            6: "Junk Email",
            7: "On My Computer",
        }
        return placeholder_names.get(folder.record_id, f"Folder {folder.record_id}")
    return folder.name or f"Folder {folder.record_id}"


def build_folder_paths(folders: dict[int, FolderInfo]) -> dict[int, Path]:
    """Build safe folder paths while detecting cycles and sibling collisions."""
    safe_names: dict[int, str] = {}
    sibling_names: dict[tuple[int, str], list[int]] = {}
    for folder in folders.values():
        name = sanitize_component(
            _display_folder_name(folder), f"Folder {folder.record_id}"
        )
        safe_names[folder.record_id] = name
        sibling_names.setdefault((folder.parent_id, name.casefold()), []).append(
            folder.record_id
        )
    for ids in sibling_names.values():
        if len(ids) > 1:
            for record_id in ids:
                safe_names[record_id] += f" [{record_id}]"

    paths: dict[int, Path] = {}

    def resolve(record_id: int, active: set[int]) -> Path:
        if record_id in paths:
            return paths[record_id]
        if record_id in active:
            raise ConversionError(f"Folder cycle detected at record {record_id}")
        folder = folders.get(record_id)
        if folder is None:
            result = Path("Recovered") / f"Folder {record_id}"
        elif folder.parent_id in folders:
            result = resolve(folder.parent_id, active | {record_id}) / safe_names[record_id]
        else:
            result = Path(safe_names[record_id])
        paths[record_id] = result
        return result

    for record_id in folders:
        resolve(record_id, set())
    return paths


def folder_message_counts(connection: sqlite3.Connection) -> dict[int, int]:
    return {
        int(row[0]): int(row[1])
        for row in connection.execute(
            "SELECT Record_FolderID, COUNT(*) FROM Mail GROUP BY Record_FolderID"
        )
    }


def descriptor_key(raw: bytes) -> str:
    if len(raw) != 4:
        raise ConversionError("Invalid OLK property descriptor")
    variant = raw[2:4] if raw[2] > 0 else raw[3:4]
    index = raw[0:2] if raw[1] > 0 else raw[0:1]
    return f"{variant.hex().upper()}:{index.hex().upper()}"


def parse_collection(data: bytes) -> dict[str, bytes]:
    """Parse the common OLK tagged collection encoding."""
    if len(data) < 12:
        raise ConversionError("Truncated OLK collection header")
    item_count, header_size, body_size = struct.unpack_from("<3i", data, 0)
    expected_header_size = 12 + item_count * 8
    if item_count < 0 or header_size < expected_header_size or header_size > len(data):
        raise ConversionError("Invalid OLK collection dimensions")
    if body_size < 0 or header_size + body_size > len(data):
        raise ConversionError("Truncated OLK collection body")

    body = memoryview(data)[header_size : header_size + body_size]
    cursor = 0
    result: dict[str, bytes] = {}
    for position in range(item_count):
        offset = 12 + position * 8
        key = descriptor_key(data[offset : offset + 4])
        size = struct.unpack_from("<i", data, offset + 4)[0]
        if size < 0 or cursor + size > len(body):
            raise ConversionError(f"Invalid OLK property length for {key}")
        result[key] = bytes(body[cursor : cursor + size])
        cursor += size
    if cursor > body_size:
        raise ConversionError("OLK property data exceeds collection body")
    return result


def parse_entity_file(path: Path) -> tuple[int, dict[str, bytes]]:
    data = path.read_bytes()
    if len(data) < ENTITY_HEADER_SIZE or data[:4] != MAGIC:
        raise ConversionError(f"Invalid OLK file header: {path}")
    kind = struct.unpack_from("<i", data, 8)[0]
    if kind != ENTITY_KIND:
        raise ConversionError(f"Expected OLK entity file: {path}")
    class_id = struct.unpack_from("<i", data, 16)[0]
    return class_id, parse_collection(data[ENTITY_HEADER_SIZE:])


def read_block_payload(path: Path) -> tuple[str, bytes]:
    data = path.read_bytes()
    if len(data) < BLOCK_HEADER_SIZE or data[:4] != MAGIC:
        raise ConversionError(f"Invalid OLK block header: {path}")
    kind = struct.unpack_from("<i", data, 8)[0]
    if kind != BLOCK_KIND:
        raise ConversionError(f"Expected OLK block file: {path}")
    try:
        block_type = data[32:36].decode("ascii")[::-1]
    except UnicodeDecodeError as exc:
        raise ConversionError(f"Invalid OLK block type: {path}") from exc
    return block_type, data[BLOCK_HEADER_SIZE:]


def decode_narrow(data: bytes) -> str:
    data = data.rstrip(b"\x00")
    if not data:
        return ""
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("cp1252", errors="replace")


def decode_wide(data: bytes) -> str:
    if len(data) % 2:
        data = data[:-1]
    return data.decode("utf-16-le", errors="replace").rstrip("\x00")


def parse_recipient(data: bytes) -> Recipient:
    if len(data) < 36:
        raise ConversionError("Truncated OLK recipient")
    recipient_type = data[2]
    cursor = 28
    address_size = struct.unpack_from("<i", data, cursor)[0]
    cursor += 4
    if address_size < 0 or cursor + address_size + 4 > len(data):
        raise ConversionError("Invalid OLK recipient address length")
    address = decode_narrow(data[cursor : cursor + address_size])
    cursor += address_size
    name_size = struct.unpack_from("<i", data, cursor)[0]
    cursor += 4
    if name_size < 0 or cursor + name_size > len(data):
        raise ConversionError("Invalid OLK recipient name length")
    name = decode_wide(data[cursor : cursor + name_size])
    return Recipient(address=address, name=name, recipient_type=recipient_type)


def parse_recipient_list(data: bytes) -> list[Recipient]:
    if len(data) < 5:
        return []
    count = struct.unpack_from("<i", data, 0)[0]
    if count < 0 or count > 100_000:
        raise ConversionError("Invalid OLK recipient count")
    cursor = 5
    recipients: list[Recipient] = []
    for _ in range(count):
        if cursor + 2 > len(data):
            raise ConversionError("Truncated OLK recipient list")
        size = struct.unpack_from("<H", data, cursor)[0]
        cursor += 2
        if cursor + size > len(data):
            raise ConversionError("Invalid OLK recipient entry length")
        recipients.append(parse_recipient(data[cursor : cursor + size]))
        cursor += size
    return recipients


def parse_message_properties(path: Path) -> MessageProperties:
    class_id, values = parse_entity_file(path)
    if class_id != MESSAGE_CLASS_ID:
        raise ConversionError(f"Not an OLK message entity: {path}")

    def narrow(key: str) -> str:
        return decode_narrow(values.get(key, b""))

    def wide(key: str) -> str:
        return decode_wide(values.get(key, b""))

    def recipients(key: str) -> list[Recipient]:
        raw = values.get(key)
        return parse_recipient_list(raw) if raw else []

    body = wide("1F:1E")
    html_body = wide("1F:62")
    return MessageProperties(
        headers=narrow("1E:04"),
        subject=wide("1F:01"),
        body=body,
        html_body=html_body,
        preview=wide("1F:27"),
        message_id=narrow("1E:02"),
        in_reply_to=narrow("1E:22"),
        references=narrow("1E:24"),
        from_=recipients("0D:03"),
        to=recipients("0D:1E"),
        cc=recipients("0D:1F"),
        bcc=recipients("0D:20"),
    )


def resolve_profile_file(data_dir: Path, stored_path: str) -> Path:
    relative = Path(unquote(stored_path))
    if relative.is_absolute():
        raise ConversionError(f"Absolute path in Outlook database: {stored_path}")
    root = data_dir.resolve()
    candidate = (root / relative).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise ConversionError(f"Path escapes Outlook Data directory: {stored_path}") from exc
    return candidate


def get_owned_blocks(
    connection: sqlite3.Connection, record_id: int
) -> list[tuple[int, str]]:
    rows = connection.execute(
        """
        SELECT b.BlockTag, b.PathToDataFile
        FROM Mail_OwnedBlocks AS ob
        JOIN Blocks AS b
          ON b.BlockID = ob.BlockID AND b.BlockTag = ob.BlockTag
        WHERE ob.Record_RecordID = ?
        ORDER BY b.rowid
        """,
        (record_id,),
    )
    return [(int(row[0]), str(row[1])) for row in rows]


def looks_like_html(value: str) -> bool:
    lowered = value.lstrip().lower()
    return any(lowered.startswith(marker) for marker in HTML_MARKERS)


def normalize_message_id(value: str) -> str:
    value = value.strip()
    if not value:
        return ""
    if value.startswith("<") and value.endswith(">"):
        return value
    return f"<{value.strip('<>')}>"


def format_recipients(recipients: Sequence[Recipient]) -> str:
    formatted: list[str] = []
    for recipient in recipients:
        if not recipient.address:
            continue
        formatted.append(email.utils.formataddr((recipient.name, recipient.address)))
    return ", ".join(formatted)


def parse_original_headers(raw_headers: str) -> Message:
    raw = raw_headers.encode("utf-8", errors="surrogateescape")
    if not raw.endswith((b"\n", b"\r")):
        raw += b"\n"
    return BytesParser(policy=email.policy.default).parsebytes(raw + b"\n")


def copy_original_headers(target: EmailMessage, raw_headers: str) -> None:
    if not raw_headers.strip():
        return
    try:
        parsed = parse_original_headers(raw_headers)
    except Exception:
        return
    for name, value in parsed.items():
        if name.lower() in CONTENT_HEADERS:
            continue
        try:
            target[name] = value
        except (TypeError, ValueError):
            continue


def set_header_if_missing(message: EmailMessage, name: str, value: object) -> None:
    if value is None or value == "" or message.get(name) is not None:
        return
    try:
        message[name] = str(value)
    except (TypeError, ValueError):
        pass


def set_recovered_body(
    message: EmailMessage, properties: MessageProperties, fallback_preview: str
) -> EmailMessage | None:
    body = properties.body.replace("\x00", "")
    html = properties.html_body.replace("\x00", "")
    if not html and body and looks_like_html(body):
        html, body = body, ""

    if body and html:
        message.set_content(body, subtype="plain", charset="utf-8")
        message.add_alternative(html, subtype="html", charset="utf-8")
        return message.get_body(preferencelist=("html",))
    if html:
        message.set_content(html, subtype="html", charset="utf-8")
        return message
    if body:
        message.set_content(body, subtype="plain", charset="utf-8")
        return None
    message.set_content(fallback_preview or "", subtype="plain", charset="utf-8")
    message["X-Outlook-Body-Missing"] = "true"
    return None


def parse_mime_part(payload: bytes, source: Path) -> EmailMessage:
    try:
        part = BytesParser(policy=email.policy.default).parsebytes(payload)
    except Exception as exc:
        raise ConversionError(f"Cannot parse MIME attachment block: {source}") from exc
    if part.get("Content-Type") is None:
        fallback = EmailMessage(policy=email.policy.default)
        fallback.set_content(payload, maintype="application", subtype="octet-stream")
        fallback.add_header("Content-Disposition", "attachment", filename=source.stem)
        return fallback
    return part


def attachment_identity(part: Message) -> tuple[str, str]:
    return ((part.get_filename() or "").casefold(), (part.get("Content-ID") or "").casefold())


def existing_attachment_identities(message: Message) -> set[tuple[str, str]]:
    return {
        attachment_identity(part)
        for part in message.walk()
        if part is not message and (part.get_filename() or part.get("Content-ID"))
    }


def add_mime_parts(
    message: EmailMessage,
    html_part: EmailMessage | None,
    parts: Sequence[EmailMessage],
) -> int:
    existing = existing_attachment_identities(message)
    inline: list[EmailMessage] = []
    regular: list[EmailMessage] = []
    for part in parts:
        identity = attachment_identity(part)
        if identity != ("", "") and identity in existing:
            continue
        existing.add(identity)
        if html_part is not None and (
            part.get_content_disposition() == "inline" or part.get("Content-ID")
        ):
            inline.append(part)
        else:
            regular.append(part)

    if inline and html_part is not None:
        if html_part.get_content_maintype() != "multipart":
            html_part.make_related()
        for part in inline:
            html_part.attach(part)
    if regular:
        if message.get_content_type() != "multipart/mixed":
            message.make_mixed()
        for part in regular:
            message.attach(part)
    return len(inline) + len(regular)


def build_email_message(
    row: sqlite3.Row,
    properties: MessageProperties,
    attachment_parts: Sequence[EmailMessage],
    source_message: EmailMessage | None,
) -> tuple[EmailMessage, int]:
    if source_message is not None and list(source_message.items()):
        message = source_message
        if not isinstance(message, EmailMessage):
            raise ConversionError("Parsed message source is not an EmailMessage")
        html_part = message.get_body(preferencelist=("html",))
    else:
        message = EmailMessage(policy=email.policy.default)
        copy_original_headers(message, properties.headers)
        html_part = set_recovered_body(
            message, properties, str(row["Message_Preview"] or properties.preview)
        )

    set_header_if_missing(message, "Subject", properties.subject or row["Message_NormalizedSubject"])
    set_header_if_missing(message, "From", format_recipients(properties.from_ or []))
    set_header_if_missing(message, "To", format_recipients(properties.to or []))
    set_header_if_missing(message, "Cc", format_recipients(properties.cc or []))
    set_header_if_missing(message, "Bcc", format_recipients(properties.bcc or []))
    set_header_if_missing(
        message,
        "Message-ID",
        normalize_message_id(properties.message_id or str(row["Message_MessageID"] or "")),
    )
    set_header_if_missing(message, "In-Reply-To", properties.in_reply_to)
    set_header_if_missing(message, "References", properties.references)

    timestamp = row["Message_TimeSent"] or row["Message_TimeReceived"] or row["Record_ModDate"]
    if message.get("Date") is None and timestamp is not None:
        message["Date"] = email.utils.formatdate(
            float(timestamp), localtime=False, usegmt=True
        )

    message["X-Outlook-Recovered-By"] = f"Outlook Mac MBOX Converter/{VERSION}"
    message["X-Outlook-Record-ID"] = str(row["Record_RecordID"])
    message["X-Outlook-Folder-ID"] = str(row["Record_FolderID"])
    message["X-Outlook-Read"] = "true" if row["Message_ReadFlag"] else "false"
    if row["Message_Hidden"]:
        message["X-Outlook-Hidden"] = "true"
    if row["Message_MarkedForDelete"]:
        message["X-Outlook-Marked-For-Delete"] = "true"
    if row["Message_PartiallyDownloaded"]:
        message["X-Outlook-Partially-Downloaded"] = "true"
    if row["Message_ReadFlag"] and message.get("Status") is None:
        message["Status"] = "RO"

    count = add_mime_parts(message, html_part, attachment_parts)
    return message, count


def parse_message_source(payload: bytes) -> EmailMessage | None:
    try:
        candidate = BytesParser(policy=email.policy.default).parsebytes(payload)
    except Exception:
        return None
    if not isinstance(candidate, EmailMessage) or not list(candidate.items()):
        return None
    return candidate


def remove_attachment_parts(message: Message) -> int:
    """Remove attachment and inline-resource MIME parts recursively."""
    payload = message.get_payload()
    if not isinstance(payload, list):
        return 0
    removed = 0
    retained: list[Message] = []
    for part in payload:
        if (
            part.get_filename()
            or part.get_content_disposition() in {"attachment", "inline"}
            or part.get("Content-ID")
        ):
            removed += 1
            continue
        removed += remove_attachment_parts(part)
        retained.append(part)
    message.set_payload(retained)
    return removed


def envelope_sender(message: Message, properties: MessageProperties) -> str:
    if properties.from_:
        for recipient in properties.from_:
            if recipient.address:
                return recipient.address.replace(" ", "_")
    addresses = email.utils.getaddresses(message.get_all("From", []))
    if addresses and addresses[0][1]:
        return addresses[0][1].replace(" ", "_")
    return "MAILER-DAEMON"


def envelope_timestamp(row: sqlite3.Row) -> float:
    value = row["Message_TimeReceived"] or row["Message_TimeSent"] or row["Record_ModDate"]
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def write_mbox_message(
    output: BinaryIO, message: EmailMessage, sender: str, timestamp: float
) -> None:
    stamp = time.strftime("%a %b %d %H:%M:%S %Y", time.gmtime(timestamp))
    output.write(f"From {sender} {stamp}\n".encode("ascii", errors="replace"))
    generator_policy = email.policy.default.clone(linesep="\n", max_line_length=78)
    BytesGenerator(
        output,
        mangle_from_=True,
        maxheaderlen=78,
        policy=generator_policy,
    ).flatten(message, unixfrom=False)
    output.write(b"\n\n")


def message_query(
    folder_ids: Sequence[int], exclude_hidden: bool, exclude_deleted: bool
) -> tuple[str, list[object]]:
    clauses: list[str] = []
    parameters: list[object] = []
    if folder_ids:
        placeholders = ",".join("?" for _ in folder_ids)
        clauses.append(f"Record_FolderID IN ({placeholders})")
        parameters.extend(folder_ids)
    if exclude_hidden:
        clauses.append("Message_Hidden = 0")
    if exclude_deleted:
        clauses.append("Message_MarkedForDelete = 0")
    where = " WHERE " + " AND ".join(clauses) if clauses else ""
    query = f"""
        SELECT Record_RecordID, PathToDataFile, Record_ModDate, Record_FolderID,
               Record_AccountUID, Message_Hidden, Message_MarkedForDelete,
               Message_MessageID, Message_NormalizedSubject,
               Message_PartiallyDownloaded, Message_ReadFlag, Message_Preview,
               Message_SenderList, Message_RecipientList, Message_TimeReceived,
               Message_TimeSent, Message_Size
        FROM Mail
        {where}
        ORDER BY Record_FolderID,
                 COALESCE(Message_TimeReceived, Message_TimeSent, Record_ModDate),
                 Record_RecordID
    """
    return query, parameters


def estimate_export_size(
    connection: sqlite3.Connection,
    folder_ids: Sequence[int],
    exclude_hidden: bool,
    exclude_deleted: bool,
) -> tuple[int, int]:
    query, parameters = message_query(folder_ids, exclude_hidden, exclude_deleted)
    count_query = "SELECT COUNT(*), COALESCE(SUM(Message_Size), 0) FROM (" + query + ")"
    row = connection.execute(count_query, parameters).fetchone()
    return int(row[0]), int(row[1])


def nearest_existing_parent(path: Path) -> Path:
    candidate = path.expanduser().resolve()
    while not candidate.exists() and candidate != candidate.parent:
        candidate = candidate.parent
    return candidate


def ensure_free_space(output_root: Path, estimate: int) -> None:
    if estimate <= 0:
        return
    parent = nearest_existing_parent(output_root)
    free = shutil.disk_usage(parent).free
    required = int(estimate * 1.15)
    if free < required:
        raise ConversionError(
            f"Insufficient free space: need about {required:,} bytes, have {free:,}"
        )


def iter_messages(
    connection: sqlite3.Connection,
    folder_ids: Sequence[int],
    exclude_hidden: bool,
    exclude_deleted: bool,
    limit: int | None,
) -> Iterator[sqlite3.Row]:
    query, parameters = message_query(folder_ids, exclude_hidden, exclude_deleted)
    cursor = connection.execute(query, parameters)
    for index, row in enumerate(cursor):
        if limit is not None and index >= limit:
            break
        yield row


def target_for_folder(
    base: Path, profile_name: str, folder_id: int, paths: dict[int, Path]
) -> Path:
    folder_path = paths.get(folder_id, Path("Recovered") / f"Folder {folder_id}")
    parent = base / profile_name / folder_path.parent
    return parent / f"{folder_path.name}.mbox"


class FolderWriter:
    """Write one MBOX through a same-directory partial file."""

    def __init__(self, target: Path, overwrite: bool):
        self.target = target
        self.partial = target.with_name(f".{target.name}.partial")
        self.overwrite = overwrite
        if target.exists() and not overwrite:
            raise ConversionError(f"Output already exists: {target}")
        if self.partial.exists() and not overwrite:
            raise ConversionError(f"Partial output already exists: {self.partial}")
        target.parent.mkdir(parents=True, exist_ok=True)
        self.handle = self.partial.open("wb")

    def close_successfully(self) -> int:
        self.handle.flush()
        os.fsync(self.handle.fileno())
        size = self.handle.tell()
        self.handle.close()
        os.replace(self.partial, self.target)
        return size

    def close_failed(self) -> None:
        if not self.handle.closed:
            self.handle.flush()
            self.handle.close()


def convert_profile(args: argparse.Namespace) -> ConversionStats:
    profile_root, data_dir = locate_data_directory(args.profile)
    output_root = args.output.expanduser().resolve()
    profile_name = sanitize_component(profile_root.name, "Main Profile")
    connection = open_database(data_dir)
    validate_database(connection)
    folders = read_folders(connection)
    paths = build_folder_paths(folders)
    counts = folder_message_counts(connection)

    if args.list_folders:
        for folder_id in sorted(counts):
            folder_path = paths.get(folder_id, Path("Recovered") / f"Folder {folder_id}")
            print(f"{folder_id:>6}  {counts[folder_id]:>8}  {folder_path}")
        connection.close()
        return ConversionStats()

    selected_ids = sorted(set(args.folder_id or []))
    unknown_ids = [record_id for record_id in selected_ids if record_id not in folders]
    if unknown_ids:
        connection.close()
        raise ConversionError(
            "Unknown folder IDs: " + ", ".join(map(str, unknown_ids))
        )

    estimated_count, estimated_size = estimate_export_size(
        connection, selected_ids, args.exclude_hidden, args.exclude_deleted
    )
    if args.limit is not None:
        estimated_count = min(estimated_count, args.limit)
    log(
        f"Profile: {profile_root}\n"
        f"Messages selected: {estimated_count:,}\n"
        f"Database message-size estimate: {estimated_size:,} bytes",
        quiet=args.quiet,
    )
    if args.dry_run:
        for folder_id in selected_ids or sorted(counts):
            if counts.get(folder_id, 0):
                target = target_for_folder(output_root, profile_name, folder_id, paths)
                print(f"{folder_id:>6}  {counts[folder_id]:>8}  {target}")
        connection.close()
        return ConversionStats(messages_seen=estimated_count)

    ensure_free_space(output_root, estimated_size)
    stats = ConversionStats()
    current_folder_id: int | None = None
    writer: FolderWriter | None = None
    error_records: list[dict[str, object]] = []

    try:
        for row in iter_messages(
            connection,
            selected_ids,
            args.exclude_hidden,
            args.exclude_deleted,
            args.limit,
        ):
            stats.messages_seen += 1
            folder_id = int(row["Record_FolderID"])
            if folder_id != current_folder_id:
                if writer is not None:
                    stats.bytes_written += writer.close_successfully()
                    stats.folders_written += 1
                target = target_for_folder(output_root, profile_name, folder_id, paths)
                log(f"Writing {target}", quiet=args.quiet)
                writer = FolderWriter(target, args.overwrite)
                current_folder_id = folder_id

            try:
                message_path = resolve_profile_file(data_dir, str(row["PathToDataFile"]))
                if not message_path.is_file():
                    raise ConversionError(f"Missing message file: {message_path}")
                properties = parse_message_properties(message_path)

                attachment_parts: list[EmailMessage] = []
                source_message: EmailMessage | None = None
                for _, stored_block_path in get_owned_blocks(
                    connection, int(row["Record_RecordID"])
                ):
                    if args.no_attachments and stored_block_path.endswith(
                        ".olk15MsgAttachment"
                    ):
                        continue
                    block_path = resolve_profile_file(data_dir, stored_block_path)
                    if not block_path.is_file():
                        stats.attachment_blocks_missing += 1
                        continue
                    try:
                        block_type, payload = read_block_payload(block_path)
                        if block_type == "Attc" and not args.no_attachments:
                            attachment_parts.append(
                                parse_mime_part(payload, block_path)
                            )
                        elif block_type == "MSrc" and source_message is None:
                            source_message = parse_message_source(payload)
                    except Exception as exc:
                        stats.attachment_blocks_failed += 1
                        error_records.append(
                            {
                                "record_id": int(row["Record_RecordID"]),
                                "block": stored_block_path,
                                "error": str(exc),
                            }
                        )

                if args.no_attachments and source_message is not None:
                    remove_attachment_parts(source_message)

                message, attached_count = build_email_message(
                    row, properties, attachment_parts, source_message
                )
                assert writer is not None
                write_mbox_message(
                    writer.handle,
                    message,
                    envelope_sender(message, properties),
                    envelope_timestamp(row),
                )
                stats.messages_written += 1
                stats.attachment_blocks_written += attached_count
            except Exception as exc:
                stats.messages_skipped += 1
                error_records.append(
                    {
                        "record_id": int(row["Record_RecordID"]),
                        "message": str(row["PathToDataFile"]),
                        "error": str(exc),
                    }
                )
                if args.on_error == "stop":
                    raise

            if (
                not args.quiet
                and args.progress_every > 0
                and stats.messages_seen % args.progress_every == 0
            ):
                log(
                    f"Processed {stats.messages_seen:,} messages; "
                    f"written {stats.messages_written:,}; skipped {stats.messages_skipped:,}"
                )

        if writer is not None:
            stats.bytes_written += writer.close_successfully()
            stats.folders_written += 1
            writer = None
    except Exception:
        if writer is not None:
            writer.close_failed()
        raise
    finally:
        connection.close()

    output_root.mkdir(parents=True, exist_ok=True)
    manifest = {
        "artifact": "OLK2MBOX conversion output",
        "artifact_version": VERSION,
        "release_date": RELEASE_DATE,
        "stability": "Stable",
        "license": "GPL-3.0-or-later",
        "source": "https://github.com/igp76/OLK2MBOX",
        "profile": str(profile_root),
        "completed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "statistics": stats.__dict__,
        "errors": error_records,
    }
    manifest_path = output_root / "OLK2MBOX-conversion-manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return stats


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Convert a legacy Outlook for Mac 15 profile cache into one MBOX "
            "file per mail folder. The source profile is always opened read-only."
        )
    )
    parser.add_argument("profile", type=Path, help="Main Profile or Data directory")
    parser.add_argument("output", type=Path, help="Output directory")
    parser.add_argument(
        "--folder-id",
        type=int,
        action="append",
        help="Convert only this folder ID; may be repeated",
    )
    parser.add_argument(
        "--list-folders",
        action="store_true",
        help="List mail folders and message counts, then exit",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show selected folders and size estimate without writing output",
    )
    parser.add_argument(
        "--limit",
        type=int,
        help="Convert at most this many messages; intended for validation",
    )
    parser.add_argument(
        "--no-attachments",
        action="store_true",
        help="Do not include attachments or embedded inline resources",
    )
    parser.add_argument(
        "--exclude-hidden",
        action="store_true",
        help="Exclude messages marked hidden by Outlook",
    )
    parser.add_argument(
        "--exclude-deleted",
        action="store_true",
        help="Exclude messages marked for deletion by Outlook",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Atomically replace MBOX files that already exist",
    )
    parser.add_argument(
        "--on-error",
        choices=("stop", "skip"),
        default="stop",
        help="Stop on a bad message or skip it and record the error (default: stop)",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=500,
        metavar="N",
        help="Report progress every N messages; 0 disables progress (default: 500)",
    )
    parser.add_argument("--quiet", action="store_true", help="Suppress progress output")
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {VERSION} ({RELEASE_DATE}; GPL-3.0-or-later)",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.limit is not None and args.limit < 1:
        parser.error("--limit must be greater than zero")
    if args.progress_every < 0:
        parser.error("--progress-every cannot be negative")
    try:
        stats = convert_profile(args)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    if not args.list_folders and not args.dry_run:
        log(
            f"Completed: {stats.messages_written:,} messages in "
            f"{stats.folders_written:,} folders; {stats.messages_skipped:,} skipped; "
            f"{stats.attachment_blocks_written:,} attachment blocks included; "
            f"{stats.bytes_written:,} bytes written",
            quiet=args.quiet,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
