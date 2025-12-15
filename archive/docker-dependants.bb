#!/bin/bash

# Many thanks to 'https://github.com/RidiculousRichard' where the original inspiration for this script was found
# this (re-written) version improves on the original by running about 100 times faster and being easier to understand

# Script to determine what named images and containers are dependent on the specified image (or a containers image) from stdin or in the args
# An unmatchable input is ignored
# All of the following will be found:
#    Any image name / tag / name:tag / id that has a prefix in it that matches the input
#    Any other image that relies on the images specified
#    Any containers (running or not) that use any of these images

# Use the Unofficial Bash Strict Mode
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

#declare -r FORCE_COLOR=1
declare -i IS_LABELS=0 IS_LAYERS=0 IS_REPORT=1 IS_VERBOSE=1


set -o noglob
[ -e ~/bin/trap.bashlib ] && source ~/bin/trap.bashlib

declare -A IMAGEID_IDX_MAP IMAGEID_PARENTID_MAP IMAGE_REPOTAG_MAP SPECIFIED_IMAGE_DEPENDENCIES
declare -a CONTAINER_IDS CONTAINER_IMAGES CONTAINER_IMAGE_IDS CONTAINER_JSON
declare -a IMAGE_IDS IMAGE_CONTAINER_IDS IMAGE_JSON
declare -a MATCHED_CONTAINER_IDS MATCHED_IMAGE_IDS SPECIFIED_DOCKER_REFS


#------------------------------------------------------------------------------------------
function usage()
{
    local -i exit_status=${1:-1}

    cat >&2 << EOF
Usage:
    $"$( basename "${BASH_SOURCE[0]}" )"  [ -h|--help ] | [ -v|--verbose ] ref.....

    Common options:
        -h --help              Display a basic set of usage instructions
        -l --labels            Display labels - hide by default
           --layers            Display layers - hide by default
        -r --report            Display report
        -v --verbose           Display more info about progress, containers and images

Project: https://github.com/ballab1/bin

EOF
    exit "$exit_status"
}

#------------------------------------------------------------------------------------------
function argsParser()
{
    local -a args=( "$@" )

    # Parse command-line options into above variable
    local -r progname="$( basename "${BASH_SOURCE[0]}" )"
    local -r longopts='help,Help,HELP,labels,layers,report,summary,verbose'
    local -r shortopts='Hhlrsv'
    local -r options=$(getopt --longoptions "${longopts}" --options "${shortopts}" --name "$progname" -- "${args[@]}") || usage $?
    eval set -- "$options"

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--h|--help|-help)        usage 0;;
            -H|--H|--HELP|-HELP)        usage 0;;
                   --Help|-Help)        usage 0;;
                   --layers)            [ ${IS_LAYERS:-0} == 0 ] && IS_LAYERS=1 || IS_LAYERS=0;     shift 2;;
            -l|--l|--labels)            [ ${IS_LABELS:-0} == 0 ] && IS_LABELS=1 || IS_LABELS=0;     shift 2;;
            -r|--r|--report)            [ ${IS_REPORT:-0} == 0 ] && IS_REPORT=1 || IS_REPORT=0;     shift 2;;
            -s|--s|--summary)           [ ${IS_VERBOSE:-0} == 0 ] && IS_VERBOSE=1 || IS_VERBOSE=0;  shift 2;;
            -v|--v|--verbose)           [ ${IS_VERBOSE:-0} == 0 ] && IS_VERBOSE=1 || IS_VERBOSE=0;  shift 2;;
            --)                         shift;                                                      break;; 
            *)                          echo "$1";                                                  shift;;
        esac
    done
    [ $# -gt 0 ] && printf '%s\n' "$@"
    return 0
}

#------------------------------------------------------------------------------------------
function colorEcho()
{
    local color=${1:?"Input parameter 'color' must be passed to 'function ${FUNCNAME[0]}()'"} 
    shift

    # start_color
    if [ -t 1 ] || [ "${FORCE_COLOR:-}" ]; then
        case "$color" in
            RED)     echo -en '\e[91m';;
            red)     echo -en '\e[31m';;
            GREEN)   echo -en '\e[92m';;
            green)   echo -en '\e[32m';;
            YELLOW)  echo -en '\e[93m';;
            yellow)  echo -en '\e[33m';;
            BLUE)    echo -en '\e[34m';;
            blue)    echo -en '\e[94m';;
            MAGENTA) echo -en '\e[95m';;
            magenta) echo -en '\e[35m';;
            CYAN)    echo -en '\e[96m';;
            cyan)    echo -en '\e[36m';;
            *)       : ;;
        esac
    fi

    echo -en "$*"

    # stop_color
    if [ -t 1 ] || [ "${FORCE_COLOR:-}" ]; then echo -en '\e[0m'; fi
}

#------------------------------------------------------------------------------------------
# return all dependents of a given imageId
function dependantsOf()
{
    local id=${1:?"Input parameter 'id' must be passed to 'function ${FUNCNAME[0]}()'"}

    if [ "${SPECIFIED_IMAGE_DEPENDENCIES[$id]:-}" ]; then
        local dependant
        local -a dependentImages=()
        local -A dependentLayers=()

        imageId="${IMAGE_IDS[id]:-}"
        for dependant in ${SPECIFIED_IMAGE_DEPENDENCIES[$imageId]}; do
            if [[ $dependant =~ \[sha256:.+\]=sha256: ]]; then
                eval "dependentLayers$dependant"
            else
                dependentImages+=( "$dependant" )
            fi
        done
        [ ${#dependentImages[*]} -gt 0 ] || return 0

        for dependant in "${dependentImages[@]}"; do
            while [ "${dependentLayers[$dependant]:-}" ]; do
                dependant="${dependentLayers[$dependant]}"
                dependentImages+=( "$dependant" )
            done
        done
        printf '%s\n' "${dependentImages[@]}"
    fi
}

#------------------------------------------------------------------------------------------
function die()
{
    local status=$?
    [ $status -eq 0 ] || echo -ne '\e[31m' >&2
    echo "$1" >&2
    [ $status -eq 0 ] || echo -ne '\e[0m' >&2
    exit $status
}

#------------------------------------------------------------------------------------------
function dumpArray()
{
    local -r name="${1:?}"
    local -ri type="${2:?}"

    local key
    local -n vals="$name"
    echo "$name"
    if [ $type -eq 0 ]; then
        for key in "${vals[@]}";do
            printf '  %s\n' "$key"  >&2
        done
    else
        for key in "${!vals[@]}";do
            printf '  [%s]="%s"\n' "$key" "${vals[$key]}"  >&2
        done
    fi
}
#------------------------------------------------------------------------------------------
function dumpAArray()
{
    local -n vals="$1"

    echo $1
    for key in "${!vals[@]}";do
        printf '[%s]="%s"\n' "$key" "${vals[$key]}"  >&2
    done
}

#------------------------------------------------------------------------------------------
function echoColor()
{
    local color=${1:?"Input parameter 'color' must be passed to 'function ${FUNCNAME[0]}()'"} 
    local data reset

    # start_color
    if [ -t 1 ] || [ "${FORCE_COLOR:-}" ]; then
        case "$color" in
            RED)     color='\e[91m';;
            red)     color='\e[31m';;
            GREEN)   color='\e[92m';;
            green)   color='\e[32m';;
            YELLOW)  color='\e[93m';;
            yellow)  color='\e[33m';;
            BLUE)    color='\e[34m';;
            blue)    color='\e[94m';;
            MAGENTA) color='\e[95m';;
            magenta) color='\e[35m';;
            CYAN)    color='\e[96m';;
            cyan)    color='\e[36m';;
            *)       color='';;
        esac
        [ "$color" ] && reset='\e[0m'
    fi

    while read data; do
        echo -en "${color}${data}${reset:-}"
    done
}

#------------------------------------------------------------------------------------------
function echoImage()
{
    local imageId=${1:?"Input parameter 'imageId' must be passed to 'function ${FUNCNAME[0]}()'"}
    local refId=${2:-}

    if [ -z "$refId" ] || [ "$imageId" = "$refId" ]; then
        colorEcho 'GREEN' "$imageId"
    else
        colorEcho 'green' "$imageId"
    fi
}

#------------------------------------------------------------------------------------------
function echoSHA256()
{
    local sha256=${1:?"Input parameter 'sha256' must be passed to 'function ${FUNCNAME[0]}()'"}

    if [ "${sha256:0:7}" = 'sha256:' ]; then
        colorEcho 'yellow' 'sha256:'; echo -en "${sha256:7}"
    else
        echo -en "$sha256"
    fi
}

#------------------------------------------------------------------------------------------
# Check for a matching container
function findContainers()
{
    local -a specifiedDockerRefs=( "$@" )

    # check for info about a specified ref in running containers
    local -i id
    local ref
    for ref in "${specifiedDockerRefs[@]}"; do

        for (( id=0; id<"${#CONTAINER_JSON[@]}"; id++ )); do
            grep -qsE "$ref" <<< "${CONTAINER_JSON[$id]}" && echo "$id" 
        done

    done
    return 0
}

#------------------------------------------------------------------------------------------
function findContainerImages()
{
    [ $# -eq 0 ] && return 0
    local -ra images=( $@ )

    local -i cdx idx len
    local repotag
    for idx in "${images[@]}"; do   

        repotag="${IMAGE_REPOTAG_MAP[$idx]}"
        [ -z "$repotag" ] && continue
        len="${#IMAGE_REPOTAG_MAP[*]}"
        for (( cdx=0; cdx<"$len"; cdx++ )); do
            [ "$repotag" = "${CONTAINER_IMAGES[$cdx]:-}" ] && echo $cdx
        done

    done
    return 0
}

#------------------------------------------------------------------------------------------
function findContainerImageIds()
{
    [ $# -eq 0 ] && return 0
    local -ra containers=( $@ )

    local -i cdx idx len
    local repotag
    for cdx in "${containers[@]}"; do   

        repotag="${CONTAINER_IMAGES[$cdx]:-}"
        [ -z "$repotag" ] && continue
        len="${#IMAGE_REPOTAG_MAP[@]}"
        for (( idx=0; idx<"$len"; idx++ )); do
            [ "$repotag" = "${IMAGE_REPOTAG_MAP[$idx]:-}" ] && echo $idx
        done

    done
    return 0
}

#------------------------------------------------------------------------------------------
function findImageContainers()
{
    [ $# -eq 0 ] && return 0
    local -ra containers=( $@ )

    local -i cdx idx len
    local repotag
    for cdx in "${containers[@]}"; do

        repotag="${CONTAINER_IMAGES[$cdx]:-}"
        [ -z "$repotag" ] && continue
        len="${#IMAGE_REPOTAG_MAP[@]}"
        for (( idx=0; idx<"$len"; idx++ )); do
            [ "$repotag" = "${IMAGE_REPOTAG_MAP[$idx]:-}" ] && echo $idx
        done

    done
    return 0
}

#------------------------------------------------------------------------------------------
function findImageContainerIds()
{
    [ $# -eq 0 ] && return 0
    local -ra images=( $@ )

    local -i cdx idx len
    local repotag
    for idx in "${images[@]}"; do

        repotag="${IMAGE_REPOTAG_MAP[$idx]}"
        [ -z "$repotag" ] && continue
        len="${#IMAGE_REPOTAG_MAP[@]}"
        for (( cdx=0; cdx<"$len"; cdx++ )); do
            [ "$repotag" = "${CONTAINER_IMAGES[$cdx]:-}" ] && echo $cdx
        done

    done
    return 0
}

#------------------------------------------------------------------------------------------
# Check for a matching container
function findImages()
{
    local -a specifiedDockerRefs=( "$@" )

    # check images for info about a specified parent
    local -i id
    local name ref
    for ref in "${specifiedDockerRefs[@]}"; do

        for (( id=0; id<"${#IMAGE_JSON[@]}"; id++ )); do
            name="${IMAGE_REPOTAG_MAP[$id]}"
            [ -z "${name:-}" ] && continue
            grep -qsE "$ref" <<< "$name" && echo "$id"
        done

    done
    return 0
}

#------------------------------------------------------------------------------------------
function findMatches()
{
    [ $# -eq 0 ] && return 1
    local -a specifiedDockerRefs=( "$@" )

    local -a matched_container_ids matched_image_ids ids

    # determine any containers coresponding to specified dependents
    mapfile -t matched_container_ids < <(findContainers "${specifiedDockerRefs[@]}")

    # determine the image IDs coresponding to specified dependents
    mapfile -t matched_image_ids < <(findImages "${specifiedDockerRefs[@]}")


    # include image ids of any containers we have found
    mapfile -t ids < <(findContainerImages "${matched_image_ids[@]}")
    mapfile -t MATCHED_CONTAINER_IDS < <(printf '%s\n' "${matched_container_ids[@]}" "${ids[@]}" | LC_ALL=C sort -u)
    mapfile -t CONTAINER_IMAGE_IDS < <(findContainerImageIds "${MATCHED_CONTAINER_IDS[@]}")
    reportMatchingContainers >&2

    # include container ids of any images we have found
    mapfile -t ids < <(findImageContainers "${matched_container_ids[@]}")
    mapfile -t MATCHED_IMAGE_IDS < <(printf '%s\n' "${matched_image_ids[@]}" "${ids[@]}" | LC_ALL=C sort -u)
    mapfile -t IMAGE_CONTAINER_IDS < <(findImageContainerIds "${MATCHED_IMAGE_IDS[@]}")
    reportMatchingImages >&2


    [ ${#MATCHED_IMAGE_IDS[*]} -eq 0 ] && [ ${#MATCHED_CONTAINER_IDS[*]} -eq 0 ] && return 1
    verbose "    Detected ${#MATCHED_CONTAINER_IDS[*]} containers associated with specified reference(s)"
    verbose "    Detected ${#MATCHED_IMAGE_IDS[*]} images associated with specified reference(s)"
    return 0
}

#------------------------------------------------------------------------------------------
# determine any images which use specified dependents as a layer on which they build
function getDependentImages()
{
    local imageId=${1:?"Input parameter 'imageId' must be passed to 'function ${FUNCNAME[0]}()'"}

    local parent
    for parent in "${!IMAGEID_PARENTID_MAP[@]}"; do
        [ "$imageId" != "${IMAGEID_PARENTID_MAP[$parent]}" ] || printf '%s\n' "$parent"
    done
}

#------------------------------------------------------------------------------------------
function getOsId()
{
    if [ -e /etc/os-release ]; then
        grep -e '^ID=' /etc/os-release | awk -F'=' '{ print $2 }' | sed 's|"||g'
    else
        echo 'windows'
    fi
}

#------------------------------------------------------------------------------------------
function imageIdToIndex()
{
    local -a parentImages=( "$@" )

    # check images for info about a specified parent
    local -i id found
    local ref
    for ref in "${specifiedImages[@]}"; do
        found=0
        for (( id=0; id<"${#IMAGE_IDS[@]}"; id++ )); do
            if [ "$ref" = "${IMAGE_IDS[$id]:-}" ]; then
                echo "$id"
                found=1
                break;
            fi
        done
        [ "$found" -eq 0 ] && echo
    done
    return 0
}

#------------------------------------------------------------------------------------------
#
#  MAIN
#
#------------------------------------------------------------------------------------------
function main()
{
    # get input from commandline
    mapfile -t SPECIFIED_DOCKER_REFS < <(argsParser "$@")

    # Check there is some input
    [ ${#SPECIFIED_DOCKER_REFS[*]} -gt 0 ] || die 'Nothing specified to search for; images/containers must be specified as either args or on the stdin'
    verbose "Searching for information on: $(printf ' %s' "${SPECIFIED_DOCKER_REFS[*]}")"

    # need to use docker Rest API to get JSON for all containers/images
    populateIMAGES

    # need to use docker Rest API to get JSON for all containers/images
    populateCONTAINERS

    # matchup what was asked for with images and containers on this system
    findMatches "${SPECIFIED_DOCKER_REFS[@]}" || die 'No parent images or containers found'
    eval "SPECIFIED_IMAGE_DEPENDENCIES=( $(populateIdDependencies "${MATCHED_IMAGE_IDS[@]:-}") )"
    reportDependentImages >&2

    # report what we have discovered
    if [ $IS_REPORT -eq 1 ]; then
        showContainers
        showImages
    fi
}

#------------------------------------------------------------------------------------------
# determine any images which use specified dependents as a layer on which they build
function populateCONTAINERS()
{
    # need to use docker Rest API to get JSON for all containers
    local -r containersjson="$(curl --silent --unix-socket /var/run/docker.sock http://localhost/containers/json?all='true')" || return 1

    mapfile -t CONTAINER_JSON < <(jq -c '.[]' <<< "$containersjson")
    readonly CONTAINER_JSON

    mapfile -t CONTAINER_IDS < <(jq -r '.[].Id' <<< "$containersjson")
    readonly CONTAINER_IDS

    mapfile -t CONTAINER_NAMES < <(jq -r '.[].Names[0]|ltrimstr("/")' <<< "$containersjson")
    readonly CONTAINER_NAMES

    mapfile -t CONTAINER_IMAGES < <(jq -r '.[].Image' <<< "$containersjson")
    readonly CONTAINER_IMAGES


    if [ $IS_VERBOSE -eq 2 ]; then
      (
        echo "    Detected ${#CONTAINER_IDS[*]} containers"
        [ "${#CONTAINER_IDS[*]}" -ne "${#CONTAINER_JSON[*]}" ] && echo "    Detected ${#CONTAINER_JSON[*]} containers"
        [ "${#CONTAINER_IDS[*]}" -ne "${#CONTAINER_NAMES[*]}" ] && echo "    Detected ${#CONTAINER_NAMES[*]} containers"
        for json in "${CONTAINER_JSON[@]}"; do
            local id="$(jq -r '.Id' <<< "$json")"
            local name="$(jq -r '.Names[0]|ltrimstr("/")' <<< "$json")"
            [ "$id" != "${CONTAINER_IDS[$idx]}" ] && echo "${idx}: CONTAINER - json_id('$id') differs from '${CONTAINER_IDS[$idx]}'"
            [[ "$name" != "${CONTAINER_NAMES[$idx]}" && "$name" != '<none>:<none>' ]] && echo "${idx}: CONTAINER - json_name('$name') differs from '${CONTAINER_NAMES[$idx]}'"
            (( idx++ )) ||:
        done
      ) >&2
    fi
    return 0
}

#------------------------------------------------------------------------------------------
# determine any images which use specified dependents as a layer on which they build
function populateIMAGES()
{
    # need to use docker Rest API to get JSON for all images
    local imagesjson="$(curl --silent --unix-socket /var/run/docker.sock http://localhost/images/json)" || return 1

    # Populate the image info hash
    mapfile -t IMAGE_JSON < <(jq -c '.[]' <<< "$imagesjson")

    mapfile -t IMAGE_IDS < <(jq -r '.[].Id' <<< "$imagesjson")
    readonly IMAGE_IDS

    imagesjson="$(curl --silent --unix-socket /var/run/docker.sock http://localhost/images/json?all='true')" || return 1
#    mapfile -t IMAGE_REPOTAG_MAP < <(jq -r '.[]|"[\(.Id)]='"'"'\(.RepoTags[0]|if .=="<none>:<none>" then .="" else . end)'"'"'"' <<< "$imagesjson")
    eval "IMAGE_REPOTAG_MAP=( $(jq -r '.[].RepoTags[0]|if .=="<none>:<none>" then .="" else . end' <<< "$imagesjson") )"
    readonly IMAGE_REPOTAG_MAP

    # Populate the parent image info hash
    eval "IMAGEID_PARENTID_MAP=( $(jq -r '.[]|"[\(.Id)]='"'"'\(.ParentId)'"'"'"' <<< "$imagesjson") )"
    readonly IMAGEID_PARENTID_MAP

    verbose "    Detected ${#IMAGE_IDS[*]} images"
    verbose "    Detected $(printf '%s\n' "${IMAGE_REPOTAG_MAP[@]}" | grep -csE '^\w') named images"


    if [ $IS_VERBOSE -eq 2 ]; then
      (
        echo "    Detected ${#IMAGE_REPOTAG_MAP[*]} containers"
        [ "${#IMAGE_IDS[*]}" -ne "${#IMAGE_JSON[*]}" ] && echo "    Detected ${#IMAGE_JSON[*]} containers"
        [ "${#IMAGE_IDS[*]}" -ne "${#IMAGE_REPOTAG_MAP[*]}" ] && echo "    Detected ${#IMAGE_REPOTAG_MAP[*]} containers"
        local -i idx=0
        local id name
        for json in "${IMAGE_JSON[@]}"; do
            local id="$(jq -r '.Id' <<< "$json")"
            local name="$(jq -r '.RepoTags[0]' <<< "$json")"
            [ "$id" != "${IMAGE_IDS[$idx]}" ] && echo "${idx}: IMAGE - json_id('$id') differs from '${IMAGE_IDS[$idx]}'"
            [ "$name" != "${IMAGE_REPOTAG_MAP[$idx]}" ] && echo "${idx}: IMAGE - json_name('$name') differs from '${IMAGE_REPOTAG_MAP[$idx]}'"
            (( idx++ )) ||:
        done
      ) >&2
    fi
    return 0
}
 
#------------------------------------------------------------------------------------------
# determine any images which use specified dependents as a layer on which they build
function populateIdDependencies()
{
    [ $# -eq 0 ] && return 0
    local -a specifiedImages=( "$@" )

    local id
    for id in "${specifiedImages[@]}"; do
        populateImageDependencies "${IMAGE_IDS[$id]}"
    done
    return 0
}
 
#------------------------------------------------------------------------------------------
# determine any images which use specified dependents as a layer on which they build
function populateImageDependencies()
{
    [ $# -eq 0 ] && return 0
    local -a specifiedImages=( "$@" )

    local imageId parentId
    local -a dependents
    for imageId in "${specifiedImages[@]}"; do
        [ -z "${imageId:-}" ] && continue

        parentId="${IMAGEID_PARENTID_MAP[$imageId]:-}"
        [ -z "${parentId:-}" ] && continue

        [ "${SPECIFIED_IMAGE_DEPENDENCIES[$imageId]:-}" ] && continue

        mapfile -t dependents < <(getDependentImages  "$parentId")
        if [ ${#dependents[*]} -gt 0 ]; then
            SPECIFIED_IMAGE_DEPENDENCIES[$imageId]="${dependents[*]}"
            printf '["%s"]="%s"\n' "$imageId" "${dependents[*]}"
            populateImageDependencies "${dependents[@]}"
        fi
    done
    return 0
}

#------------------------------------------------------------------------------------------
function reportDependentImages()
{
    [ $IS_VERBOSE -eq 0 ] && return 0

    dumpArray SPECIFIED_IMAGE_DEPENDENCIES 1

    local id
    local -i dependants=0
    for id in "${!SPECIFIED_IMAGE_DEPENDENCIES[@]}"; do
        dependants+=$(echo "${SPECIFIED_IMAGE_DEPENDENCIES[$id]}" | wc -l)
    done
  
    verbose "    Detected ${dependants} other layers dependent on specified images"
}

#------------------------------------------------------------------------------------------
function reportDistinctImages()
{
    [ $IS_VERBOSE -eq 0 ] && return 0

    verbose "    Detected ${#MATCHED_IMAGE_IDS[*]} distinct images dependent on specified images"
    [ ${#MATCHED_IMAGE_IDS[*]} -gt 0 ] || return 0

    local image
    echo -n '      '
    for image in "${MATCHED_IMAGE_IDS[@]}"; do
        colorEcho 'cyan'  "  ${IMAGES[$image]:-}"
    done
    echo
}

#------------------------------------------------------------------------------------------
function reportMatchingContainers()
{
    [ $IS_VERBOSE -eq 0 ] && return 0

dumpArray matched_container_ids 0
dumpArray ids 0
dumpArray MATCHED_CONTAINER_IDS 0

    if [ ${#MATCHED_CONTAINER_IDS[*]} -eq 0 ]; then
        verbose "    Found 0 matching containers"
        return 0
    fi

    local id
    echo -n "    Found ${#MATCHED_CONTAINER_IDS[*]} matching containers: "
    for id in ${MATCHED_CONTAINER_IDS[@]}; do
        colorEcho 'cyan' " ${CONTAINER_NAMES[$id]}"
    done
    echo
}

#------------------------------------------------------------------------------------------
function reportMatchingImages()
{
    [ $IS_VERBOSE -eq 0 ] && return 0

dumpArray matched_image_ids 1
dumpArray CONTAINER_IMAGE_IDS 1

    if [ ${#MATCHED_IMAGE_IDS[*]} -eq 0 ]; then
        verbose "    Found 0 matching images"
        return 0
    fi

    local name
    echo "    Found ${#MATCHED_IMAGE_IDS[*]} matching images"
    for id in "${MATCHED_IMAGE_IDS[@]}"; do
#        [ -z "${IMAGE_REPOTAG_MAP[$id]}" ] && continue
        colorEcho 'cyan' "       ${IMAGE_REPOTAG_MAP[$id]}"'\n'
    done
    echo
}

#------------------------------------------------------------------------------------------
function showContainerInfo()
{
    local id=${1:?"Input parameter 'id' must be passed to 'function ${FUNCNAME[0]}()'"}

    local name="${CONTAINER_NAMES[$id]:-}"
    local containerId="${CONTAINER_IDS[$id]:-}"
    local image="${CONTAINER_IMAGES[$id]:-}"
    local json="${CONTAINER_JSON[$id]:-}"
    local imageId="$(jq -r '.ImageID' <<< "$json")"


    colorEcho 'YELLOW' '\nExecuting'; echo -en ' container '; colorEcho 'GREEN' "$name\\n"
    colorEcho 'blue'   'Container Name:   '; echoImage "$name\\n" "$name\\n"
    colorEcho 'blue'   '            ID:   '; echo "${containerId:-}"
    colorEcho 'blue'   '         Image:   '; echoImage "${image}\\n" "$image\\n"
    colorEcho 'blue'   '      Image Id:   '; echoSHA256 "$imageId\\n"

    # add Network info, Volume mounts
    colorEcho 'blue'   '        Status:   '; echo "$(jq -r '"\(.State): \(.Status)"' <<< "$json")"
    local network=$(jq '. as $c| $c.NetworkSettings.Networks| to_entries[]| select(.key==$c.HostConfig.NetworkMode)' <<< "$json")
    colorEcho 'blue'   '       Network:   '; echo "$(jq -r '.key' <<< "$network")"
    colorEcho 'blue'   '    IP Address:   '; echo "$(jq -r '.value.IPAddress' <<< "$network")"

    echo
}

#------------------------------------------------------------------------------------------
function showContainers()
{
    [ "${#MATCHED_CONTAINER_IDS[*]}" -gt 0 ] || return 0

    local id
    for id in "${MATCHED_CONTAINER_IDS[@]}"; do
        [ -z "$id" ] && continue
        showContainerInfo "$id"
    done
    return 0
}

#------------------------------------------------------------------------------------------
function showImages()
{
    [ "${#MATCHED_IMAGE_IDS[*]}" -eq 0 ] && return 0

    echo
    local id
    for id in "${MATCHED_IMAGE_IDS[@]}"; do
        [ -z "$id" ] && continue
#        showImageDependents "$id"
        showImageLayers "$id"
        echo
    done
    return 0
}

#------------------------------------------------------------------------------------------
function showImageDependents()
{
    local id=${1:?"Input parameter 'id' must be passed to 'function ${FUNCNAME[0]}()'"}

    local refImage="${IMAGE_IDS[$id]:-}"

    local dependant

#    mapfile -t IMAGE_JSON < <(jq -c '.[]' <<< "$imagesjson")
#    mapfile -t IMAGE_IDS < <(jq -r '.[].Id' <<< "$imagesjson")
#    mapfile -t IMAGE_REPOTAG_MAP < <(jq -r '.[].RepoTags[0]|if .=="<none>:<none>" then .="" else . end' <<< "$imagesjson")
#    mapfile -t IMAGE_PARENT

#    mapfile -t CONTAINER_JSON < <(jq -c '.[]' <<< "$containersjson")
#    mapfile -t CONTAINER_IDS < <(jq -r '.[].Id' <<< "$containersjson")
#    mapfile -t CONTAINER_NAMES < <(jq -r '.[].Names[0]|ltrimstr("/")' <<< "$containersjson")
#    mapfile -t CONTAINER_IMAGES < <(jq -r '.[].Image' <<< "$containersjson")_IDX < <(imageIdToIndex "${image_parent_ids[@]}")


    local -a dependants_found display
    mapfile -t dependants_found < <(dependantsOf "$id")
    if [ -z ${refImage:-} ] || [ ${#dependants_found[*]} -eq 0 ]; then
        echo -n 'No dependencies found for '; colorEcho 'GREEN' "$refImage\\n"
        return 0
    fi


    # determine what to display
    local -a display=()
    for dependant in "${dependants_found[@]}"; do
        [ "${IMAGES[$dependant]:-}" ] || continue
        [ "${IMAGES[$dependant]}" != '<none>:<none>' ] || continue
        display+=( "$dependant" )
    done


    # report image dependants
    if [ ${#display[*]} -eq 0 ]; then
        echo -en 'No images depend on '; colorEcho 'GREEN' "$refImage\\n"
    else
        colorEcho 'YELLOW' 'Images'; echo -en ' which '; colorEcho 'cyan' 'depend on '; echoImage "$refImage\\n"
        for dependant in "${display[@]}"; do
            showImageInfo "$dependant" "$refImage"
        done
    fi
}

#------------------------------------------------------------------------------------------
function showImageInfo()
{
    local -r iid=${1:?"Input parameter 'id' must be passed to 'function ${FUNCNAME[0]}()'"}
    local -r refId=${2:?"Input parameter 'refId' must be passed to 'function ${FUNCNAME[0]}()'"}

    echo -en "    "
    echoSHA256 "$image "
    echoImage "${IMAGES[$image]}\\n" "$refImage\\n"

    if [ "$image" = "$refImage" ]; then
        showImageLayers "$image"
        showLabels "$image"
    fi
}

#------------------------------------------------------------------------------------------
function showImageLayers()
{
    local id=${1:?"Input parameter 'id' must be passed to 'function ${FUNCNAME[0]}()'"}

#    mapfile -t CONTAINER_JSON < <(jq -c '.[]' <<< "$containersjson")
#    mapfile -t CONTAINER_IDS < <(jq -r '.[].Id' <<< "$containersjson")
#    mapfile -t CONTAINER_NAMES < <(jq -r '.[].Names[0]|ltrimstr("/")' <<< "$containersjson")
#    mapfile -t CONTAINER_IMAGES < <(jq -r '.[].Image' <<< "$containersjson")
#
#    mapfile -t IMAGE_JSON < <(jq -c '.[]' <<< "$imagesjson")
#    mapfile -t IMAGE_IDS < <(jq -r '.[].Id' <<< "$imagesjson")
#    mapfile -t IMAGE_REPOTAG_MAP < <(jq -r '.[].RepoTags[0]|if .=="<none>:<none>" then .="" else . end' <<< "$imagesjson")
#    mapfile -t IMAGEID_PARENTID_MAP < <(imageIdToIndex "${image_parent_ids[@]}")

    local -i imageCount namedImageCount
    local layer=$id
    image="${IMAGE_IDS[$id]:-}"
    imageName="${IMAGE_REPOTAG_MAP[$id]:-}"
#    [ -z "${image:-}" ] && return 0

    # now show what this image depends on
    imageCount=0
    namedImageCount=0
    colorEcho 'YELLOW' 'Layers'; echo -en ' contained in '; colorEcho 'GREEN' "$imageName"'\n'
set -x
    while [ "$layer" ]; do
        if [ -z "${IMAGE_IDS[$layer]:-}" ]; then
            [ $IS_LAYERS -eq 0 ] || (echo -n '    ' ; echoSHA256 "${IMAGE_IDS[$layer]}\\n")
        else
            (( ++namedImageCount )) || :
            echo -n '    '; echoSHA256 "$layer "
            echoImage "${IMAGE_IDS[$layer]}\\n" "$image\\n"
            local -a digests=( $(dockerImageInfo "$layer" | jq -r '.RepoDigests[]|sub("^.*@";"")') )
            if [ "${#digests[*]}" -gt 0 ]; then
                colorEcho 'blue' '  RepoDigests:   '; colorEcho 'magenta' "${digests[0]}"'\n'
                [ "${#digests[*]}" -gt 1 ] && printf '                 \e[35m%s\e[0m\n' "${digests[@]:1}"
            fi
            [ $IS_LABELS -eq 0 ] && [ "${IMAGE_IDS[$id]}" != "$image" ] || showLabels "$layer"
        fi
        (( ++imageCount )) || :
        layer="${IMAGE_LAYERS[$layer]:-}"
    done
set +x
    echo -n '    '
    echoImage "$imageName"
    echo -en ' contains '
    colorEcho 'cyan' "${namedImageCount} named images"
    echo -en ' in a total of '
    colorEcho 'cyan' "${imageCount}"' layers\n'
}

#------------------------------------------------------------------------------------------
function showLabels()
{
    local image=${1:?"Input parameter 'image' must be passed to 'function ${FUNCNAME[0]}()'"}


    local -a labels=( $(docker inspect "$image" |  jq -r 'try .[].Config.Labels | to_entries[] | "\(.key)=\(.value)"') )
    [ "${#labels[*]}" -eq 0 ] && return 0

    colorEcho 'blue'   '       Labels:   '; echo "${labels[0]}"

    local -a refs=()
    local -i idx=-1
    for (( i=${#labels[*]}-1; i>=0; i-- )); do
        if [[ "${labels[i]:-}" == 'container.git.refs=('* ]]; then
            idx=$i
        elif [[ "${labels[i]:-}" == ' '* ]]; then
            refs+=( "${labels[i]}" )
            unset labels[i]
            [ $idx -gt 0 ] && (( --idx ))
        fi
    done
    [ ${#refs[*]} -gt 0 ] && labels[$idx]=${labels[$idx]}$(printf ',%s' "${refs[@]}")
    printf '                 %s\n' "${labels[@]:1}"
}

#------------------------------------------------------------------------------------------
function verbose()
{
    [ $IS_VERBOSE -eq 0 ] && return 0
    if [ $# -gt 0 ]; then
        echo -e "$*"  >&2
    fi
}

#------------------------------------------------------------------------------------------

declare start=$(date +%s)
main "$@"
declare finish=$(date +%s)
declare -i elapsed=$(( finish - start ))
printf '\nTime elapsed: %02d:%02d:%02d\n'  $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60))
exit 0
