#!/bin/bash

declare -i index
declare image
declare baseUrl='http://s2.ubuntu.home:5000'
declare credentials="$(< ~/.inf/secrets/credentials.github)"

declare start=$(date +%s)
[ -f ~/bin/trap.bashlib ] && source ~/bin/trap.bashlib

# get the list of images
declare -a images
mapfile -t images < <(curl -k -s -u "$credentials" -X GET "${baseUrl}/_catalog" | jq -r '.repositories[]')

declare afterCatalog=$(date +%s)
index=0
for image in "${images[@]}"; do
    (( index++ )) ||:
    # count number of defined tags
    printf "%s,%s,%s\n" "$index" "$image" "$(curl -k -s -u "$credentials" -X GET "${baseUrl}/${image}/tags/list" | jq -r '.tags[]|len')"
done

declare finish=$(date +%s)
declare -i afterCatalog=$(( afterCatalog - start ))
declare -i elapsed=$(( finish - start ))

TZ='America/New_York' date
printf "Time to download catalog: %02d:%02d:%02d\n"  $((afterCatalog / 3600)) $((afterCatalog % 3600 / 60)) $((afterCatalog % 60))
printf "Total time elapsed:       %02d:%02d:%02d\n"  $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60))
