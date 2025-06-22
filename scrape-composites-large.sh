#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 99999999"
while [ $job -ge "65520" ]; do # Select random point in the 13*210 cycle
  let "job = $(openssl rand 2 | od -DAn)"
done
let "id = 1"
while [ ! -f "${fifo_id}" ]; do
  let "digits = 101 - (($job * 8) % 13)" # Range of 89-101 digits
  let "start = (($job * 91) % 210) * 500"
  if [ $digits -le 93 ]; then
    let "perpage = 2"
  else
    let "perpage = 1"
  fi
  echo "threads=1 digits=${digits} start=${start} perpage=${perpage} id=${id} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
  let "id++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-large-threads' --ungroup
