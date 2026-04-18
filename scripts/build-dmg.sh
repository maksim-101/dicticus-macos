#!/bin/bash
# Build Dicticus.app and package as a styled DMG.
#
# Usage: ./scripts/build-dmg.sh
# Output: Dicticus.dmg in the project root
#
# Requirements: Xcode, xcodegen, create-dmg (brew install create-dmg)
#
# Per D-05: Uses xcodebuild build (not archive) since archive requires a team ID.
# Per D-06: Ad-hoc signing with CODE_SIGN_IDENTITY="-" (required on Apple Silicon).
# Per D-07: Styled DMG with background image and Applications symlink.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")/Dicticus"
OUTPUT_DIR="$(dirname "$SCRIPT_DIR")"
DMG_NAME="Dicticus.dmg"
BACKGROUND="$SCRIPT_DIR/dmg-background.png"

echo "=== Step 1: Generate Xcode project ==="
cd "$PROJECT_DIR"
xcodegen generate

echo "=== Step 2: Build Release .app (ad-hoc signed) ==="
xcodebuild -scheme Dicticus \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    build 2>&1 | tail -5

APP_DIR="build/Build/Products/Release"

# Verify the .app exists
if [ ! -d "$APP_DIR/Dicticus.app" ]; then
    echo "ERROR: Dicticus.app not found at $APP_DIR/"
    exit 1
fi

# Verify entitlements are embedded
echo "=== Step 3: Verify entitlements ==="
codesign -d --entitlements :- "$APP_DIR/Dicticus.app" 2>/dev/null || echo "WARNING: Could not read entitlements"

echo "=== Step 4: Create styled DMG ==="
# Remove existing DMG if present
rm -f "$OUTPUT_DIR/$DMG_NAME"

# Stage only Dicticus.app (exclude loose .bundle files from SPM dependencies)
STAGING_DIR=$(mktemp -d)
cp -R "$APP_DIR/Dicticus.app" "$STAGING_DIR/"
trap "rm -rf '$STAGING_DIR'" EXIT

EXIT_CODE=0
create-dmg \
    --volname "Dicticus" \
    --background "$BACKGROUND" \
    --window-size 660 400 \
    --icon-size 128 \
    --icon "Dicticus.app" 180 200 \
    --app-drop-link 480 200 \
    --no-internet-enable \
    "$OUTPUT_DIR/$DMG_NAME" \
    "$STAGING_DIR/" || EXIT_CODE=$?

# create-dmg returns exit code 2 if it created the DMG but could not
# set the background image (e.g., running in CI without a display).
# The DMG is still valid.
if [ $EXIT_CODE -eq 2 ] && [ -f "$OUTPUT_DIR/$DMG_NAME" ]; then
    echo "WARNING: DMG created but background image may not be set (headless environment)"
elif [ $EXIT_CODE -ne 0 ]; then
    echo "ERROR: create-dmg failed (exit code $EXIT_CODE)"
    exit 1
fi

echo "=== Done ==="
echo "DMG created: $OUTPUT_DIR/$DMG_NAME"
echo ""
echo "To install:"
echo "  1. Double-click $DMG_NAME to mount"
echo "  2. Drag Dicticus.app to Applications"
echo "  3. On first launch: System Settings > Privacy & Security > Open Anyway"
