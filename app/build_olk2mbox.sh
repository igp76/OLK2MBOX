#!/bin/bash
# Artifact-Version: 2.1.1
# Release-Date: 2026-09-09
# Stability: Stable
# Change-Summary: Build the embedded engine from the consolidated cli source directory.
# SPDX-FileCopyrightText: 2026 igp76
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

APP_VERSION="2.0.0"
BUILDER_VERSION="2.1.1"
ENGINE_VERSION="2.0.0"
PYINSTALLER_VERSION="6.22.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="$PROJECT_ROOT/.build/olk2mbox-apple-silicon"
DIST_ROOT="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_ROOT/OLK2MBOX.app"
ZIP_PATH="$DIST_ROOT/OLK2MBOX-${APP_VERSION}-arm64.zip"
DMG_PATH="$DIST_ROOT/OLK2MBOX-${APP_VERSION}-arm64.dmg"
RELEASE_MANIFEST_PATH="$DIST_ROOT/OLK2MBOX-${APP_VERSION}-release-manifest.json"
CHECKSUM_PATH="$DIST_ROOT/OLK2MBOX-${APP_VERSION}-SHA256SUMS.txt"
VENV_PATH="$BUILD_ROOT/venv"
CODESIGN_IDENTITY="-"
USE_CURRENT_ENVIRONMENT=false

usage() {
    echo "Usage: $0 [--identity IDENTITY] [--use-current-environment] [--version]"
    echo
    echo "Build OLK2MBOX.app for Apple Silicon."
    echo "The default is an ad hoc signature. Pass a Developer ID identity when available."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --identity)
            [[ $# -ge 2 ]] || { echo "error: --identity requires a value" >&2; exit 2; }
            CODESIGN_IDENTITY="$2"
            shift 2
            ;;
        --use-current-environment)
            USE_CURRENT_ENVIRONMENT=true
            shift
            ;;
        --version)
            echo "OLK2MBOX app builder ${BUILDER_VERSION} (app ${APP_VERSION}, engine ${ENGINE_VERSION})"
            exit 0
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ "$BUILD_ROOT" != "$PROJECT_ROOT/.build/olk2mbox-apple-silicon" ]]; then
    echo "error: unsafe build path" >&2
    exit 1
fi

rm -rf "$BUILD_ROOT"
rm -rf "$APP_BUNDLE"
rm -f "$ZIP_PATH"
rm -f "$DMG_PATH"
rm -f "$RELEASE_MANIFEST_PATH"
rm -f "$CHECKSUM_PATH"
mkdir -p "$BUILD_ROOT" "$DIST_ROOT"

if [[ "$USE_CURRENT_ENVIRONMENT" == true ]]; then
    PYINSTALLER="$(command -v pyinstaller || true)"
    if [[ -z "$PYINSTALLER" ]]; then
        echo "error: pyinstaller is not available in the current environment" >&2
        exit 1
    fi
    PYTHON="$(command -v python3)"
else
    python3 -m venv "$VENV_PATH"
    "$VENV_PATH/bin/python" -m pip install \
        --disable-pip-version-check \
        --only-binary=:all: \
        --require-hashes \
        --requirement "$SCRIPT_DIR/requirements-build.txt"
    PYINSTALLER="$VENV_PATH/bin/pyinstaller"
    PYTHON="$VENV_PATH/bin/python"
fi

ACTUAL_PYINSTALLER_VERSION="$($PYINSTALLER --version)"
if [[ "$ACTUAL_PYINSTALLER_VERSION" != "$PYINSTALLER_VERSION" ]]; then
    echo "error: expected PyInstaller $PYINSTALLER_VERSION, found $ACTUAL_PYINSTALLER_VERSION" >&2
    exit 1
fi

echo "Building embedded converter for arm64..."
"$PYINSTALLER" \
    --clean \
    --noconfirm \
    --onefile \
    --name olk2mbox \
    --target-arch arm64 \
    --distpath "$BUILD_ROOT/helper-dist" \
    --workpath "$BUILD_ROOT/pyinstaller-work" \
    --specpath "$BUILD_ROOT" \
    "$PROJECT_ROOT/cli/olk2mbox.py"

CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
HELPERS_DIR="$CONTENTS/Helpers"
RESOURCES_DIR="$CONTENTS/Resources"
LICENSES_DIR="$RESOURCES_DIR/Licenses"
mkdir -p "$MACOS_DIR" "$HELPERS_DIR" "$RESOURCES_DIR" "$LICENSES_DIR"

echo "Compiling native SwiftUI interface for arm64..."
xcrun swiftc \
    -parse-as-library \
    -swift-version 5 \
    -O \
    -target arm64-apple-macos13.0 \
    -framework AppKit \
    -framework SwiftUI \
    "$SCRIPT_DIR/Sources/OLK2MBOXApp.swift" \
    -o "$MACOS_DIR/OLK2MBOX"

cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$BUILD_ROOT/helper-dist/olk2mbox" "$HELPERS_DIR/olk2mbox"
ditto "$SCRIPT_DIR/Resources/en.lproj" "$RESOURCES_DIR/en.lproj"
ditto "$SCRIPT_DIR/Resources/it.lproj" "$RESOURCES_DIR/it.lproj"
cp "$PROJECT_ROOT/LICENSE" "$LICENSES_DIR/GPL-3.0.txt"
cp "$PROJECT_ROOT/third_party/PYTHON-3.14.7-LICENSE.txt" "$LICENSES_DIR/PYTHON-3.14.7-LICENSE.txt"
cp "$PROJECT_ROOT/docs/THIRD_PARTY_NOTICES.en-US.md" "$LICENSES_DIR/OLK2MBOX-THIRD-PARTY-NOTICES.en-US.md"
cp "$PROJECT_ROOT/docs/THIRD_PARTY_NOTICES.it-IT.md" "$LICENSES_DIR/OLK2MBOX-THIRD-PARTY-NOTICES.it-IT.md"
cp "$SCRIPT_DIR/Resources/OLK2MBOX-SOURCE-CODE.txt" "$RESOURCES_DIR/OLK2MBOX-SOURCE-CODE.txt"

echo "Generating application icon..."
ASSET_CATALOG="$BUILD_ROOT/Assets.xcassets"
ICONSET="$ASSET_CATALOG/AppIcon.appiconset"
xcrun swift "$SCRIPT_DIR/Tools/GenerateOLK2MBOXIcon.swift" "$ICONSET"
"$PYTHON" -c 'import json, sys; from pathlib import Path; sizes=[(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]; images=[{"filename":f"icon_{points}x{points}{"@2x" if scale == 2 else ""}.png","idiom":"mac","scale":f"{scale}x","size":f"{points}x{points}"} for points,scale in sizes]; Path(sys.argv[1]).write_text(json.dumps({"images":images,"info":{"author":"xcode","version":1}},indent=2)+"\n",encoding="utf-8")' "$ICONSET/Contents.json"
xcrun actool \
    --compile "$RESOURCES_DIR" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$BUILD_ROOT/asset-info.plist" \
    "$ASSET_CATALOG"

"$PYTHON" -c 'import json, platform, sys; from pathlib import Path; target=Path(sys.argv[1]); target.write_text(json.dumps({"artifact":"OLK2MBOX.app","artifact_version":sys.argv[2],"app_version":sys.argv[2],"engine_version":sys.argv[3],"builder_version":sys.argv[4],"release_date":"2026-09-09","stability":"Stable","change_summary":"Build the current stable app from the consolidated clean-root source.","license":"GPL-3.0-or-later","source_url":f"https://github.com/igp76/OLK2MBOX/tree/app-v{sys.argv[2]}","architecture":"arm64","python":platform.python_version(),"pyinstaller":sys.argv[5],"apple_code_signing":"ad-hoc","apple_notarized":False}, indent=2)+"\n", encoding="utf-8")' \
    "$RESOURCES_DIR/OLK2MBOX-build-manifest.json" \
    "$APP_VERSION" \
    "$ENGINE_VERSION" \
    "$BUILDER_VERSION" \
    "$ACTUAL_PYINSTALLER_VERSION"

echo "Signing application..."
xattr -cr "$APP_BUNDLE"
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$HELPERS_DIR/olk2mbox"
    codesign --force --deep --sign - "$APP_BUNDLE"
else
    codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$HELPERS_DIR/olk2mbox"
    codesign --force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
fi

echo "Verifying bundle..."
plutil -lint "$CONTENTS/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
file "$MACOS_DIR/OLK2MBOX"
file "$HELPERS_DIR/olk2mbox"
"$HELPERS_DIR/olk2mbox" --version

echo "Creating DMG release..."
DMG_ROOT="$BUILD_ROOT/dmg-root"
mkdir -p "$DMG_ROOT"
ditto "$APP_BUNDLE" "$DMG_ROOT/OLK2MBOX.app"
ln -s /Applications "$DMG_ROOT/Applications"
cp "$PROJECT_ROOT/LICENSE" "$DMG_ROOT/OLK2MBOX-COPYING.txt"
cp "$SCRIPT_DIR/Resources/OLK2MBOX-SOURCE-CODE.txt" "$DMG_ROOT/OLK2MBOX-SOURCE-CODE.txt"
cp "$PROJECT_ROOT/docs/THIRD_PARTY_NOTICES.en-US.md" "$DMG_ROOT/OLK2MBOX-THIRD-PARTY-NOTICES.en-US.md"
cp "$PROJECT_ROOT/docs/THIRD_PARTY_NOTICES.it-IT.md" "$DMG_ROOT/OLK2MBOX-THIRD-PARTY-NOTICES.it-IT.md"
xattr -cr "$DMG_ROOT/OLK2MBOX.app"
codesign --verify --deep --strict --verbose=2 "$DMG_ROOT/OLK2MBOX.app"
hdiutil create \
    -volname "OLK2MBOX" \
    -srcfolder "$DMG_ROOT" \
    -format UDZO \
    -ov \
    "$DMG_PATH"
hdiutil verify "$DMG_PATH"

echo "Creating ZIP release..."
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Generating release provenance and checksums..."
"$PYTHON" -c 'import hashlib, json, sys; from pathlib import Path; target=Path(sys.argv[1]); packages=[]; [(packages.append({"filename":Path(name).name,"sha256":hashlib.sha256(Path(name).read_bytes()).hexdigest()})) for name in sys.argv[5:]]; target.write_text(json.dumps({"artifact":"OLK2MBOX Apple Silicon release","artifact_version":sys.argv[2],"release_date":"2026-09-09","stability":"Stable","change_summary":"Republish the current stable app from the consolidated clean-root source.","app_version":sys.argv[2],"engine_version":sys.argv[3],"builder_version":sys.argv[4],"license":"GPL-3.0-or-later","corresponding_source":f"https://github.com/igp76/OLK2MBOX/tree/app-v{sys.argv[2]}","architecture":"arm64","minimum_macos":"13.0","apple_code_signing":"ad-hoc","apple_notarized":False,"openpgp_primary_fingerprint":"9A0D7C4D2286FB72B7FBBB71EF548834983D3094","openpgp_signing_subkey_fingerprint":"C8F51EAB8C7DB38C53DA8458927D2B68384F934C","packages":packages},indent=2)+"\n",encoding="utf-8")' \
    "$RELEASE_MANIFEST_PATH" \
    "$APP_VERSION" \
    "$ENGINE_VERSION" \
    "$BUILDER_VERSION" \
    "$ZIP_PATH" \
    "$DMG_PATH"
{
    echo "# Artifact-Version: 2.0.0"
    echo "# Release-Date: 2026-09-09"
    echo "# Stability: Stable"
    echo "# Change-Summary: SHA-256 checksums for the republished clean-root OLK2MBOX 2.0.0 app release."
    echo "# SPDX-License-Identifier: GPL-3.0-or-later"
    shasum -a 256 "$ZIP_PATH" "$DMG_PATH" "$RELEASE_MANIFEST_PATH" | sed "s#  $DIST_ROOT/#  #"
} > "$CHECKSUM_PATH"
(cd "$DIST_ROOT" && shasum -a 256 -c "$(basename "$CHECKSUM_PATH")")

# Finder or file-provider metadata may be reattached to the unpacked convenience
# bundle after packaging. Remove it without altering the already-created archives.
xattr -cr "$APP_BUNDLE"
xattr -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_BUNDLE" 2>/dev/null || true
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -rf "$BUILD_ROOT"

echo "Build completed: $APP_BUNDLE"
echo "ZIP release: $ZIP_PATH"
echo "DMG release: $DMG_PATH"
echo "Release manifest: $RELEASE_MANIFEST_PATH"
echo "Checksums: $CHECKSUM_PATH"
