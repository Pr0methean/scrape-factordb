#!/bin/bash
set -u
origstart=$start
let "min_perpage = 1"
let "max_perpage = 1"
let "start = $origstart"
let "perpage = $perpage"
# let "half_perpage = 0"
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
let "remaining = $perpage"
let "max_redundant = ($perpage + 5)/10"
if [ $max_redundant -gt 15 ]; then
  let "max_redundant = 15"
fi
let "redundant = 0"
declare assign_url
while read -r assign_url; do
    result=$(sem --id 'factordb-curl' --ungroup -j 4 xargs wget -e robots=off --no-check-certificate -nv -O- <<< "${assign_url}" | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
    echo $result
    let "should_fetch_anew = 0"
    grep -q '\(>C<\|>PRP<\|>P<\|>CF<\|>FF<\)' <<< $result
    if [ $? -eq 0 ]; then
        # Increased penalties for conflicting work that has already *finished*
        let "start += 5"
        let "perpage -= 10"
        let "redundant++"
        sleep 1
    else
        grep -q 'already in queue' <<< $result
        if [ $? -eq 0 ]; then
            let "start += 5"
            let "perpage -= 5"
            let "redundant++"
            sleep 0.5
        fi
    fi
    if [ $redundant -gt $max_redundant ]; then
        # Results are or will be out of date; run a new search
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
        sleep 0.5
    else
        grep -q 'Please wait' <<< $result
        if [ $? -eq 0 ]; then
            let "start -= 5"
            sleep 1.5
        fi
    fi
    let "remaining--"
done <<< "${assign_urls}"
if [ $perpage -gt ${max_perpage} ]; then
    let "perpage = $max_perpage"
fi
if [ $perpage -lt ${min_perpage} ]; then
    let "start += $min_perpage - $perpage"
    let "perpage = $min_perpage"
fi
if [ $start -lt 0 ]; then
    let "start = 0"
fi
if [ $start -gt 100000 ]; then
    let "start = 100000"
fi

 #
 #    | xargs wget -e robots=off -nv -w "$delay" -O /tmp/lastscrape || true
done
