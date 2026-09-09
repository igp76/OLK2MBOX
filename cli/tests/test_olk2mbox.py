"""Unit tests for the standalone OLK2MBOX converter.

Artifact-Version: 2.0.1
Release-Date: 2026-09-09
Stability: Stable
Change-Summary: Verify the stable converter from the consolidated CLI directory.
SPDX-FileCopyrightText: 2026 igp76
SPDX-License-Identifier: GPL-3.0-or-later
"""

from __future__ import annotations

import io
import struct
import sys
import tempfile
import unittest
from email.message import EmailMessage
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import olk2mbox as converter  # noqa: E402


def descriptor(variant: int, index: int, size: int) -> bytes:
    if variant > 0xFF or index > 0xFF:
        raise ValueError("The synthetic fixture only supports one-byte keys")
    return bytes((index, 0, 0, variant)) + struct.pack("<i", size)


def collection(items: list[tuple[int, int, bytes]]) -> bytes:
    header_size = 12 + len(items) * 8
    body = b"".join(value for _, _, value in items)
    header = struct.pack("<3i", len(items), header_size, len(body))
    return header + b"".join(
        descriptor(variant, index, len(value))
        for variant, index, value in items
    ) + body


def recipient(address: str, name: str) -> bytes:
    address_data = address.encode("utf-8")
    name_data = name.encode("utf-16-le")
    flags = struct.pack("<h4b", 3, 2, 3, 7, 0) + b"\x00" * 22
    return (
        flags
        + struct.pack("<i", len(address_data))
        + address_data
        + struct.pack("<i", len(name_data))
        + name_data
    )


def recipient_list(*values: bytes) -> bytes:
    return (
        struct.pack("<iB", len(values), 2)
        + b"".join(struct.pack("<H", len(value)) + value for value in values)
    )


def entity_file(items: list[tuple[int, int, bytes]]) -> bytes:
    header = (
        converter.MAGIC
        + struct.pack("<i", 1)
        + struct.pack("<i", converter.ENTITY_KIND)
        + struct.pack("<i", 42)
        + struct.pack("<i", converter.MESSAGE_CLASS_ID)
        + b"\x00" * 12
        + b"gsem"
        + b"\x00" * 4
    )
    return header + collection(items)


class CollectionTests(unittest.TestCase):
    def test_descriptor_key(self) -> None:
        self.assertEqual(converter.descriptor_key(b"\x01\x00\x00\x1f"), "1F:01")

    def test_invalid_collection_is_rejected(self) -> None:
        with self.assertRaises(converter.ConversionError):
            converter.parse_collection(struct.pack("<3i", 1, 20, 500))


class MessageParserTests(unittest.TestCase):
    def test_message_fields_and_recipients(self) -> None:
        sender = recipient("sender@example.com", "Sender Name")
        target = recipient("target@example.com", "Target Name")
        fixture = entity_file(
            [
                (0x1E, 0x04, b"X-Test: yes\r\n"),
                (0x1F, 0x01, "Example subject".encode("utf-16-le")),
                (0x1F, 0x1E, "Example body".encode("utf-16-le")),
                (0x1E, 0x02, b"fixture@example.com"),
                (0x0D, 0x03, recipient_list(sender)),
                (0x0D, 0x1E, recipient_list(target)),
            ]
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.olk15Message"
            path.write_bytes(fixture)
            parsed = converter.parse_message_properties(path)

        self.assertEqual(parsed.subject, "Example subject")
        self.assertEqual(parsed.body, "Example body")
        self.assertEqual(parsed.message_id, "fixture@example.com")
        self.assertEqual(parsed.from_[0].address, "sender@example.com")
        self.assertEqual(parsed.to[0].name, "Target Name")

    def test_wrong_class_is_rejected(self) -> None:
        fixture = bytearray(entity_file([]))
        struct.pack_into("<i", fixture, 16, 8)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.olk15Event"
            path.write_bytes(fixture)
            with self.assertRaises(converter.ConversionError):
                converter.parse_message_properties(path)


class FolderPathTests(unittest.TestCase):
    def test_outlook_roots_and_hierarchy(self) -> None:
        folders = {
            7: converter.FolderInfo(7, -2, 0, "Placeholder", 99),
            121: converter.FolderInfo(121, 7, 0, "Archive", 0),
            101: converter.FolderInfo(101, -2, 60129542145, "", 99),
            110: converter.FolderInfo(110, 101, 60129542145, "Inbox", 1),
        }
        paths = converter.build_folder_paths(folders)
        self.assertEqual(paths[121], Path("On My Computer/Archive"))
        self.assertEqual(paths[110], Path("Exchange Account 101/Inbox"))

    def test_unsafe_folder_characters_are_replaced(self) -> None:
        folders = {
            1: converter.FolderInfo(1, -2, 1, "", 99),
            2: converter.FolderInfo(2, 1, 1, "A/B:C", 0),
        }
        self.assertEqual(
            converter.build_folder_paths(folders)[2],
            Path("Exchange Account 1/A_B_C"),
        )


class MboxWriterTests(unittest.TestCase):
    def test_from_lines_are_escaped(self) -> None:
        message = EmailMessage()
        message["From"] = "sender@example.com"
        message["Subject"] = "Fixture"
        message.set_content("first\nFrom should be escaped\nlast")
        output = io.BytesIO()
        converter.write_mbox_message(output, message, "sender@example.com", 0)
        data = output.getvalue()
        self.assertTrue(data.startswith(b"From sender@example.com "))
        self.assertIn(b"\n>From should be escaped\n", data)

    def test_message_id_normalization(self) -> None:
        self.assertEqual(
            converter.normalize_message_id("example@example.com"),
            "<example@example.com>",
        )
        self.assertEqual(
            converter.normalize_message_id("<example@example.com>"),
            "<example@example.com>",
        )

    def test_attachment_removal_keeps_alternative_bodies(self) -> None:
        message = EmailMessage()
        message.set_content("Plain body")
        message.add_alternative("<p>HTML body</p>", subtype="html")
        message.add_attachment(
            b"payload",
            maintype="application",
            subtype="octet-stream",
            filename="fixture.bin",
        )

        removed = converter.remove_attachment_parts(message)

        self.assertEqual(removed, 1)
        self.assertEqual(len(list(message.iter_attachments())), 0)
        self.assertEqual(message.get_body(preferencelist=("plain",)).get_content().strip(), "Plain body")


if __name__ == "__main__":
    unittest.main()
