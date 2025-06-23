#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 99999999"
while [ $job -ge "65520" ]; do # Select random point in the 13*210 cycle
  let "job = $(openssl rand 2 | od -DAn)"
done
let "id = 1"
let "minute_ns = 60 * 1000 * 1000 * 1000"
let "hour_ns = 60 * ${minute_ns}"
while [ ! -f "${fifo_id}" ]; do
  let "digits = 101 - (($job * 8) % 13)" # Range of 89-101 digits
  let "start = (($job * 91) % 210) * 500"
  let "now = $(date +%s%N)"
  let "day_start = ($now / (24 * ${hour_ns})) * (24 * ${hour_ns})"
  let "softmax_ns = (150 - ${digits}) * ${minute_ns}"
  let "now_ns_of_day = ${now} - ${day_start}"
  if [ ${now_ns_of_day} -gt $((18 * ${hour_ns})) ]; then
    # softmax ends at 8am
    let "softmax_ns = 32 * ${hour_ns} + ${day_start} - ${now}"
  elif [ ${now_ns_of_day} -lt $((7 * ${hour_ns})) ]; then
    # softmax can't end before 8am but may end later
    let "min_softmax_ns = 8 * ${hour_ns} + ${day_start} - ${now}"
    if [ ${softmax_ns} -lt ${min_softmax_ns} ]; then
      let "softmax_ns = ${min_softmax_ns}"
    fi
  fi
  if [ $digits -le 93 ]; then
    let "perpage = 2"
  else
    let "perpage = 1"
  fi
  echo "threads=1 digits=${digits} start=${start} softmax_ns=${softmax_ns} id=${id} nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
  let "id++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-large-threads' --ungroup
