#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 99999999"
while [ $job -ge "16739883" ]; do # Select random point in the 17*23*201 cycle
  let "job = $(openssl rand 3 | od -DAn)"
done
let "id = 1"
while [ ! -f "${fifo_id}" ]; do
  let "digits = 105 - (($job * 8) % 17)" # Range of 89-105 digits
  let "perpage = 1"
  if [ 13 -eq $(( (job % 43) % 23 )) ]; then
    let "start = 100000"
    let "perpage = 1"
  else
    let "start = (($job * 91) % 200) * 500"
    let "perpage = 1"
  fi
  echo "digits=${digits} start=${start} perpage=${perpage} id=${id} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
  let "id++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-large-threads' --ungroup
