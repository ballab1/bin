#!/usr/bin/env bash
set -euo pipefail

# Source directory (where files currently are)
SRC="${1:?Usage: $0 <source_dir> <target_dir>}"
# Target directory (where files should be moved)
DEST_ROOT="${2:?Usage: $0 <source_dir> <target_dir>}"

# Extensions to scan (case-insensitive)
EXTS="3gp gif heic jpeg jpg mov mp4 png"
REGEX=$(printf "%s|" $EXTS | sed 's/|$//')

command -v exiftool >/dev/null || {
    echo "exiftool is required."
    exit 1
}

find "$SRC" -type f | while read -r FILE; do
    EXT="${FILE##*.}"
    EXT_LOWER=$(echo "$EXT" | tr 'A-Z' 'a-z')

    [[ "$EXT_LOWER" =~ ^($REGEX)$ ]] || continue

    DATE=$(exiftool -s -s -s -DateTimeOriginal -CreateDate -MediaCreateDate -TrackCreateDate "$FILE" 2>/dev/null | head -n1)

    if [[ -z "$DATE" ]]; then
        echo "No date found for: $FILE"
        continue
    fi

    YEAR=$(echo "$DATE" | awk -F'[: ]' '{print $1}')
    MONTH=$(echo "$DATE" | awk -F'[: ]' '{print $2}')

    if ! [[ "$YEAR" =~ ^[0-9]{4}$ && "$MONTH" =~ ^[0-9]{2}$ ]]; then
        echo "Unusable date for: $FILE → $DATE"
        continue
    fi

    DEST_DIR="$DEST_ROOT/$YEAR/$MONTH"
    mkdir -p "$DEST_DIR"

    BASENAME=$(basename "$FILE")
    DEST_FILE="$DEST_DIR/$BASENAME"

    if [[ -e "$DEST_FILE" ]]; then
        SRC_HASH=$(sha256sum "$FILE" | awk '{print $1}')
        DST_HASH=$(sha256sum "$DEST_FILE" | awk '{print $1}')

        if [[ "$SRC_HASH" == "$DST_HASH" ]]; then
            echo "Duplicate detected → deleting source: $FILE"
            rm "$FILE"
            continue
        fi

        # Generate unique suffix
        n=1
        while [[ -e "$DEST_DIR/${BASENAME%.*}_$n.${BASENAME##*.}" ]]; do
            ((n++))
        done
        NEW_NAME="${BASENAME%.*}_$n.${BASENAME##*.}"
        DEST_FILE="$DEST_DIR/$NEW_NAME"
        echo "Name collision → renaming to: $NEW_NAME"
    fi

    mv "$FILE" "$DEST_FILE"
    echo "Moved: $FILE → $DEST_FILE"
done

