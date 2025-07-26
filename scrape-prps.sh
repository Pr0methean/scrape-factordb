#!/bin/bash
check_bases() {
  let "stopped_early = 0"
  let "bases_actually_checked = 0"
  for base in "${bases_left[@]}"; do
    let "bases_actually_checked += 1"
    url="https://factordb.com/${id}\&open=prime\&basetocheck=${base}"
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
  elif [ "$@" -eq "" ]; then
    let "skipped_bases = ${#bases_left[@]} - $bases_actually_checked"
    let "cpu_savings = ($actual_digits * $actual_digits * $actual_digits + 2500000000) * ${skipped_bases} / 50"
    echo "Crediting $(./format-nanos.sh $cpu_savings) back to CPU budget for skipped bases."
    let "cpu_budget += $cpu_savings"
    if [ "$cpu_budget" -gt "$cpu_budget_max" ]; then
      let "cpu_budget = $cpu_budget_max"
    fi
  fi
}

set -u
let "min_start = 0"
let "throttled_restart_threshold_per_sec_delay = 10"
urlstart='https://factordb.com/listtype.php?t=1&mindig='
let "min_checks_per_restart = 30 * 254"
let "checks_since_restart = 0"
let "next_start_time = 0"
let "next_cpu_budget_reset = 0"
let "cpu_budget_max = 8 * 60 * 1000 * 1000 * 1000"
let "cpu_budget_reset_period_secs = 60 * 60"
let "cpu_budget = 0"
while true; do
url="${urlstart}${digits}&perpage=${perpage}\&start=${start}"
echo "Running search: ${url}"
results=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -T 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
for id in $(grep -o 'index.php?id=[0-9]\+' <<< "$results" \
  | uniq); do
  let "restart = 0"
  echo "Checking ID ${id}"
  status=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -T 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "https://factordb.com/${id}\&open=prime\&ct=Proof")
  bases_checked_html=$(grep -A1 'Bases checked' <<< "$status")
  bases_checked_lines=$(grep -o '[0-9]\+' <<< "$bases_checked_html")
  declare -a bases_left
  readarray -t bases_left < <(echo {2..255} "${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
  if [ ${#bases_left[@]} -eq 0 ]; then
    echo "ID ${id} already has all bases checked"
    continue
  fi
  echo "${id}: ${#bases_left[@]} bases left to check: ${bases_left[@]}"
  actual_digits=$(grep -o '&lt;[0-9]\+&gt;' <<< "$status" | head -n 1 | grep -o '[0-9]\+')
  echo "${id}: This PRP is ${actual_digits} digits."
  # Large PRPs can exhaust our CPU limit, so throttle if we're close to it
  let "now = $(date '+%s')"
  let "cpu_cost = ($actual_digits * $actual_digits * $actual_digits + 2500000000) * ${#bases_left[@]} / 50"
  echo "Estimated server CPU time for ${id} is $(./format-nanos.sh $cpu_cost)."
  if [ $now -lt $next_cpu_budget_reset ]; then
    let "cpu_budget = $cpu_budget - $cpu_cost"
    if [ $cpu_budget -lt 0 ]; then
      let "delay = $next_cpu_budget_reset - $now"
      echo "Throttling for $delay seconds, because our budget is $(./format-nanos.sh $((-$cpu_budget))) short. Press SPACE to skip."
      if read -t $delay -n 1; then
        echo "$(date -Is): Throttling skipped."
        let "delay = $(($(date '+%s') - $now"
      else
        echo "$(date -Is): Throttling delay finished."
      fi
      if [ $delay -ge $(($start * $throttled_restart_threshold_per_sec_delay)) ]; then
        echo "Restarting due to low position of $start relative to delay of $delay seconds."
        let "restart = 1"
      fi
      let "cpu_budget = $cpu_budget_max - $cpu_cost"
    fi
  else
    echo "$(date -Is): CPU budget has been refreshed."
    let "next_cpu_budget_reset = $now + $cpu_budget_reset_period_secs"
    let "cpu_budget = $cpu_budget_max - $cpu_cost"
  fi
  echo "Remaining CPU budget is $(./format-nanos.sh $cpu_budget)."
  if [ $actual_digits -ge 700 -o $cpu_budget -le 0 ]; then
    check_bases
  else
    # Small PRPs can be launched as fire-and-forget subprocesses
    (check_bases "in_subprocess") &
  fi
  let "checks_since_restart += ${#bases_left[@]}"

done

if [ $restart -eq 0 ]; then
  # Restart once we have found enough PRP checks that weren't already done
  if [ ${checks_since_restart} -ge ${min_checks_per_restart} ]; then
    echo "${checks_since_restart} PRP checks launched; restarting due to sufficient number"
    let "restart = 1"
  elif [ $start -ge 100000 ]; then
    echo "${checks_since_restart} PRP checks launched; restarting since we reached max start of 100000"
    let "restart = 1"
  fi
fi
  if [ $restart -ne 0 ]; then
    let "checks_since_restart = 0"
    let "start = ${min_start}"
    continue
  else
    let "start += ${perpage}"
    echo "${checks_since_restart} PRP checks launched after checking ${start} IDs; advancing"
  fi
done
