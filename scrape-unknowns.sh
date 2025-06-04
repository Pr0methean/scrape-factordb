#!/bin/bash
set -u
origstart=$start
let "min_perpage = 3"
let "max_perpage = 20"
let "goal_perpage = 3"
let "min_start = 0"
let "max_start = 100000" # Largest start that factordb allows
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
let "max_redundant = $goal_perpage"
if [ $max_redundant -lt 2 ]; then
  let "max_redundant = 2"
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
        let "start += 1"
        let "perpage -= 2"
        let "redundant++"
        sleep 1
    else
        grep -q 'already in queue' <<< $result
        if [ $? -eq 0 ]; then
            let "start += 1"
            let "perpage -= 1"
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
        if [ $perpage -lt $goal_perpage ]; then
          let "perpage += 1"
        elif [ $start -le $min_start ]; then
          let "perpage += 1"
        else
          let "start -= 1"
        fi
        sleep 0.5
    else
        grep -q 'Please wait' <<< $result
        if [ $? -eq 0 ]; then
            let "start -= $goal_perpage"
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
if [ $start -lt ${min_start} ]; then
    let "start = $min_start"
fi
if [ $start -gt ${max_start} ]; then
    let "start = $max_start"
fi

 #
 #    | xargs wget -e robots=off -nv -w "$delay" -O /tmp/lastscrape || true
done
