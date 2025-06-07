#!/bin/bash
set -u
let "min_start = 0"
let "max_start = 51"
let "start = $min_start"
let "perpage = 3"
let "waits = 0"
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
delays=(2 3 4 5.5 8 11 16 21 30)
let "max_waits = ${#delays[@]} - 1"
while true; do
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
echo $url
assign_urls=$(sem --id 'factordb-curl' --ungroup --fg -j 4 wget -e robots=off --no-check-certificate -nv -O- -o /dev/null "${url}" \
  | pup 'a[href*="index.php?id"] attr{href}' \
  | uniq \
  | tac \
  | sed 's_.*index.php_https://factordb.com/index.php_' \
  | sed 's_$_\&prp=Assign+to+worker_')
declare assign_url
while read -r assign_url; do
    result=$(sem --id 'factordb-curl' --ungroup -j 4 xargs wget -e robots=off --no-check-certificate -nv -O- <<< "${assign_url}" | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
    echo $result
    grep -q 'Assigned' <<< $result
    if [ $? -eq 0 ]; then
      if [ $waits -gt 0 ]; then
        let "waits -= 1"
      fi
    elif [ $waits -lt $max_waits ]; then
        grep -q 'Please wait' <<< $result
        if [ $? -eq 0 ]; then
            let "waits += 1"
        fi
    fi
    sleep ${delays[$waits]}
done <<< "${assign_urls}"
let "start = ($start + $perpage) % ${max_start}"
done
