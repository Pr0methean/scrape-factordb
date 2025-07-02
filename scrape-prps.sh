#!/bin/bash
set -u
let "start = 0"
urlstart='https://factordb.com/listtype.php?t=1&mindig='
fifo_id="/tmp/$(uuidgen)"
mkfifo ${fifo_id}
while true; do
  parallel --pipe --fifo -j 4 ./scrape-prp-by-id.sh < ${fifo_id} &
  parallel_id=$!
  echo "started parallel job ${parallel_id}"
  while [ -e /proc/${parallel_id} -a ! -e /tmp/prp_base_checked ]; do
    url="${urlstart}${digits}&perpage=${perpage}\&start=${start}"
    echo "Running search: ${url}"
    results=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
    grep -o 'index.php?id=[0-9]\+' <<< "$results" | uniq | tee -a ${fifo_id}
    let "start += 3"
  done
  rm /tmp/prp_base_checked
  kill -HUP ${parallel_id}
  echo "Waiting to join parallel job"
  wait ${parallel_id}
  let "start = 0"
done
