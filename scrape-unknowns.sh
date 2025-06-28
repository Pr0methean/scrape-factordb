#!/bin/bash
set -u
let "start = 0"
let "perpage = 3"
let "min_delay = 1"
let "max_delay = 45"
let "delay = ${min_delay} * 2"
let "delay_increment = 5"
let "valid = 0"
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
while true; do
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
assign_urls=$(sem --id 'factordb-curl' --ungroup -j 4 xargs wget -e robots=off --no-check-certificate --retry-connrefused --retry-on-http-error=502 -T 30 -t 3 -nv -O- <<< "${url}" \
  | grep -o 'index.php?id=[0-9]\+' \
  | uniq \
  | tac)
declare assign_url
let "remaining = $perpage"
let "search_succeeded = 0"
while read -r assign_url; do
    if [ "${assign_url}" == "" ]; then
      continue
    fi
    assign_url="https://factordb.com/${assign_url}\&prp=Assign+to+worker"
    let "search_succeeded = 1"
    let "remaining -= 1"
    result=$(sem --id 'factordb-curl' --ungroup -j 4 xargs wget -e robots=off --no-check-certificate -nv -O- -T 30 -t 3 --retry-connrefused --retry-on-http-error=502 <<< "${assign_url}" | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
    echo $result
    grep -q 'Assigned' <<< $result
    if [ $? -eq 0 ]; then
      let "valid += 1"
      # The following must round down to $min_delay from $min_delay + 1
      let "delay = (17 * $delay + 5) / 20"
      if [ $delay -lt $min_delay ]; then
        let "delay = $min_delay"
      fi
    else
      grep -q 'Please wait' <<< $result
      if [ $? -eq 0 ]; then
        let "valid += 1"
        if [ $delay -lt $delay_increment ]; then
          let "delay *= 2"
        else
          let "delay += $delay_increment"
          if [ $delay -gt $max_delay ]; then
            let "delay = $max_delay"
          fi
        fi
        if [ $remaining -gt 0 ]; then
          sleep ${delay}
        elif [ $delay -gt 1 ]; then
          # adjust for the extra delay of loading more search results
          sleep $(($delay - 1))
        fi
      fi
    fi
done <<< "${assign_urls}"
if [ $valid -ge $(( $perpage + $perpage )) ]; then
  let "start = 0"
  let "valid = 0"
elif [ ${search_succeeded} -eq 0 -a ${start} -gt 0 ]; then
  let "start = 0"
  let "valid = 0"
else
  let "start += $perpage"
fi
done
