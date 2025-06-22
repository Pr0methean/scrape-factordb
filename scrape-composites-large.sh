#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 99999999"
while [ $job -ge "16750440" ]; do # Select random point in the 17*23*210 cycle
  let "job = $(openssl rand 3 | od -DAn)"
done
let "id = 1"
while [ ! -f "${fifo_id}" ]; do
  let "digits = 105 - (($job * 8) % 17)" # Range of 89-105 digits
  let "start = (($job * 91) % 210) * 500"
  if [ $digits -le 93 ]; then
    if [ $start -ge 100000 ]; then
      # Results past 100500 will only be returned as part of a page of more than 500
      # so we switch to pages of 5000 for that size.
      let "perpage = 20"
    else
      let "perpage = 2"
    fi
  elif [ $digits -le 100 -a $start -ge 100000 ]; then
    let "perpage = 2"
  else
    let "perpage = 1"
  fi
  echo "digits=${digits} start=${start} perpage=${perpage} id=${id} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
  let "id++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-large-threads' --ungroup
