#!/bin/bash
set -u
let "start = 0"
let "perpage = 1"
let "min_perpage = 1"
let "max_perpage = 3"
let "total_assigned = 0"
let "minute_ns = 60 * 1000 * 1000 * 1000"
let "min_restart = 10"
let "max_delay = 30"
let "min_delay = 2"
let "delay = 20"
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
for (( size=104; size>=104; size-- )); do
let "entries = 0"
while IFS=, read -r id expr; do
url="https://factordb.com/?id=${id}\&prp=Assign+to+worker"
while true; do
  result=$(sem --fg --id 'factordb-curl' -j 2 xargs -n 3 wget -e robots=off --no-check-certificate -q -T 30 -t 3 --retry-connrefused --retry-on-http-error=502 -O- -o/dev/null -- <<< "${url}" \
    | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
  echo $result
  grep -q 'Please wait' <<< $result
  if [ $? -eq 0 ]; then
    echo "Got 'Please wait' for $id"
    sleep 30
  else
    break
  fi
done
let "entries += 1"
echo "Processed ${entries} entries in U${size}000.csv"
done < U${size}000.csv
done
