#!/bin/bash
set -u
job=1050000

# Start at a random point in the cycle of 21*37, and avoid modulo bias
while [ $job -ge 65268 ]; do
#   myrandom=$(openssl rand 3 | od -DAn)
#   job=$(($myrandom / 160))
  job=$(openssl rand 2 | od -DAn)
done

while : ; do
  let "start = ((job * 8) % 21) * 5000" # start must be in range 0 to 100,000
  let "digits = ((job * 17) % 37) + 93" # 93-127 digits; too big or on the borderline of what we can factor ourselves
  if [ $digits -gt 127 ]; then
    let "start = 0"
    let "digits = 1"
  fi
  url="https://factordb.com/listtype.php?t=3&mindig=${digits}&perpage=5000&start=${start}&download=1"
  sem --id 'factordb-curl' --fg -j 4 wget -e robots=off -nv --no-check-certificate -O- "$url"
  echo "$(date -Is): Requested ${digits}-digit composites starting at ${start}."
  sleep 178
  let "job++"
done
