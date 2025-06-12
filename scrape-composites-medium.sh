#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 1"
sizes=(30 22 16 11 8 6 4 3 2 1 1 1 1)
while [ ! -f "${fifo_id}" ]; do
  let "digits = (($job * 7) % 13) + 76" # Range 76-88 digits
  let "perpage = ${sizes[($job % 13)]}"
  let "start = 0"
  echo "digits=${digits} start=${start} perpage=${perpage} id=${job} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-medium-threads' --ungroup
