#!/bin/bash -x

START="$(date  '+%s')"
while read -r image; do
  docker pull "s4.ubuntu.home:5000/$image"
  docker tag "s4.ubuntu.home:5000/$image"  "s2.ubuntu.home:5000/$image"
  docker push "s2.ubuntu.home:5000/$image"
  docker rmi "s2.ubuntu.home:5000/$image" "s4.ubuntu.home:5000/$image"
  echo
done < images.txt

declare -i elapsed=$(( $(date '+%s') - START_TIME ))
[ $elapsed -le 2 ] && printf '%02d:%02d:%02d' $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60))
