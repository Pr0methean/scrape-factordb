#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 0"
while [ ! -f "${fifo_id}" ]; do
  let "digits = ($job % 4) + 79" # Range 79-82 digits
  let "start = ($job % 21) * 5000" # Handle numbers clamped to range 0-104999
  echo "digits=${digits} start=${start} perpage=1 id=${job} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-medium-threads' --ungroup
