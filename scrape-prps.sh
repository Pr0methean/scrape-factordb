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

IFS=':'
let "min_start = 0"
let "start = ${min_start}"
urlstart='https://factordb.com/listtype.php?t=1&mindig='
let "min_checks_per_restart = 30 * 255"
let "checks_since_restart = 0"
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
    continue
  fi
  actual_digits=$(grep -o '&lt;[0-9]\+&gt;' <<< "$status" | head -n 1 | grep -o '[0-9]\+')
  echo "${id}: This PRP is ${actual_digits} digits."
  if [ $actual_digits -gt 1000 ]; then
  # Large PRPs can exhaust our CPU limit, so throttle if we're close to it
    let "cpu_cost = ($actual_digits * $actual_digits * $actual_digits / 80 + 10000000) * ${#bases_left[@]}"
    echo "Estimated server CPU time for ${id} is $(./format-nanos.sh $cpu_cost)."
    limits=$(sem --id 'factordb-curl' -j 4 --fg wget -e robots=off --no-check-certificate -t 10 -T 10 -nv -O- --retry-connrefused --retry-on-http-error=502 -o/dev/null "https://factordb.com/res.php"_)
    cpu_time_tenths=$(get_row "${limits}" 2 6 | grep -o '[0-9\.]\+' | sed 's/\.//')
    echo "CPU time already spent is ${cpu_time_tenths} tenths of a second."
    let "spare_cpu_time = (6000 - $cpu_time_tenths) - ($cpu_cost / 100000000 )"
    if [ $spare_cpu_time -le 0 ]; then
      wait_time=$(get_row "${limits}" 2 7 | grep -o '[0-9:]\+')
      read -ra min_sec <<< "$wait_time"
      let "wait_sec = ${min_sec[0]} * 60 + ${min_sec[1]}"
      echo "Waiting ${wait_sec} seconds for CPU-time allocation to refresh"
      sleep $wait_sec
    fi
  fi

  let "stopped_early = 0"
  for base in "${bases_left[@]}"; do
    url="https://factordb.com/${id}\&open=prime\&basetocheck=${base}"
    let "checks_since_restart += 1"
    output=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O- -t 10 -T 10 --retry-connrefused --retry-on-http-error=502 <<< "$url")
    if [ $? -eq 0 ]; then
      if grep -q 'set to C' <<< "$output"; then
        echo "${id}: No longer PRP (ruled out by PRP check)"
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
      fi
    fi
  done
  if [ $stopped_early -eq 0 ]; then
    echo "${id}: All bases checked"
  fi
done

# Restart once we have found enough PRP checks that weren't already done
let "restart = 0"
if [ ${checks_since_restart} -ge ${min_checks_per_restart} ]; then
  echo "${checks_since_restart} PRP checks done; restarting due to sufficient number"
  let "restart = 1"
elif [ $start -ge 100000 ]; then
  echo "${checks_since_restart} PRP checks done; restarting since we reached max start of 100000"
  let "restart = 1"
fi
  if [ $restart -ne 0 ]; then
    let "checks_since_restart = 0"
    let "start = ${min_start}"
    continue
  else
    let "start += ${perpage}"
    echo "${checks_since_restart} PRP checks done after checking ${start} IDs; advancing"
  fi
done
