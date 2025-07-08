#!/bin/bash
set -u
let "start = 0"
let "perpage = 27"
let "valid = 0"
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
while true; do
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
echo "$(date -Iseconds): searching ${url}"
all_results=$(sem --fg --id 'factordb-curl' -j 4 wget -e robots=off --no-check-certificate --retry-connrefused --retry-on-http-error=502 -T 30 -t 3 -q -O- -- "${url}" \
  | grep -o 'index.php?id=[0-9]\+' \
  | uniq \
  | tac \
  | sed 's_.\+_https://factordb.com/&\&prp=Assign+to+worker_' \
  | sem --fg --id 'factordb-curl' -j 4 xargs -n 3 wget -e robots=off --no-check-certificate -q -T 30 -t 3 --retry-connrefused --retry-on-http-error=502 -O- \
  | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
echo "$all_results"
assigned=$(grep -c 'Assigned' <<< $all_results)
if [ $assigned -gt 0 ]; then
  let "valid += 1"
else
  grep -q 'Please wait' <<< $all_results
  if [ $? -eq 0 ]; then
    echo "No assignments made; waiting 5 seconds before retrying"
    sleep 5
  fi
fi
if [ $valid -ge 2 ]; then
  let "start = 0"
  let "valid = 0"
else
  let "start += $perpage"
fi
let "perpage = (($assigned * 2 + 2) / 3) * 3"
if [ $perpage -lt 3 ]; then
  let "perpage = 3"
elif [ $perpage -gt 63 ]; then
  let "perpage = 63"
fi
done
