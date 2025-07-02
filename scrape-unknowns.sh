#!/bin/bash
set -u
let "start = 0"
let "perpage = 6"
let "min_delay = 1"
let "max_delay = 45"
let "delay = ${min_delay} * 2"
let "delay_increment = 5"
let "valid = 0"
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
while true; do
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
assign_urls=$(sem --id 'factordb-curl' -j 4 xargs wget -e robots=off --no-check-certificate --retry-connrefused --retry-on-http-error=502 -T 30 -t 3 -nv -O- <<< "${url}" \
  | grep -o 'index.php?id=[0-9]\+' \
  | uniq \
  | tac \
  | sed 's_.\+_https://factordb.com/&\&prp=Assign+to+worker_')
let "remaining = $perpage"
let "search_succeeded = 0"
results=$(sem --id 'factordb-curl' -j 4 xargs -n 2 wget -e robots=off --no-check-certificate -nv -O- -T 30 -t 3 --retry-connrefused --retry-on-http-error=502 <<< "${assign_urls}" | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
    echo $results
    grep -q 'Please wait' <<< $results
    if [ $? -eq 0 ]; then
      let "valid = 1"
      if [ $delay -lt $delay_increment ]; then
        let "delay *= 2"
      else
        let "delay += $delay_increment"
        if [ $delay -gt $max_delay ]; then
          let "delay = $max_delay"
        fi
      fi
      # adjust for the extra delay of loading more search results
      sleep $(($delay - 1))
    else
      grep -q 'Assigned' <<< $results
      if [ $? -eq 0 ]; then
        let "valid += 1"
        # The following must round down to $min_delay from $min_delay + 1
        let "delay = (17 * $delay + 5) / 20"
        if [ $delay -lt $min_delay ]; then
          let "delay = $min_delay"
        fi
      fi
    fi
if [ $valid -ge 3 ]; then
  let "start = 0"
  let "valid = 0"
elif [ ${search_succeeded} -eq 0 -a ${start} -gt 0 ]; then
  let "start = 0"
  let "valid = 0"
else
  let "start += $perpage"
fi
done
