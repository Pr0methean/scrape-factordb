#!/bin/bash
set -u
fifo_id="/tmp/$(uuidgen)"
mkfifo "${fifo_id}"
let "job = 0"
while [ ! -f "${fifo_id}" ]; do
#  let "digits = 300 - ((job * 89) % 180)" # Range of 121-300 digits
  let "digits = 122 - ((job * 13) % 31)" # Range of 92-122 digits
  if [ 11 -eq $(( job % 23  )) ]; then
    let "start = 100000"
  else
    let "start = (99501 * $RANDOM) / 32767"
  fi
  echo "digits=$digits start=${start} perpage=500 id=$job nice=0 ./scrape-composites.sh" >> "${fifo_id}"
  let "job++"
done &
tail -f "${fifo_id}" | parallel -j '/tmp/scrape-composites-huge-threads' --ungroup
