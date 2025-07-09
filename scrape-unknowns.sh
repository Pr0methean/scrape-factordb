#!/bin/bash
set -u
let "start = 0"
let "perpage = 1"
let "total_assigned = 0"
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
while true; do
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
echo "$(date -Iseconds): searching ${url}"
all_results=$(sem --fg --id 'factordb-curl' -j 4 wget -e robots=off --no-check-certificate --retry-connrefused --retry-on-http-error=502 -T 30 -t 3 -q -O- -- "${url}" \
  | grep '#BB0000' \
  | grep -o 'index.php?id=[0-9]\+' \
  | uniq \
  | tac \
  | sed 's_.\+_https://factordb.com/&\&prp=Assign+to+worker_' \
  | sem --fg --id 'factordb-curl' -j 4 xargs -n 3 wget -e robots=off --no-check-certificate -q -T 30 -t 3 --retry-connrefused --retry-on-http-error=502 -O- \
  | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
echo "$all_results"
assigned=$(grep -c 'Assigned' <<< $all_results)
please_waits=$(grep -c 'Please wait' <<< $all_results)
if [ $please_waits -gt 0 ]; then
  if [ $assigned -eq 0 ]; then
    echo "No assignments made; waiting 10 seconds before retrying"
    sleep 10
  elif [ $please_waits -ge $assigned ]; then
    echo "Too few assignments made; waiting 5 seconds before retrying"
    sleep 5
  fi
fi
let "total_assigned += $assigned"
let "old_start = $start"
let "old_perpage = $perpage"
if [ $assigned -gt 0 ]; then
  if [ $old_start -gt 0 -a $total_assigned -ge 2 ]; then
    let "start = 0"
    let "total_assigned = 0"
  else
    let "start += $perpage - $please_waits"
  fi
else
  already_queued=$(grep -c 'queue' <<< $all_results)
  if [ $already_queued -gt 0 ]; then
    let "start += $perpage - $please_waits"
  fi
fi
if [ $assigned -ge $(($perpage - 1)) -a $perpage -ge 3 ]; then
  let "perpage = (($assigned + 2) / 3) * 3"
elif [ $assigned -gt 0 ]; then
  if [ $perpage -lt 3 -a $old_start -gt 0 ]; then
    let "perpage += 1"
  elif [ $perpage -ge 3 ]; then
    let "perpage = $assigned + 2"
    if [ $perpage -gt 63 ]; then
      let "perpage = 63"
    else
      let "perpage = ($perpage / 3) * 3"
    fi
  fi
elif [ $perpage -gt 3 ]; then
  let "perpage = 3"
else
  let "perpage = 1"
  if [ $old_start -ge 100000 ]; then
    let "start = 0"
  elif [ $old_perpage -eq 1 ]; then
    let "start += 1"
  fi
fi
done
