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
