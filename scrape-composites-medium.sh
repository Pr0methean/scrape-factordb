#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 99999999"
while [ $job -ge "65531" ]; do # Select random point in the cycle of 19
  let "job = $(openssl rand 2 | od -DAn)"
done
let "id = 1"
let "minute_ns = 60 * 1000 * 1000 * 1000"
let "hour_ns = 60 * ${minute_ns}"
while [ ! -f "${fifo_id}" ]; do
  let "start = 0"
  let "now = $(date +%s%N)"
  let "day_start = ($now / (24 * ${hour_ns})) * (24 * ${hour_ns})"
  let "now_ns_of_day = ${now} - ${day_start}"
  if [ ${now_ns_of_day} -lt $((15 * ${hour_ns})) -a ${now_ns_of_day} -gt $((2 * ${hour_ns})) ]; then
    # softmax ends at 16:00 UTC (08:00 PST)
    let "min_softmax_ns = 16 * ${hour_ns} + ${day_start} - ${now}"
  else
    let "min_softmax_ns = 0"
  fi
  let "digits = 70 + (($job * 11) % 19)" # Range of 70-88 digits
  let "softmax_ns = (150 - ${digits}) * ${minute_ns}"
  if [ ${softmax_ns} -lt ${min_softmax_ns} ]; then
    let "softmax_ns = ${min_softmax_ns}"
  fi
  echo "threads=1 digits=${digits} start=${start} softmax_ns=${softmax_ns} id=${id} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
  let "id++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-medium-threads' --ungroup
