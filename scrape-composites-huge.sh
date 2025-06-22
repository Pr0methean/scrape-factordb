#!/bin/bash
set -u
let "job = 9999999999"
while [ $job -ge "4294967040" ]; do # Select random point in the 17*210 cycle
  let "job = $(openssl rand 4 | od -DAn)"
done
let "id = 1"
while true; do
  let "digits = 117 - (($job * 8) % 17)" # Range of 101-117 digits
  let "start = (($job * 91) % 210) * 500"
  threads=$(cat /tmp/scrape-composites-huge-threads) digits=${digits} start=${start} perpage=1 id=${id} nice=0 ./scrape-composites.sh
  let "job++"
  let "id++"
done
