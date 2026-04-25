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
#   4. Copies the freshly-built Release .app from macOS/build/ to /Applications/.
#   5. Re-launches via `open -a Dicticus`.
#
# Dev-only — do not run on end-user machines.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")/macOS"
BUNDLE_ID="com.dicticus.app"
CANONICAL_APP="/Applications/Dicticus.app"
BUILD_APP="$PROJECT_DIR/build/Build/Products/Release/Dicticus.app"
TRASH_DIR="$HOME/.Trash"
TIMESTAMP="$(date +%s)"

echo "=== Step 1: Verify build artefact ==="
if [ ! -d "$BUILD_APP" ]; then
    echo "ERROR: Dicticus.app not found at $BUILD_APP"
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
      */DerivedData/*) continue ;;                 # Xcode per-user build cache
    esac
    STALE_COPIES+=("$path")
done < <(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'")

if [ ${#STALE_COPIES[@]} -eq 0 ]; then
    echo "  No stale copies found."
else
    echo "  Found ${#STALE_COPIES[@]} stale copy/copies:"
    for p in "${STALE_COPIES[@]}"; do echo "    - $p"; done
fi

echo "=== Step 4: Trash stale copies ==="
if [ ${#STALE_COPIES[@]} -gt 0 ]; then
    for p in "${STALE_COPIES[@]}"; do
        dest="$TRASH_DIR/Dicticus-stale-$TIMESTAMP-$(basename "$(dirname "$p")").app"
        echo "  mv $p -> $dest"
        mv "$p" "$dest"
    done
fi

echo "=== Step 5: Install fresh build to $CANONICAL_APP ==="
if [ -d "$CANONICAL_APP" ]; then
    dest="$TRASH_DIR/Dicticus-prev-$TIMESTAMP.app"
    echo "  Existing canonical install -> $dest"
    mv "$CANONICAL_APP" "$dest"
fi
cp -R "$BUILD_APP" "$CANONICAL_APP"

echo "=== Step 6: Relaunch ==="
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
