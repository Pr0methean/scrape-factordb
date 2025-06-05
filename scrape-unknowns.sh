#!/bin/bash
set -u
let "min_start = 0"
let "max_start = 50"
let "start = $min_start"
let "perpage = 3"
let "waits = 0"
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
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
      let "waits = 0"
    elif [ $waits -lt 4 ]; then
        grep -q 'Please wait' <<< $result
        if [ $? -eq 0 ]; then
            let "waits += 1"
        fi
    fi
    sleep $((2 ** ${waits}))
done <<< "${assign_urls}"
let "start = ($start + $perpage) % ${max_start}"
done
