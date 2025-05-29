#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 99999999"
while [ $job -ge "16718400" ]; do
  let "job = $(openssl rand 3 | od -DAn)"
done
while [ ! -f "${fifo_id}" ]; do
  let "digits = 95 - (($job * 5) % 9)" # Range of 87-95 digits
  if [ 13 -eq $(( (job % 43) % 23 )) ]; then
    let "start = 100000"
  else
    let "start = (($job * 91) % 200) * 500"
  fi
  echo "digits=${digits} start=${start} perpage=1 id=${job} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-large-threads' --ungroup
