#!/usr/bin/env bash
set -euo pipefail

DST="${1:?Usage: $0 <dst_dir> <src_dir>}"
SRC="${2:?Usage: $0 <dst_dir> <src_dir>}"

LOG="$HOME/INFO.log"
RUN="$HOME/RUN.sh"

: > "$LOG"
: > "$RUN"

declare -A NAME_INDEX

#
# Build SRC index (no subshell, no blank lines, array-safe)
#
while IFS= read -r -d '' FILE; do
    NAME=$(basename "$FILE")
    NAME_INDEX["$NAME"]+="$FILE"$'\n'
done < <(find "$SRC" -type f -print0)

#
# Process DST (no subshell)
#
while IFS= read -r -d '' FILE; do
    NAME=$(basename "$FILE")
    DST_HASH=$(sha256sum "$FILE" | awk '{print $1}')

    MATCHES="${NAME_INDEX[$NAME]:-}"

    if [[ -z "$MATCHES" ]]; then
        echo "NO MATCH: DST_HASH=$DST_HASH DST_FILE=$FILE" >> "$LOG"
        continue
    fi

    # Convert MATCHES into an array
    mapfile -t MATCH_ARR < <(printf "%s\n" "$MATCHES" | sed '/^$/d')

    FILTERED_ARR=()

    #
    # Filter SRC matches by hash equality with DST
    #
    for SRC_FILE in "${MATCH_ARR[@]}"; do
        [[ -z "$SRC_FILE" ]] && continue
        SRC_HASH=$(sha256sum "$SRC_FILE" | awk '{print $1}')
        if [[ "$SRC_HASH" == "$DST_HASH" ]]; then
            FILTERED_ARR+=("$SRC_FILE")
        fi
    done

    COUNT=${#FILTERED_ARR[@]}

    #
    # 0 matching hashes → silent
    #
    if (( COUNT == 0 )); then
        continue
    fi

    #
    # 1 matching hash → symlink + log
    #
    if (( COUNT == 1 )); then
        SRC_FILE="${FILTERED_ARR[0]}"

        # Absolute safety: SRC_FILE must not be empty
        [[ -z "$SRC_FILE" ]] && continue

        REL_PATH=$(realpath --relative-to="$(dirname "$FILE")" "$SRC_FILE")

        echo "rm \"$FILE\"" >> "$RUN"
        echo "ln -s \"$REL_PATH\" \"$FILE\"" >> "$RUN"

        echo "MATCH: DST_HASH=$DST_HASH DST_FILE=$FILE SRC_HASH=$DST_HASH SRC_FILE=$SRC_FILE" >> "$LOG"
        continue
    fi

    #
    # >1 matching hashes → log all, no symlink
    #
    echo "MULTIPLE MATCHES (HASHES MATCH): DST_HASH=$DST_HASH DST_FILE=$FILE" >> "$LOG"
    for SRC_FILE in "${FILTERED_ARR[@]}"; do
        echo "SRC: SRC_HASH=$DST_HASH SRC_FILE=$SRC_FILE" >> "$LOG"
    done
    echo >> "$LOG"

done < <(find "$DST" -type f ! -xtype l -size +1000c -print0)

