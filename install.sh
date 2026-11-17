#!/bin/bash
# Installs (or updates) Blink from the latest GitHub Release:
#
#   curl -fsSL https://raw.githubusercontent.com/pizzani/blink/main/install.sh | bash
#
# Downloading with curl doesn't mark the app as quarantined, so macOS opens it without
# the "Open Anyway" prompt that browser downloads of unnotarized apps get.

set -euo pipefail

URL="https://github.com/pizzani/blink/releases/latest/download/Blink.zip"

# /Applications if we can write there, otherwise the user's own Applications folder.
DEST=/Applications
if [[ ! -w "$DEST" ]]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Blink..."
curl -fsSL "$URL" -o "$TMP/Blink.zip"
ditto -x -k "$TMP/Blink.zip" "$TMP"

# Quit a running copy before replacing it.
pkill -x Blink 2>/dev/null && sleep 1 || true

rm -rf "$DEST/Blink.app"
mv "$TMP/Blink.app" "$DEST/"
echo "Installed to $DEST/Blink.app"

open "$DEST/Blink.app"
echo "Blink is running. Look for it in the menu bar."
