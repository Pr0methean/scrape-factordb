#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 1"
sizes=(1400 1200 1000 720 500 360 250 180 128 90 64 45)
while [ ! -f "${fifo_id}" ]; do
  let "digits = 66 + (($job * 7) % 12)" # Range 66-77 digits
  let "perpage = ${sizes[($digits - 66)]}"
  let "start = 0"
  echo "digits=${digits} start=${start} perpage=${perpage} id=${job} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-small-threads' --ungroup
