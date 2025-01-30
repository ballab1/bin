#!/bin/bash
# NAME       : cri-purge.sh
#
# DESCRIPTION: This script will parse the output of "crictl images" to
#           determine older images that can be pruned.  Unlike "--prune"
#           option this will not delete all images that are not in use on
#           this specific node.  It will only attempt to delete old versions
#           of the image
#
# ASSUMPTION: The output of CRICTL is processed in best effort to maintain
#           semantic version order from oldest to newest (v1.7.1, v1.8.0,
#           v1.8.1, v1.8.2, v1.9.0) with the goal to only retain the newest
#           version.
#
#           This script requires root permissions to access the CRICTL binary.
#
AUTHOR="Richard J. Durso"
RELDATE="06/10/2024"
VERSION="0.1.2"
#############################################################################

###[ Define Variables ]#######################################################
CRI_CMD="crictl"
CRIINFO_CMD="crio-status"

# By default dangling images with '<none>' tag are skipped.
# Define regex to match images with version of some type 
IMAGE_VERSION_REGEX="^\S+\s+[\w\-_\.\d]+\s+.*"

# Dry run feature is disabled by default
DRY_RUN=0

###[ Routines ]##############################################################
__usage() {
  echo "
  $(basename "$0") | Version: ${VERSION} | ${RELDATE} | ${AUTHOR}

  List and Purge downloaded cached images from containerd.
  -----------------------------------------------------------------------------

  This script requires sudo access to CRICTL (or CRIO-STATUS for OpenShift) to
  obtain a list of cached downloaded images and remove specific older images. 
  It will do best effort to honor semantic versioning always leaving the newest
  version of the downloaded image and only purge previous version(s).

  -h,   --help            : This usage statement.
  -dp,  --dry-run         : Dry run --purge, Do not actually purge any images.
  -dpd, --dry-run-dangling: Same as --dry-run, but include dangling images.
  -l,   --list            : List cached images and purgable versions.
  -p,   --purge           : List images and PURGE/PRUNE older versioned images.
  -pd,  --purge-dangling  : Same as --purge, but include dangling images.
  -s,   --show-dangling   : List dangling images with '<none>' tag.

  "
}

###[ Make Temp Working Files ]###############################################
# Create unique temp files to store working data
CRI_IMAGES=$(mktemp "/tmp/$(basename "$0").XXXXXX")
CRI_IMAGES_SKIP=$(mktemp "/tmp/$(basename "$0").XXXXXX")
UNIQUE_CRI_IMAGE_NAMES=$(mktemp "/tmp/$(basename "$0").XXXXXX")

# Create trap to cleanup files
trap 'rm -f $CRI_IMAGES $CRI_IMAGES_SKIP $UNIQUE_CRI_IMAGE_NAMES' EXIT

###[ Determine ContainerD Location]##########################################
# Try to determine where the CRI image store is to located.  Used to calculate
# disk space differences before and after a image purge.

__determine_containerd_root_dir() {
  # Parse output of CRICTL INFO looking for containerdRootDir
  IMAGE_STORE=$(${CRI_CMD} info | awk -F'"' '/containerdRootDir/{print $4}')

  # Pase output of CRIO-STATUS looking for storage root directory
  [ -z "${IMAGE_STORE}" ] && IMAGE_STORE=$(crio-status info | awk -F'storage root: ' '/storage root:/ {print $2}')

  # Unable to find image store
  [ ! -d "${IMAGE_STORE}" ] && echo "NOTE: Unable to determine containerd root directory!";echo
}

###[ Generate Image List ]###################################################
# This will load a list of currently cached images that were previously
# downloaded and store this in temp file CRI_IMAGES. Images with TAG '<none>'
# (dangling) by default are skipped and placed in temp file CRI_IMAGES_SKIP.
# Some basic statistics are gathered as well:
#
#    TOTAL_CRI_IMAGES = Integer value of images found minus skipped images
#    UNIQUE_CRI_IMAGE_NAMES = array of unique image names without version
#    TOTAL_UNIQUE_IMAGE_NAMES = Integrer value of UNIQUE_CRI_IMAGE_NAMES
#
# CRI_IMAGES will have a data lines formated as:
# docker.io/library/traefik                                  2.8.0                  b5f5bb1d51fd8       31.5MB
# docker.io/library/traefik                                  2.8.4                  9d00af07cc7c9       33.3MB
# docker.io/library/traefik                                  2.8.5                  2caeed3432ab5       33.3MB
# docker.io/library/traefik                                  2.8.7                  e3d8309b974e3       33.3MB

__generate_image_list() {

  # load list of images / filter out header line / version sort on 60th char of line
  ${CRI_CMD} images | tail -n +2 | sort -k 1.60 -V > "${CRI_IMAGES}"

    # If purging dangling images, don't skip them
    if [ "${1^^}" != "PURGE-DANGLING" ]; then
      # sort untagged images to group together in output
      grep -vP "${IMAGE_VERSION_REGEX}" "${CRI_IMAGES}" | sort > "${CRI_IMAGES_SKIP}"

      # Show list of dangling images being skipped
      if [ "$(grep -c '^' "${CRI_IMAGES_SKIP}")" -ne 0 ]; then
        echo "NOTE: Dangling Images:"
        cat "${CRI_IMAGES_SKIP}"
      fi
      grep -oP "${IMAGE_VERSION_REGEX}" "${CRI_IMAGES}" > "${CRI_IMAGES}_"
      mv -f "${CRI_IMAGES}_" "${CRI_IMAGES}"
    fi
    echo

  TOTAL_CRI_IMAGES=$(grep -c '^' "${CRI_IMAGES}")

  # Reduce raw image list to unique names (without version)
  awk '{ print $1 }' "${CRI_IMAGES}" | sort -u > "${UNIQUE_CRI_IMAGE_NAMES}"
  TOTAL_UNIQUE_IMAGE_NAMES=$(grep -c '^' "${UNIQUE_CRI_IMAGE_NAMES}")
}

###[ Reorder Hash Vales ]#####################################################
# If elements in array IMAGES are of an unversioned image (tag "<none>") then
# loop through the elements to see if its associated to a running container.
# If so swap it with the last element in the array to match placement of a 
# versioned image where last element is likely highest version number to keep.

# Edge case - possible more than one hash could be associated with a running
# container. This is assumed rare and not handled. Only one is retained. If 
# none are associated with a running container, still one will be retained.

__reorder_hash_vales() {
  local i=0
  local elements=${#IMAGES[@]}-1 
  local SWAP=""

  # Only reorder if this is a unversioned image
  for (( i=0; i<$(( elements )); i++ ))
  do
    TAG_REF=$(__get_tag_ref $i)

    if [ "$TAG_REF" = "\$3" ]; then
      # See if image has is associated to a running container
      if [ -n "$( ${CRI_CMD} ps --image "$(echo "${IMAGES[$i]}" |awk '{ printf "%s\n", $3 }')" -q)" ];
      then
        # If last image in array has a version tag, do not replace it.
        # Try to preserve versions and purge dangling images
        if [ "$(echo "${IMAGES[$elements]}" | awk '{ print $2 }')" = "<none>" ]; then
          # swap elment $i with last element
          SWAP="${IMAGES[$elements]}"

          IMAGES[elements]="${IMAGES[$i]}"
          IMAGES[i]=$SWAP
        fi
      fi
    fi
  done
}

###[ Get Image TAG ]##########################################################
# Return image TAG, if image has TAG "<none>" then return its hash value
__get_tag_ref() {
  local result=""
  # Get tag reference from an item (if <none>, use its hash instead)
  if [ "$(echo "${IMAGES[@]: -$1}" | awk '{ print $2 }')" = "<none>" ]; then
    result="\$3"
  else
    result="\$2"
  fi
  echo $result
}

###[ Process Image List ]#####################################################
# List or optionally PURGE images from disk cache.  This route will attempt to
# keep one version for each uniquely named application image. Ideally the most
# recently downloaded image is retained and all older versions are purged to
# free up local disk storage.
#
# If $1 is "PURGE" then this routine will act and purge specific image(s), any
# other value will just display of a list of images that could be purged.

__process_images() {
  # Create Image List to Process
  __generate_image_list "${1^^}"

  echo
  ((DRY_RUN)) && echo "DRY-RUN - No images will be purged."
  echo "Total Images: ${TOTAL_CRI_IMAGES} Unique Versioned Images Names: ${TOTAL_UNIQUE_IMAGE_NAMES}"
  echo
  COUNT=0
  while read -r IMAGE_NAME; # Do not quote UNIQUE_CRI_IMAGE_NAMES, breaks for loop
  do
    ((COUNT=COUNT+1))
    echo -n "${COUNT} / ${TOTAL_UNIQUE_IMAGE_NAMES} : Image: ${IMAGE_NAME}"

    # Find all versions of this IMAGE_NAME
    mapfile -t IMAGES <<< "$(grep "${IMAGE_NAME}" "${CRI_IMAGES}")"
    NUM_IMAGES=${#IMAGES[@]}

    # If only 1 version detected, keep it.
    if [[ ${NUM_IMAGES} -eq 1 ]]; then
      TAG_REF=$(__get_tag_ref 0)
      echo " - Keep TAG: $(echo "${IMAGES[0]}" | awk "{ printf \"%s (%s)\n\", $TAG_REF, \$4 }")"
    else
      # For dangling image, determine if image hash is associated with running container and reorder array
      [ "${1^^}" == "PURGE-DANGLING" ] && __reorder_hash_vales

      # print last line of the array, should be one to keep.
      TAG_REF=$(__get_tag_ref 1)
      echo " - Keep TAG: $(printf %s\\n "${IMAGES[@]: -1}"| awk "{ printf \"%s (%s)\n\", $TAG_REF, \$4 }")"

      for (( i=0; i<$(( ${#IMAGES[@]}-1 )); i++ ))
      do
        # Remove image if $1 == "PURGE"
        TAG_REF=$(__get_tag_ref $i)
        if [ "${1^^}" == "PURGE" ] || [ "${1^^}" == "PURGE-DANGLING" ]; then
          echo "- Purge TAG: $( echo "${IMAGES[$i]}" | awk "{ printf \"%s (%s)\n\", $TAG_REF, \$4 }")"

          # Remove the Specific Image:TAG, or by a hash (if tag=<none>)
          if [ "$TAG_REF" = "\$3" ]; then
            # Only execute if NOT a dry-run
            ! ((DRY_RUN)) && ${CRI_CMD} rmi "$(echo "${IMAGES[$i]}" |awk '{ printf "%s\n", $3 }')" > /dev/null 2>&1
          else
            # Only execute if NOT a dry-run
            ! ((DRY_RUN)) && ${CRI_CMD} rmi "$(echo "${IMAGES[$i]}" |awk '{ printf "%s:%s\n", $1, $2 }')" > /dev/null 2>&1
          fi
        else
          echo "- Purgeable TAG: $( echo "${IMAGES[$i]}" | awk "{ printf \"%s (%s)\n\", $TAG_REF, \$4 }")"
        fi
      done
      echo
    fi
  done < "${UNIQUE_CRI_IMAGE_NAMES}"
}

###[ Main Section ]##########################################################

# Confirm crictl is installed
if ! command -v ${CRI_CMD} >/dev/null 2>&1 && ! command -v ${CRIINFO_CMD} >/dev/null 2>&1 ; then
  echo
  echo "* ERROR: $CRI_CMD/$CRIINFO_CMD commands not found, install missing application or update script variable CRI_CMD/CRIINFO_CMD"
  echo
  exit 2
fi

# Confirm sudo or root equivilant access
if [ "$(id -u)" -ne 0 ]; then
  echo
  echo "* ERROR: ROOT privilege required to access CRICTL binaries."
  __usage
  exit 1
fi

__determine_containerd_root_dir

# Process argument list
if [ "$#" -ne 0 ]; then
  while [ "$#" -gt 0 ]
  do
    case "$1" in
    -h|--help)
      __usage
      exit 0
      ;;
    -v|--version)
      echo "$VERSION"
      exit 0
      ;;
    -l|--list)
      __process_images LIST
      exit 0
      ;;
    -dp|--dry-run)
      # Enable Dry Run 
      DRY_RUN=1
      if [ -d "${IMAGE_STORE}" ]; then
        __process_images "PURGE"
      fi
      ;;
    -dpd|--dry-run-dangling)
      # Enable Dry Run 
      DRY_RUN=1
      if [ -d "${IMAGE_STORE}" ]; then
        __process_images "PURGE-DANGLING"
      fi
      ;;
    -p|--purge)
      if [ -d "${IMAGE_STORE}" ]; then
        START_DISK_SPACE=$(du -ab "${IMAGE_STORE}" | sort -n -r | head -1 | awk '{ print $1 }')
        __process_images "PURGE"
        END_DISK_SPACE=$(du -ab "${IMAGE_STORE}" | sort -n -r | head -1 | awk '{ print $1 }')
        echo
        if [ $((START_DISK_SPACE-END_DISK_SPACE)) -ge 1 ]; then
          echo Disk Space Change: "$(numfmt --to iec --format "%8.2f" $((START_DISK_SPACE-END_DISK_SPACE)) )"
        else
          echo Disk Space Change: none
        fi
        exit 0
      fi
      ;;
    -pd|--purge-dangling)
      if [ -d "${IMAGE_STORE}" ]; then
        START_DISK_SPACE=$(du -ab "${IMAGE_STORE}" | sort -n -r | head -1 | awk '{ print $1 }')
        __process_images "PURGE-DANGLING"
        END_DISK_SPACE=$(du -ab "${IMAGE_STORE}" | sort -n -r | head -1 | awk '{ print $1 }')
        echo
        if [ $((START_DISK_SPACE-END_DISK_SPACE)) -ge 1 ]; then
          echo Disk Space Change: "$(numfmt --to iec --format "%8.2f" $((START_DISK_SPACE-END_DISK_SPACE)) )"
        else
          echo Disk Space Change: none
        fi
      fi
      exit 0
      ;;

    -s|--show-dangling)
      __generate_image_list
      exit 0
      ;;
    --)
      break
      ;;
    -*)
      echo "Invalid option '$1'. Use --help to see the valid options" >&2
      exit 1
      ;;
    # an option argument, continue
    *)  ;;
    esac
    shift
  done
else
  __usage
  exit 1
fi