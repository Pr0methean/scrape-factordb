#!/bin/bash
set -u
while : ; do
  url="https://factordb.com/listtype.php?t=3&mindig=1&perpage=5000&start=0"
  sem --id 'factordb-curl' --fg -j 4 wget --user-agent "\"Mozilla/5.0 (X11; Linux x86_64; rv:139.0) Gecko/20100101 Firefox/139.0\"" -t 10 --retry-connrefused --retry-on-http-error=502 -e robots=off --no-check-certificate -O- "$url"
  echo "$(date -Is): Requested tiny composites."
  sleep 598
done
