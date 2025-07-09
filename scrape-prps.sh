#!/bin/bash
set -u
mkdir "/tmp/prp"
mkdir "/tmp/prp-lock"
rm /tmp/prp/*
let "start = 0"
urlstart='https://factordb.com/listtype.php?t=1&mindig='
let "bases_checked_before_page = 0"
let "bases_per_restart = 254 * $perpage * 5"
let "children = 0"
while true; do
url="${urlstart}${digits}&perpage=${perpage}\&start=${start}"
echo "Running search: ${url}"
results=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
for id in $(grep -o 'index.php?id=[0-9]\+' <<< "$results" \
  | uniq); do
  (
  exec 9>/tmp/prp-lock/${id}
  flock -xn 9
  if [ ! $? ]; then
    echo "ID ${id} already locked by another process"
    exit 0
  fi
  echo "Checking ID ${id}"
  status=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "https://factordb.com/${id}\&open=prime\&ct=Proof")
#  actual_digits=$(grep -o '&lt;[0-9]\+&gt;' <<< "$status" | head -n 1 | grep -o '[0-9]\+')
#  let "delay = ($actual_digits * $actual_digits) / 1000000"
#  echo "PRP with ID ${id} is ${actual_digits} digits; will wait ${delay} s between requests."
  bases_checked_html=$(grep -A1 'Bases checked' <<< "$status")
  bases_checked_lines=$(grep -o '[0-9]\+' <<< "$bases_checked_html")
  bases=({2..255})
  declare -a bases_left
  readarray -t bases_left < <(echo "${bases[@]} ${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
  echo "${id}: Bases left to check: ${bases_left[@]}"
  for base in "${bases_left[@]}"; do
    touch /tmp/prp/id_${id}_base_${base}
    url="https://factordb.com/${id}\&open=prime\&basetocheck=${base}"
    output=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
    if [ $? -eq 0 ]; then
      if grep -q 'set to C' <<< "$output"; then
        echo "${id}: Check ruled out PRP"
        break
      elif grep -q 'Verified' <<< "$output"; then
        echo "${id}: No longer PRP"
        break
      elif ! grep -q 'PRP' <<< "$output"; then
        echo "${id}: No longer PRP"
        break
#      else
#        sleep ${delay}
      fi
    fi
  done
  ) &
  let "children += 1"
done
while [ $children -ge $perpage ]; do
  wait -n
  let "children -= 1"
  echo "${children} PRPs still being checked"
done

# Restart once we have found enough PRP checks that weren't already done
let "bases_checked_since_restart = $(find '/tmp/prp' -type f -printf '.' | wc -m)"
if [ $start -gt 0 -a ${bases_checked_since_restart} -gt ${bases_per_restart} ]; then
  echo "${bases_checked_since_restart} bases checked; restarting"
  let "bases_checked_since_restart = 0"
  let "start = 0"
  rm /tmp/prp/*
else
  let "start += ${perpage}"
fi
let "bases_checked_before_page = ${bases_checked_since_restart}"
done

