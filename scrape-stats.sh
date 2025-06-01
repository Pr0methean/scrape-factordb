#!/bin/bash
set -u
get_row () {
  pup -p "body table:nth-child($2) tr:nth-child($3) td:nth-child(2)" <<< "$1" \
    | sed 's_<td[^>]*>__' \
    | sed 's_</td>__' \
    | tr -d '\n' \
    | tr -d ','
}

try_assign_prp () {
  if [ ! -f "/tmp/factordb-scraped-unknowns/$1" ]; then
    assign_least_u="https://factordb.com/index.php?id=$1&prp=Assign+to+worker"
    echo $1
    result=$(sem --id 'factordb-curl' --ungroup -j 4 xargs wget -e robots=off --no-check-certificate -nv -O- <<< "${assign_least_u}" | grep '\(>C<\|>PRP<\|>P<\|>CF<\|>FF<\|Assigned\|already\)')
    if [ "${result}" != "" ]; then
      touch "/tmp/factordb-scraped-unknowns/$1"
      return 0
    else
      return 1
    fi
    echo "$1: $result"
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
    if [ "${u}" != "" ]; then
      echo "\"${time}\",${p},${prp},${cf},${c},${u}" | tee -a stats.csv
      least_u_row=$(get_row "${results}" 6 4)
      if [ "${least_u_row}" != "" ]; then
        least_u_id=$(grep -o 'index\.php?id=[0-9]\+' <<< "${least_u_row}" \
          | grep -o '[0-9]\+')
        if [ ! "$(try_assign_prp ${least_u_id} )" ]; then
          echo "Smallest-unknown id ${least_u_id} is already scraped"
          assign_ids=$(sem --id 'factordb-curl' --ungroup --fg -j 4 wget -e robots=off --no-check-certificate -nv -O- -o /dev/null "https://factordb.com/listtype.php?t=2\&mindig=3000\&start=1\&perpage=3" \
            | pup 'a[href*="index.php?id"] attr{href}' \
            | uniq \
            | tac \
            | sed 's_.*id=__')
          while read -r assign_id; do
            try_assign_prp ${assign_id}
          done <<< "${assign_ids}"
        fi
      fi
    fi
  ) &
  next_row_proc=$!
  sleep 59.5
  wait $next_row_proc
done
