#!/bin/bash

find . -type f -name '*.*' \
    | sed -E 's/.*\.([^.]+)$/\1/' \
    | sort -u
