#!/bin/bash
set -u
mkdir "/tmp/prp"
mkdir "/tmp/prp-lock"
rm /tmp/prp/*
let "min_start = 0"
let "start = ${min_start}"
urlstart='https://factordb.com/listtype.php?t=1&mindig='
let "min_ids_per_restart = $perpage + 3"
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
  declare -a bases_left
  readarray -t bases_left < <(echo {2..255} "${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
  echo "${id}: Bases left to check: ${bases_left[@]}"
  let "stopped_early = 0"
  for base in "${bases_left[@]}"; do
    url="https://factordb.com/${id}\&open=prime\&basetocheck=${base}"
    output=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
    if [ $? -eq 0 ]; then
      if grep -q 'set to C' <<< "$output"; then
        echo "${id}: No longer PRP (ruled out by PRP check)"
        touch /tmp/prp/${id}
        let "stopped_early = 1"
        break
      elif grep -q '\(Verified\|Processing\)' <<< "$output"; then
        echo "${id}: No longer PRP (certificate received)"
        let "stopped_early = 1"
        break
      elif ! grep -q 'PRP' <<< "$output"; then
        echo "${id}: No longer PRP (ruled out by factor or N-1/N+1 check)"
        let "stopped_early = 1"
        break
      else
        touch /tmp/prp/${id}
      fi
    fi
  done
  if [ $stopped_early -eq 0 ]; then
    echo "${id}: All bases checked"
  fi
  ) &
  let "children += 1"
done
while [ $children -ge $perpage ]; do
  wait -n
  let "children -= 1"
  echo "${children} PRPs still being checked"
done

# Restart once we have found enough PRP checks that weren't already done
let "ids_checked_since_restart = $(find '/tmp/prp' -type f -printf '.' | wc -m)"
if [ ${ids_checked_since_restart} -ge ${min_ids_per_restart} -a $((${ids_checked_since_restart} * 2)) -ge $((${start} - ${min_start})) ]; then
  echo "${ids_checked_since_restart} IDs checked; restarting"
  let "ids_checked_since_restart = 0"
  let "start = ${min_start}"
  rm /tmp/prp/*
else
  let "start += ${perpage}"
fi
done

