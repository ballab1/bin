#!/bin/bash

declare -r exceptions='
/
/dev
/etc
/lib
/lib64
/root
/sbin
/sys
/usr/bin
/usr/local/bin
/usr/local/crf/startup'

echo 'number lines: '$(echo $exceptions | wc -l)

declare -a array
mapfile -t array <<< "$exceptions"
echo 'arraysize:   '"${#array[*]}"

for en in "${array[@]}"; do
   declare -i count=$(grep -c "$en" <<< "$exceptions")
   [ $count -ne 1 ] && echo "entry '$en' returned : $count"
done
