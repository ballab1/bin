#!/bin/bash

declare -r PROGNAME="$( basename "${BASH_SOURCE[0]}" )"
declare -r PROGRAM_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"


declare -r loader="$PROGRAM_DIR/../utilities/appenv.bashlib"
if [ ! -e "$loader" ]; then
    echo 'Unable to load libraries' >&2
    exit 1
fi
source "$loader"
appenv.loader 'deploy.main'

if false; then
echo
json.encodeField  -- 100

echo
json.encodeField  -- 'true'

echo
json.encodeField  'isDone' 'false'

echo
json.encodeField  'name' 'Bob'

declare -a a=( 1 'true' 'isthere' )

echo
json.encodeField  'array' "${a[@]}"

declare -A b=( ['a']=1  ['b']=true  ['c']='Joan' )

echo
json.encodeField  'hash' '#b'
echo

declare str='"access_rights":777,
"access_rights_in_human_readable_form":"-rwxrwxrwx",
"sha256":"d783500c28dce865b9c6eb0e28dd86367d8c5641e441befd003aec5191ef6219"'

echo
json.encodeField  -- "$str"
echo

fi

declare filename=$(ls '/mnt/Synology/Guest/All Users/Music/Ace Of Base/The Bridge/09'*.wma)
filename="$(stat --format='%n' "$filename")"
echo -n '{'
json.encodeField  'name' "$( basename "$filename" )"
echo '}'

filename=$(ls '/mnt/Synology/Guest/All Users/Music/Blue '*'Cult/Don'*/05*)
filename="$(stat --format='%n' "$filename")"
echo -n '{'
json.encodeField  'name' "$( basename "$filename" )"
echo -n ','
json.encodeField  'folder' "$( dirname "$filename" )"
echo '}'
