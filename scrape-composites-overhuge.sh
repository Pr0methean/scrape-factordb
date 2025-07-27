#!/bin/bash
set -u
job=4294967251

# Start at a random point in the cycle of 210*25, and avoid modulo bias
while [ $job -ge 4294967250 ]; do
#   myrandom=$(openssl rand 3 | od -DAn)
#   job=$(($myrandom / 160))
  job=$(openssl rand 4 | od -DAn)
done

while : ; do
  let "perpage = 500"
  let "start = ((job * 23) % 210) * 500" 
  let "digits = ((job * 11) % 25) + 101" # 101-123 digits; too big or on the borderline of what we can factor ourselves
  if [ $digits -gt 123 ]; then
    let "start = 0"
    let "digits = 1"
    let "perpage = 5000" # stimulating factoring seems to be more effective for smaller numbers
  elif [ ${start} -ge 100000 ]; then
    # start must be in range 0 to 100,000; but fetch 5000 numbers since that's the only way to get more than the first 100,500
    let "start = 100000"
    let "perpage = 5000"
  fi
  url="https://factordb.com/listtype.php?t=3&mindig=${digits}&perpage=${perpage}&start=${start}"
  sem --id 'factordb-curl' --fg -j 3 wget --user-agent "\"Mozilla/5.0 (X11; Linux x86_64; rv:139.0) Gecko/20100101 Firefox/139.0\"" -t 10 --retry-connrefused --retry-on-http-error=502 -e robots=off --no-check-certificate -O- "$url"
  echo "$(date -Is): Requested ${perpage} ${digits}-digit composites starting at ${start}."
  # sleep 58
  let "job++"
done
