#!/usr/bin/env bash

set -euo pipefail

ROOT="${1:-.}"

printf "\nScanning Git repos under: %s\n\n" "$ROOT"

# Loop through directories only
find "$ROOT" -maxdepth 1 -mindepth 1 -type d | while read -r dir; do
    # Skip .git directories inside the root
    [ "$(basename "$dir")" = ".git" ] && continue

    if [ -d "$dir/.git" ]; then
        # Check if repo is clean
        if git -C "$dir" diff --quiet && git -C "$dir" diff --cached --quiet; then
            printf "✔ CLEAN: %s\n" "$(basename "$dir")"
        else
            printf "✖ DIRTY: %s\n" "$(basename "$dir")"
        fi
    else
        printf "… Not a repo: %s\n" "$(basename "$dir")"
    fi
done

printf "\nDone.\n"
