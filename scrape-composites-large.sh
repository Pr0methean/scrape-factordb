#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 99999999"
while [ $job -ge "64680" ]; do # Select random point in the 11*210 cycle
  let "job = $(openssl rand 2 | od -DAn)"
done
let "id = 1"
let "minute_ns = 60 * 1000 * 1000 * 1000"
let "hour_ns = 60 * ${minute_ns}"
while [ ! -f "${fifo_id}" ]; do
  let "start = (($job * 91) % 210) * 500"
  let "now = $(date +%s%N)"
  let "day_start = (${now} / (24 * ${hour_ns})) * (24 * ${hour_ns})"
  let "now_ns_of_day = ${now} - ${day_start}"
  if [ ${now_ns_of_day} -lt $((16 * ${hour_ns})) ]; then
    # when starting between 00:00 and 16:00 UTC (16:00 and 08:00 PST), softmax extends until 16:00 UTC
    let "min_softmax_ns = 16 * ${hour_ns} - ${now_ns_of_day}"
    let "extra_digits = 3"
  else
    let "min_softmax_ns = 0"
    let "extra_digits = 0"
  fi
  let "digits = 89 + (($job * 4) % 11) + ${extra_digits}" # Range of 89-99 digits during day, 92-102 at night
  let "softmax_ns = (150 - ${digits}) * ${minute_ns}"
  if [ ${softmax_ns} -lt ${min_softmax_ns} ]; then
    let "softmax_ns = ${min_softmax_ns}"
  fi
  echo "threads=1 digits=${digits} start=${start} softmax_ns=${softmax_ns} id=${id} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
  let "id++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-large-threads' --ungroup
