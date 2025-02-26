#!/bin/bash
set -u
get_row () {
  pup -p "body table:nth-child(4) tr:nth-child($2) td:nth-child(2)" <<< "$1" \
    | sed 's_<td[^>]*>__' \
    | sed 's_</td>__' \
    | tr -d '\n' \
    | tr -d ','
}

while true; do
  (
    results=$(sem --id 'factordb-curl' -j 4 wget -e robots=off -nv --no-check-certificate -O- -o /dev/null 'https://factordb.com/status.php')
    time=$(date -u --iso-8601=seconds)
    p=$(get_row "${results}" 2)
    prp=$(get_row "${results}" 3)
    cf=$(get_row "${results}" 4)
    c=$(get_row "${results}" 5)
    u=$(get_row "${results}" 6)
    if [ "${u}" != "" ]; then
      echo "\"${time}\",${p},${prp},${cf},${c},${u}" | tee -a stats.csv
    fi
  ) &
  next_row_proc=$!
  sleep 59.5
  wait $next_row_proc
done
