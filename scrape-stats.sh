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
    result=$(sem --id 'factordb-curl' -j 2 wget -e robots=off --no-check-certificate -nv -O- -o/dev/null "${assign_least_u}" | grep '\(>C<\|>PRP<\|>P<\|>CF<\|>FF<\|Assigned\|already\|Please wait\)')
    grep -q "Assigned" <<< "${result}"
    if [ $? -eq 0 ]; then
      touch "/tmp/factordb-scraped-unknowns/$1"
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

mkdir -p "/tmp/factordb-scraped-unknowns"

while true; do
  (
    results=$(sem --id 'factordb-curl' -j 2 wget -e robots=off -nv --no-check-certificate -O- -o /dev/null 'https://factordb.com/status.php')
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
      if [ "${least_u_row}" != "" ]; then
        least_u_id=$(grep -o 'index\.php?id=[0-9]\+' <<< "${least_u_row}" \
          | grep -o '[0-9]\+')
        try_assign_prp ${least_u_id}
        if [ $? -eq 0 ]; then
          echo "Assigned PRP check: ${least_u_id}"
        else
          echo "Smallest-unknown id ${least_u_id} is already scraped"
        fi
      else
        echo "No smallest unknown-status number found!"
      fi
    fi
  ) &
  next_row_proc=$!
  sleep 59.5
  wait $next_row_proc
done
