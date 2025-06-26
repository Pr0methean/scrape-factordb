#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 99999999"
while [ $job -ge "16666650" ]; do # Select random point in the 13*37*1050 cycle
  let "job = $(openssl rand 3 | od -DAn)"
done
let "id = 1"
while [ ! -f "${fifo_id}" ]; do
  echo "threads=1 job=${job} id=${id} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
  let "id++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-large-threads' --ungroup
