#!/bin/bash
set -u
job=4294967251

# Start at a random point in the cycle of 21*25, and avoid modulo bias
while [ $job -ge 4294967250 ]; do
#   myrandom=$(openssl rand 3 | od -DAn)
#   job=$(($myrandom / 160))
  job=$(openssl rand 4 | od -DAn)
done

while : ; do
  let "start = ((job * 8) % 21) * 5000" # start must be in range 0 to 100,000
  let "digits = ((job * 11) % 25) + 101" # 101-123 digits; too big or on the borderline of what we can factor ourselves
  if [ $digits -gt 123 ]; then
    let "start = 0"
    let "digits = 1"
  fi
  url="https://factordb.com/listtype.php?t=3&mindig=${digits}&perpage=5000&start=${start}"
  sem --id 'factordb-curl' --fg -j 4 wget --user-agent "\"Mozilla/5.0 (X11; Linux x86_64; rv:139.0) Gecko/20100101 Firefox/139.0\"" -t 10 --retry-connrefused --retry-on-http-error=502 -e robots=off --no-check-certificate -O- "$url"
  echo "$(date -Is): Requested ${digits}-digit composites starting at ${start}."
  sleep 58
  let "job++"
done
