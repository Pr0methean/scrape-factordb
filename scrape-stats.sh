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
    fi
  ) &
  next_row_proc=$!
  sleep 119.5
  wait $next_row_proc
done
