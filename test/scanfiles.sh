#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?Usage: $0 <target_dir> <src_dir>}"
SRC="${2:?Usage: $0 <target_dir> <src_dir>}"

LOG="$HOME/INFO.log"
RUN="$HOME/RUN.sh"

: > "$LOG"
: > "$RUN"

declare -A NAME_INDEX

# Build filename → list-of-paths index for SRC
while IFS= read -r FILE; do
    NAME=$(basename "$FILE")
    NAME_INDEX["$NAME"]+="$FILE"$'\n'
done < <(find "$SRC" -type f)

# Walk target tree
while IFS= read -r FILE; do
    NAME=$(basename "$FILE")
    DST_HASH=$(sha256sum "$FILE" | awk '{print $1}')

    MATCHES="${NAME_INDEX[$NAME]:-}"

    # No filename match
    if [[ -z "$MATCHES" ]]; then
        echo "NO MATCH: HASH=$DST_HASH FILE=$FILE" >> "$LOG"
        continue
    fi

    MATCHES=$(echo "$MATCHES" | sed '/^$/d')
    COUNT=$(echo "$MATCHES" | wc -l)

    #
    # SINGLE MATCH
    #
    if (( COUNT == 1 )); then
        SRC_FILE="$MATCHES"
        SRC_HASH=$(sha256sum "$SRC_FILE" | awk '{print $1}')

        if [[ "$SRC_HASH" == "$DST_HASH" ]]; then
            # ✔ Silent success, but write symlink replacement commands to RUN.sh
            REL_PATH=$(realpath --relative-to="$(dirname "$FILE")" "$SRC_FILE")

            echo "rm \"$FILE\"" >> "$RUN"
            echo "ln -s \"$REL_PATH\" \"$FILE\"" >> "$RUN"
            continue
        fi

        # ❌ Hash mismatch → log
        echo "HASH MISMATCH: DST_HASH=$DST_HASH FILE=$FILE SRC_HASH=$SRC_HASH SRC_FILE=$SRC_FILE" >> "$LOG"
        continue
    fi

    #
    # MULTIPLE MATCHES
    #
    declare -A HASHES
    while IFS= read -r SRC_FILE; do
        [[ -z "$SRC_FILE" ]] && continue
        SRC_HASH=$(sha256sum "$SRC_FILE" | awk '{print $1}')
        HASHES["$SRC_HASH"]=1
    done <<< "$MATCHES"

    # Only log if ALL hashes match
    if (( ${#HASHES[@]} == 1 )); then
        echo "MULTIPLE MATCHES (ALL HASHES MATCH): DST_HASH=$DST_HASH FILE=$FILE" >> "$LOG"

        while IFS= read -r SRC_FILE; do
            [[ -z "$SRC_FILE" ]] && continue
            SRC_HASH=$(sha256sum "$SRC_FILE" | awk '{print $1}')
            echo "SRC: HASH=$SRC_HASH FILE=$SRC_FILE" >> "$LOG"
        done <<< "$MATCHES"

        echo >> "$LOG"
    fi

    # If hashes differ → silent
done < <(find "$TARGET" -type f)

