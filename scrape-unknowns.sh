#!/bin/bash
set -u
let "start = 0"
let "perpage = 3"
let "delay = 6"
let "min_delay = 1"
let "max_delay = 45"
let "delay_increment = 5"
let "valid = 0"
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
let "remaining = $perpage"
while read -r assign_url; do
    let "remaining -= 1"
    result=$(sem --id 'factordb-curl' --ungroup -j 4 xargs wget -e robots=off --no-check-certificate -nv -O- <<< "${assign_url}" | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
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
          let "delay += 5"
          if [ $delay -gt $max_delay ]; then
            let "delay = $max_delay"
          fi
        fi
      else
        continue
      fi
    fi
    if [ $remaining -eq 0 ]; then
      # adjust for the extra delay of loading more search results
      sleep $(($delay - 1))
    else
      sleep ${delay}
    fi
done <<< "${assign_urls}"
if [ $valid -ge $(( $perpage + $perpage )) ]; then
  let "start = 0"
  let "valid = 0"
else
  let "start += $perpage"
fi
done
