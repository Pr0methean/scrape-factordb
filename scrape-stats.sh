#!/bin/bash
set -u
get_row () {
  pup -p "body table:nth-child($2) tr:nth-child($3) td:nth-child(2)" <<< "$1" \
    | sed 's_<td[^>]*>__' \
    | sed 's_</td>__' \
    | tr -d '\n' \
    | tr -d ',' \
    | tr -d ' '
}

try_assign_prp () {
  if [ ! -f "/tmp/factordb-scraped-unknowns/$1" ]; then
    assign_least_u="https://factordb.com/index.php?id=$1&prp=Assign+to+worker"
    echo $1
    result=$(sem --id 'factordb-curl' -j 4 wget -e robots=off --no-check-certificate -nv -O- -o/dev/null "${assign_least_u}" | grep '\(>C<\|>PRP<\|>P<\|>CF<\|>FF<\|Assigned\|already\|Please wait\)')
    grep -q "Assigned" "${result}"
    if [ "$?" ]; then
      touch "/tmp/factordb-scraped-unknowns/$1"
      return 0
    else
      return 1
    fi
  fi
}

mkdir -p "/tmp/factordb-scraped-unknowns"

while true; do
  (
    results=$(sem --id 'factordb-curl' -j 4 wget -e robots=off -nv --no-check-certificate -O- -o /dev/null 'https://factordb.com/status.php')
    time=$(date -u --iso-8601=seconds)
    p=$(get_row "${results}" 4 2)
    prp=$(get_row "${results}" 4 3)
    cf=$(get_row "${results}" 4 4)
    c=$(get_row "${results}" 4 5)
    u=$(get_row "${results}" 4 6)
    smallest_prp_cell=$(get_row "${results}" 6 2)
    # echo ${smallest_prp_cell}
    smallest_prp=$(sed 's_digits.*__' <<< "${smallest_prp_cell}")
    # echo "Smallest PRP size is ${smallest_prp}"
    smallest_c_cell=$(get_row "${results}" 6 3)
    smallest_c=$(sed 's_digits.*__' <<< "${smallest_c_cell}")
    load=$(get_row "${results}" 20 2)
    if [ "${u}" != "" ]; then
      echo "\"${time}\",${p},${prp},${cf},${c},${u},${smallest_prp},${smallest_c},${load}" | tee -a stats.csv
      least_u_row=$(get_row "${results}" 6 4)
      let "start_prp = 0"
      if [ "${least_u_row}" != "" ]; then
        least_u_id=$(grep -o 'index\.php?id=[0-9]\+' <<< "${least_u_row}" \
          | grep -o '[0-9]\+')
        if [ "$(try_assign_prp ${least_u_id} )" ]; then
          echo "Assigned PRP check: ${least_u_id}"
          let "start_prp = -1"
        else
          echo "Smallest-unknown id ${least_u_id} is already scraped"
          let "start_prp = 1"
        fi
      else
        echo "No smallest unknown-status number found!"
      fi
      if [ "${start_prp}" -ge 0 ]; then
          all_results=$(sem --fg --id 'factordb-curl' -j 4 wget -e robots=off --no-check-certificate --retry-connrefused \
              --retry-on-http-error=502 -T 30 -t 3 -q -O- -o/dev/null -- "https://factordb.com/listtype.php?t=2\&mindig=2001\&start=${start_prp}\&perpage=3" \
            | grep '#BB0000' \
            | grep -o 'index.php?id=[0-9]\+' \
            | uniq \
            | tac \
            | sed 's_.\+_https://factordb.com/&\&prp=Assign+to+worker_' \
            | sem --fg --id 'factordb-curl' -j 4 xargs -n 3 wget -e robots=off --no-check-certificate -q -T 30 -t 3 \
               --retry-connrefused --retry-on-http-error=502 -O- -o/dev/null -- \
            | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
          echo "${all_results}"
      fi
    fi
  ) &
  next_row_proc=$!
  sleep 59.5
  wait $next_row_proc
done
