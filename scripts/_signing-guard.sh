#!/bin/bash
# Signing guard: ensure the Developer ID key is present before codesign.
# Source this file; do not run it directly.
# Requires: op (1Password CLI), security, interactive terminal for Touch ID.

_SIGNING_HASH="B9CA1FF8209D9B1BD4940F2D39C327EF836FD3C0"
_KEYCHAIN="$HOME/Library/Keychains/Apple Development.keychain-db"
_OP_ITEM="sqn2j6zeygtpewb2v66expqxva"
_TMP_P12="/tmp/devid-guard-$$.p12"

_ensure_signing_key() {
    if security find-identity -v -p codesigning \
        "$_KEYCHAIN" 2>/dev/null | grep -q "$_SIGNING_HASH"; then
        return 0   # key present — no-op
    fi

    echo "  Developer ID key missing from keychain. Attempting auto-restore via 1Password..."

    # Fail loud if op is not authenticated — never continue silently (D-03 step 4)
    if ! op whoami >/dev/null 2>&1; then
        echo "ERROR: 1Password CLI not authenticated."
        echo "  Run: eval \$(op signin) then re-run this script."
        exit 1
    fi

    # Trap ensures .p12 is removed even if an error occurs mid-restore (T-36.2-01)
    trap 'rm -f "$_TMP_P12"' EXIT

    op read "op://TrueNAS/$_OP_ITEM/Certificates.p12" --out-file "$_TMP_P12"
    # Password captured into a local variable only; never echoed or written to disk (T-36.2-02)
    _PW="$(op item get "$_OP_ITEM" --fields password --reveal)"
    # Import into the custom keychain — NOT login (iCloud-synced and therefore pruned) (D-04, T-36.2-03)
    security import "$_TMP_P12" \
        -k "$_KEYCHAIN" \
        -P "$_PW" \
        -T /usr/bin/codesign
    rm -f "$_TMP_P12"

    # Re-verify the expected identity is now present
    if ! security find-identity -v -p codesigning \
        "$_KEYCHAIN" 2>/dev/null | grep -q "$_SIGNING_HASH"; then
        echo "ERROR: Key restore did not produce the expected identity ($_SIGNING_HASH)."
        exit 1
    fi
    echo "  Developer ID key restored successfully."
}

_ensure_signing_key
