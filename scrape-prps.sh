#!/bin/bash
set -u
let "min_start = 0"
let "start = ${min_start}"
let "next_start_time = 0"
urlstart='https://factordb.com/listtype.php?t=1&mindig='
let "min_ids_per_restart = 30"
let "old_ids_checked_since_restart = 0"
let "ids_with_prp_checks_since_restart = 0"
let "children = 0"
while true; do
url="${urlstart}${digits}&perpage=${perpage}\&start=${start}"
echo "Running search: ${url}"
results=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -T 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
for id in $(grep -o 'index.php?id=[0-9]\+' <<< "$results" \
  | uniq); do
  echo "Checking ID ${id}"
  status=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -T 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "https://factordb.com/${id}\&open=prime\&ct=Proof")
  bases_checked_html=$(grep -A1 'Bases checked' <<< "$status")
  bases_checked_lines=$(grep -o '[0-9]\+' <<< "$bases_checked_html")
  declare -a bases_left
  readarray -t bases_left < <(echo {2..255} "${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
  echo "${id}: Bases left to check: ${bases_left[@]}"
  if [ ${#bases_left[@]} -eq 0 ]; then
    echo "ID ${id} already has all bases checked"
    exit 0
  fi
  actual_digits=$(grep -o '&lt;[0-9]\+&gt;' <<< "$status" | head -n 1 | grep -o '[0-9]\+')
  echo "PRP with ID ${id} is ${actual_digits} digits; will wait ${delay} s between requests."

  # Large PRPs can exhaust our CPU limit, so throttle if we've just tested one
  # Miller-Rabin test is O(log^3 n) = O($actual_digits ^ 3)
  let "cpu_cost = $actual_digits * $actual_digits * $actual_digits * ${#bases_left[@]}"
  let "now = $(date '+%s')"
  let "delay = $next_start_time - $now"
  if [ $delay -gt 0 ]; then
    echo "Throttling for $delay seconds"
    sleep $delay
  fi
  let "next_start_time = $now + ($cpu_cost / 1000000000)"

  let "stopped_early = 0"
  for base in "${bases_left[@]}"; do
    url="https://factordb.com/${id}\&open=prime\&basetocheck=${base}"
    output=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O- -t 10 -T 10 --retry-connrefused --retry-on-http-error=502 <<< "$url")
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
        if [ $delay -gt 0 -a $stopped_early -eq 0 ]; then
          sleep $delay
        fi
      fi
    fi
  done
  if [ $stopped_early -eq 0 ]; then
    echo "${id}: All bases checked"
  fi
done

# Restart once we have found enough PRP checks that weren't already done
let "ids_with_prp_checks_since_restart += 1"
if [ ${ids_with_prp_checks_since_restart} -ne ${old_ids_checked_since_restart} ]; then
  let "old_ids_checked_since_restart = ${ids_with_prp_checks_since_restart}"
  let "ids_checked_since_restart = ${start} + ${perpage} - ${min_start}"
  let "restart = 0"
  if [ ${ids_with_prp_checks_since_restart} -ge ${min_ids_per_restart} ]; then
    echo "${ids_with_prp_checks_since_restart} IDs checked in ${ids_checked_since_restart} tries; restarting due to sufficient number"
    let "restart = 1"
  elif [ $start -ge 100000 ]; then
    echo "${ids_with_prp_checks_since_restart} IDs checked in ${ids_checked_since_restart} tries; restarting since we reached max start of 100000"
    let "restart = 1"
  fi
  if [ $restart -ne 0 ]; then
    let "ids_with_prp_checks_since_restart = 0"
    let "ids_checked_since_restart = 0"
    let "start = ${min_start}"
    let "old_ids_checked_since_restart = 0"
    rm /tmp/prp/*
    continue
  else
    echo "${ids_with_prp_checks_since_restart} IDs checked in ${ids_checked_since_restart} tries; advancing"
  fi
fi
let "start += ${perpage}"
done
