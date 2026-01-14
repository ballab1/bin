#!/bin/bash

pwd
declare grepExpr="($(find . -type f -name '*.bashlib' -exec basename '{}' \; | sed -e 's|.bashlib||' | tr '\n' '|' | sed 's/|$//'))\\.[a-z]+"

while read file;do
    echo -e "\n----$file"
    grep -E "$grepExpr" "$file"
done < <(find . -type f -executable -or -name '*.bashlib' | sort) | awk '

# Start-of-record header
/^----\.\// {
    # Flush previous record if non-empty
    if (rec && rec_has_content) {
        print rec
    }

    # Start new record with trimmed header
    rec = $0
    rec_has_content = 0
    next
}

# Other lines
{
    rec = rec ORS $0
    if ($0 ~ /[^[:space:]]/) {
        rec_has_content = 1
    }
}

END {
    # Flush last record
    if (rec && rec_has_content) {
        print rec
    }
}
'
