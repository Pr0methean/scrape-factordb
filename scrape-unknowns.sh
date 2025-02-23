#!/bin/bash
set -u
origstart=$start
let "start = $origstart"
let "perpage = $perpage"
# let "half_perpage = 0"
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
while true; do
if [ $origstart -eq -1 ]; then
  let "start = $RANDOM"
fi
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
echo $url
assign_urls=$(sem --id 'factordb-curl' --ungroup --fg -j 4 wget -e robots=off --no-check-certificate -nv -O- -o /dev/null "${url}" \
  | pup 'a[href*="index.php?id"] attr{href}' \
  | uniq \
  | tac \
  | sed 's_.*index.php_https://factordb.com/index.php_' \
  | sed 's_$_\&prp=Assign+to+worker_')
let "remaining = $perpage"
let "redundant = 0"
declare assign_url
while read -r assign_url; do
    result=$(sem --id 'factordb-curl' --ungroup -j 4 xargs wget -e robots=off --no-check-certificate -nv -O- <<< "${assign_url}" | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
    echo $result
    let "should_fetch_anew = 0"
    grep -q '\(>C<\|>PRP<\|>P<\|>CF<\|>FF<\)' <<< $result
    if [ $? -eq 0 ]; then
        # Increased penalties for conflicting work that has already *finished*
        let "start++"
        let "perpage--"
        let "redundant++"
        # sleep 0.5
    else
        grep -q 'already in queue' <<< $result
        if [ $? -eq 0 ]; then
            let "start++"
            let "perpage--"
            let "redundant++"
            # sleep 2
        fi
    fi
    if [ $redundant -ge 3 ]; then
        # Results are or will be out of date; wait and then run a new search
        let "perpage -= $remaining"
        if [ $perpage -lt 10 ]; then
            let "perpage = 10"
        fi
        # if [ $remaining -gt $perpage ]; then
        #     let "remaining = $perpage"
        # fi
        # let "start += $remaining"
        let "start += $perpage"
        if [ $start -gt $((100000 + $perpage)) ]; then
            let "start = 100000 + $perpage"
        fi
        break
    fi
    grep -q 'Assigned' <<< $result
    if [ $? -eq 0 ]; then
  #      if [ $half_perpage -gt 0 ]; then
          let "perpage++"
  #        let "half_perpage=0"
  #      else
  #        let "half_perpage=1"
  #      fi
    else
        grep -q 'Please wait' <<< $result
        if [ $? -eq 0 ]; then
            let "start--"
            # sleep 0.5
        fi
    fi
    let "remaining--"
done <<< "${assign_urls}"
if [ $start -lt 0 ]; then
    let "start = 0"
fi
if [ $perpage -gt 5000 ]; then
    let "perpage = 5000"
fi
 #
 #    | xargs wget -e robots=off -nv -w "$delay" -O /tmp/lastscrape || true
done
