#!/bin/bash -x

START="$(date  '+%s')"
while read -r image; do
  docker pull "${DOCKER_REGISTRY:-}$image"
  docker tag "${DOCKER_REGISTRY:-}$image" "${DOCKER_REGISTRY:-}$image"
  docker push "${DOCKER_REGISTRY:-}$image"
  docker rmi "${DOCKER_REGISTRY:-}$image" "${DOCKER_REGISTRY:-}$image"
  echo
done < images.txt

declare -i elapsed=$(( $(date '+%s') - START_TIME ))
[ $elapsed -le 2 ] && printf '%02d:%02d:%02d' $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60))
