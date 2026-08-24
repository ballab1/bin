#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n'

SRC=~/photo/PhotoLibrary
DST=~/photo/VideoLibrary

# Find AVI and MOV files (case-insensitive)
while read -r srcfile; do
    # Compute relative path
    rel="${srcfile#$SRC/}"

    # Build destination path
    dstfile="$DST/$rel"

    # Ensure destination directory exists
    mkdir -p "$(dirname "$dstfile")"

    if [[ -e "$dstfile" ]]; then
        echo "Skipping existing file: $dstfile"
    else
        echo "Moving: $srcfile → $dstfile"
        mv "$srcfile" "$dstfile"
    fi
done < <(find "$SRC" -type f \( -iname "*.avi" -o -iname "*.mov" \) )


