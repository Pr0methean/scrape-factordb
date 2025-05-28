#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 0"
while [ ! -f "${fifo_id}" ]; do
  let "digits = 71 + (($job * 5) % 8)" # 56 & 72-78 digit range
  let "start = 0"
  if [ $digits -eq 71 ]; then
    let "digits = 56"
#    let "start = ($job % 2) * ($RANDOM + 5000)" # Process either from start or from a random point
    let "perpage = 4"
  elif [ $digits -eq 78 ]; then
#    let "start = ($job % 2) * $RANDOM" # Process either from start or from a random point
    let "perpage = 2"
  else
    let "perpage = 3"
  fi
  echo "digits=${digits} start=${start} perpage=${perpage} id=${job} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-small-threads' --ungroup
