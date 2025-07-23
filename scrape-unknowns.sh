#!/bin/bash
set -u
let "start = 0"
let "perpage = 6"
let "min_perpage = 6"
let "max_perpage = 63"
let "total_assigned = 0"
let "minute_ns = 60 * 1000 * 1000 * 1000"
let "max_delay = 30"
let "min_delay = 2"
let "delay = 20"
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
while true; do
all_results=$(sem --fg --id 'factordb-curl' -j 4 xargs -n 3 wget -e robots=off --no-check-certificate -q -T 30 -t 3 --retry-connrefused --retry-on-http-error=502 -O- -o/dev/null -- <<< "${urls}" \
  | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
echo "$all_results"
assigned=$(grep -c 'Assigned' <<< $all_results)
please_waits=$(grep -c 'Please wait' <<< $all_results)
already=$(grep -c '\(queue\|>C<\|>P<\|>PRP<\)' <<< $all_results)
if [ $(($already + 2)) -ge $perpage ]; then
  let "perpage += 3"
  if [ $perpage -gt $max_perpage ]; then
    let "perpage = $max_perpage"
  else
    echo "Increased number of results per page to $perpage."
  fi
elif [ $(($please_waits + 2)) -ge $perpage -a $perpage -gt $min_perpage ]; then
  let "perpage -= 3"
  echo "Decreased number of results per page to $perpage."
fi
if [ $please_waits -gt 0 -a $assigned -lt 3 ]; then
  if [ $assigned -eq 0 ]; then
    if [ $delay -le 7 ]; then
      let "delay = 10"
    else
      let "delay += 3"
      if [ $delay -gt $max_delay ]; then
        let "delay = $max_delay"
      fi
    fi
    if [ $already -eq 0 ]; then
      let "urls_time_remaining = ${urls_expiry} - $(date +%s%N) - ($delay * 1000 * 1000 * 1000)"
      if [ $urls_time_remaining -lt 0 ]; then
        echo "$(date -Iseconds): No assignments made, and no results already assigned; giving up on current search and waiting $delay seconds for next search"
        sleep "$delay"
        break
      fi
      echo "$(date -Iseconds): No assignments made, and no results already assigned; waiting $delay seconds before retrying same search"
      sleep "$delay"
    else
      echo "$(date -Iseconds): No assignments made, but some results already assigned; waiting $delay seconds before next search"
      sleep "$delay"
      break
    fi
  elif [ $please_waits -ge $assigned ]; then
    if [ $delay -le 6 ]; then
      let "delay = 7"
    else
      let "delay += 1"
      if [ $delay -gt $max_delay ]; then
        let "delay = $max_delay"
      fi
    fi
    echo "$(date -Iseconds): Too few assignments made; waiting $delay seconds before next search"
    sleep "$delay"
    break
  else
    if [ $delay -lt 4 ]; then
      let "delay = 4"
    fi
    echo "$(date -Iseconds): 'Please wait' received; waiting $delay seconds before next search"
    sleep "$delay"
    break
  fi
elif [ $assigned -gt 0 ]; then
  let "delay -= 5"
  if [ $delay -lt $min_delay ]; then
    let "delay = $min_delay"
  fi
  echo "$(date -Iseconds): Enough assignments made; waiting $delay seconds before next search"
  sleep "$delay"
  break
else
  # we got neither 'assigned' nor 'please wait' so our search wasn't helpful and we should do a bigger one now
  break
fi
done
let "total_assigned += $assigned"
let "old_start = $start"
let "advance = $already + $assigned"
if [ $old_start -gt 0 -a $total_assigned -ge 6 ]; then
  let "start = 0"
  let "total_assigned = 0"
  let "delay -= (old_start / 3)"
  if [ $delay -lt $min_delay ]; then
    let "delay = $min_delay"
  fi
elif [ $(($old_start + $advance)) -gt 100000 ]; then
  let "start = 0"
  let "total_assigned = 0"
  let "delay = $min_delay"
else
  let "start += $advance"
fi
done
