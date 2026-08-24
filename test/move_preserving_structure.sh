#!/usr/bin/env bash

set -euo pipefail

SRC="$1"
DEST="$2"

# Ensure both SRC and DEST exist
if [[ ! -d "$SRC" ]]; then
    echo "Source directory does not exist: $SRC"
    exit 1
fi

if [[ ! -d "$DEST" ]]; then
    echo "Destination directory does not exist: $DEST"
    exit 1
fi

# Walk through all files in SRC
find "$SRC" -type f | while read -r FILE; do
    # Compute relative path
    REL_PATH="${FILE#$SRC/}"

    # Compute destination path
    DEST_PATH="$DEST/$REL_PATH"

    # Ensure destination subdirectory exists
    mkdir -p "$(dirname "$DEST_PATH")"

    # Move only if file does NOT already exist
    if [[ -e "$DEST_PATH" ]]; then
        echo "Skipping existing file: $DEST_PATH"
    else
        echo "Moving: $FILE → $DEST_PATH"
        mv "$FILE" "$DEST_PATH"
    fi
done

# Remove empty directories from SRC
find "$SRC" -type d -empty -delete

echo "Done."

