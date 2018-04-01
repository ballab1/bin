#!/bin/bash

function permissions.set_bindirs()
{
    local -r dirlist=$1
    
    for dir in ${dirlist}; do
        mkdir -p "$dir" && chmod -R 777 "$dir"
        local -a files=( $( ls "$dir"/* 2> /dev/null ) )
        [ ${#files[@]} -gt 0 ] && chmod 755 "${files[*]}"
    done
}

clear
permissions.set_bindirs '/home/bobb/bin /home/bobb/.jenkins /home/bobb/.nano'
