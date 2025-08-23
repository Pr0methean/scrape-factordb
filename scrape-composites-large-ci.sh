#!/bin/bash
set -u
fifo_id="/tmp/scrape-composites-fifo"
mkfifo "${fifo_id}"
let "job = 9999999999"
let "max_job = 1641 * 23 * 11 * 10345"
while [ $job -ge "$max_job" ]; do # Select random point in the cycle, with no modulo bias
  let "job = $SRANDOM"
done
let "id = 1"
while [ ! -f "${fifo_id}" ]; do
  echo "threads=1 digits=${digits} id=${id} nice=0 ./scrape-composites-ci.sh" >> "${fifo_id}"
  let "job++"
  let "id++"
done &
tail -f "${fifo_id}" | parallel -j 2 --ungroup
