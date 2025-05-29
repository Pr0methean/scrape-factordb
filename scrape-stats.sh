#!/bin/bash
set -u
get_row () {
  pup -p "body table:nth-child($2) tr:nth-child($3) td:nth-child(2)" <<< "$1" \
    | sed 's_<td[^>]*>__' \
    | sed 's_</td>__' \
    | tr -d '\n' \
    | tr -d ','
}

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
        # echo ${least_u_row}
        assign_least_u=$(grep -o 'index\.php?id=[0-9]\+' <<< "${least_u_row}" \
          | sed 's_.*index.php_https://factordb.com/index.php_' \
          | sed 's_$_\&prp=Assign+to+worker_')
        echo ${assign_least_u}
        result=$(sem --id 'factordb-curl' --ungroup -j 4 xargs wget -e robots=off --no-check-certificate -nv -O- <<< "${assign_least_u}" | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
        echo $result
      fi
    fi
  ) &
  next_row_proc=$!
  sleep 59.5
  wait $next_row_proc
done
