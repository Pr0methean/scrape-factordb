#!/bin/bash
set -u
let "start = 0"
let "perpage = 3"
let "total_assigned = 0"
let "minute_ns = 60 * 1000 * 1000 * 1000"
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
while true; do
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
echo "$(date -Iseconds): searching ${url}"
urls=$(sem --fg --id 'factordb-curl' -j 4 wget -e robots=off --no-check-certificate --retry-connrefused --retry-on-http-error=502 -T 30 -t 3 -q -O- -o/dev/null -- "${url}" \
  | grep '#BB0000' \
  | grep -o 'index.php?id=[0-9]\+' \
  | uniq \
  | tac \
  | sed 's_.\+_https://factordb.com/&\&prp=Assign+to+worker_')
let "urls_expiry = $(date +%s%N) + 15 * ${minute_ns}"
let "retries = 0"
while true; do
all_results=$(sem --fg --id 'factordb-curl' -j 4 xargs -n 3 wget -e robots=off --no-check-certificate -q -T 30 -t 3 --retry-connrefused --retry-on-http-error=502 -O- -o/dev/null -- <<< "${urls}" \
  | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
echo "$all_results"
assigned=$(grep -c 'Assigned' <<< $all_results)
please_waits=$(grep -c 'Please wait' <<< $all_results)
if [ $please_waits -gt 0 ]; then
  if [ $assigned -eq 0 ]; then
    already=$(grep -c '\(queue\|>C<\|>P<\|>PRP<\)' <<< $all_results)
    if [ $already -eq 0 ]; then
      let "delay = ${retries} * 3 + 10"
      if [ $delay -gt 60 ]; then
        let "delay = 60"
      fi
      let "urls_time_remaining = ${urls_expiry} - $(date +%s%N) - ($delay * 1000 * 1000 * 1000)"
      if [ $urls_time_remaining -lt 0 ]; then
        echo "$(date -Iseconds): No assignments made, and no results already assigned; giving up on current search and waiting $delay seconds"
        sleep "$delay"
        break
      fi
      echo "$(date -Iseconds): No assignments made, and no results already assigned; waiting $delay seconds before retrying same search"
      sleep "$delay"
      let "retries += 1"
    else
      echo "$(date -Iseconds): No assignments made, but some results already assigned; waiting 10 seconds before searching again"
      sleep 10
      break
    fi
  elif [ $please_waits -ge $assigned ]; then
    echo "$(date -Iseconds): Too few assignments made; waiting 7 seconds before retrying"
    sleep 7
    break
  else
    echo "$(date -Iseconds): 'Please wait' received; waiting 4 seconds before retrying"
    sleep 4
    break
  fi
else
  sleep 2
  break
fi
done
let "total_assigned += $assigned"
let "old_start = $start"
already_queued=$(grep -c 'queue' <<< $all_results)
let "advance = $already_queued + $assigned"
if [ $old_start -gt 0 -a $total_assigned -ge 12 ]; then
  let "start = 0"
  let "total_assigned = 0"
elif [ $(($old_start + $advance)) -gt 100000 ]; then
  let "start = 0"
  let "total_assigned = 0"
else
  let "start += $advance"
fi
done
