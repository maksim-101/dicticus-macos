#!/bin/bash
# Consolidate multiple Dicticus.app installations to /Applications/Dicticus.app.
#
# Usage:
#   ./scripts/install-local.sh
#
# Behavior:
#   1. Gracefully quits any running Dicticus instance.
#   2. Enumerates every com.dicticus.app bundle on disk via mdfind.
#   3. Trashes (mv ~/.Trash/) every copy that is NOT /Applications/Dicticus.app,
#      excluding ~/.Trash, Time Machine snapshots, and dev build artifacts
#      (project build/ subdir + Xcode DerivedData).
#   4. Wipes the specific Dicticus DerivedData folder to prevent identity confusion.
#   5. Copies the freshly-built Release .app from macOS/build/ to /Applications/.
#   6. Re-signs the app with Developer ID Moritz Wehrli (VTWHBCCP36) for TCC persistence.
#   7. Re-launches via `open -a Dicticus`.
#
# Dev-only — do not run on end-user machines.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")/macOS"
BUNDLE_ID="com.dicticus.app"
CANONICAL_APP="/Applications/Dicticus.app"
BUILD_APP="$PROJECT_DIR/build/Build/Products/Release/Dicticus.app"
RECORDER_APP="$PROJECT_DIR/build/Build/Products/Debug-Recorder/Dicticus.app"
SIGNING_ID="B9CA1FF8209D9B1BD4940F2D39C327EF836FD3C0" # Developer ID Moritz Wehrli
TRASH_DIR="$HOME/.Trash"
TIMESTAMP="$(date +%s)"

echo "=== Step 1: Verify build artefact ==="
if [ -d "$RECORDER_APP" ]; then
    echo "  Using Debug-Recorder build."
    SOURCE_APP="$RECORDER_APP"
elif [ -d "$BUILD_APP" ]; then
    echo "  Using Release build."
    SOURCE_APP="$BUILD_APP"
else
    echo "ERROR: Dicticus.app not found at $BUILD_APP or $RECORDER_APP"
    echo "Run scripts/build-dmg.sh or xcodebuild -scheme Dicticus -configuration Release first."
    exit 1
fi

echo "=== Step 2: Quit any running Dicticus instance ==="
osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null || true
for i in 1 2 3; do
    if ! pgrep -x "Dicticus" >/dev/null 2>&1; then break; fi
    sleep 1
done
if pgrep -x "Dicticus" >/dev/null 2>&1; then
    echo "  Dicticus still running after 3s — forcing pkill -f Dicticus.app"
    pkill -f "Dicticus.app" || true
    sleep 1
fi

echo "=== Step 3: Enumerate stale Dicticus.app copies ==="
STALE_COPIES=()
while IFS= read -r path; do
    [ -z "$path" ] && continue
    # Whitelist guard — must be a Dicticus.app bundle
    case "$path" in
      */Dicticus.app) ;;
      *) continue ;;
    esac
    # Exclude canonical, Trash, Time Machine, and dev build artifacts
    case "$path" in
      "$CANONICAL_APP") continue ;;
      "$HOME/.Trash"/*) continue ;;
      */Backups.backupdb/*) continue ;;
      */.MobileBackups/*) continue ;;
      /Volumes/com.apple.TimeMachine.localsnapshots/*) continue ;;
      */build/Build/Products/*) continue ;;        # local xcodebuild output
    esac
    STALE_COPIES+=("$path")
done < <(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'")

if [ ${#STALE_COPIES[@]} -eq 0 ]; then
    echo "  No stale copies found."
else
    echo "  Found ${#STALE_COPIES[@]} stale copy/copies:"
    for p in "${STALE_COPIES[@]}"; do echo "    - $p"; done
fi

echo "=== Step 4: Trash stale copies & wipe DerivedData ==="
if [ ${#STALE_COPIES[@]} -gt 0 ]; then
    for p in "${STALE_COPIES[@]}"; do
        dest="$TRASH_DIR/Dicticus-stale-$TIMESTAMP-$(basename "$(dirname "$p")").app"
        echo "  mv $p -> $dest"
        mv "$p" "$dest"
    done
fi
# Wipe Dicticus-specific DerivedData to prevent identity desync
DD_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Dicticus-*" -type d -maxdepth 1 2>/dev/null || true)
if [ -n "$DD_PATH" ]; then
    echo "  Cleaning DerivedData: $DD_PATH"
    rm -rf "$DD_PATH"
fi

echo "=== Step 5: Install fresh build to $CANONICAL_APP ==="
if [ -d "$CANONICAL_APP" ]; then
    dest="$TRASH_DIR/Dicticus-prev-$TIMESTAMP.app"
    echo "  Existing canonical install -> $dest"
    mv "$CANONICAL_APP" "$dest"
fi
cp -R "$SOURCE_APP" "$CANONICAL_APP"

echo "=== Step 6: Re-sign for TCC persistence ==="
echo "  Signing with identity: $SIGNING_ID"
codesign --force --deep --sign "$SIGNING_ID" "$CANONICAL_APP"

echo "=== Step 7: Relaunch ==="
open -a Dicticus

echo ""
echo "=== Done ==="
echo "Canonical install: $CANONICAL_APP"
echo "Stale copies trashed: ${#STALE_COPIES[@]}"
echo ""
echo "NOTE: TCC permission entries (Microphone / Accessibility / Input Monitoring)"
echo "cannot be cleaned programmatically. If hotkeys still misbehave, open"
echo "  System Settings > Privacy & Security"
echo "and remove any leftover Dicticus entries before re-granting."
