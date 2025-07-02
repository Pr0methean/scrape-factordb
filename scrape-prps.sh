#!/bin/bash
set -u
let "start = 0"
urlstart='https://factordb.com/listtype.php?t=1&mindig='
let "bases_left_since_restart = 0"
let "bases_per_restart = 254 * $perpage * 5"
while true; do
url="${urlstart}${digits}&perpage=${perpage}\&start=${start}"
echo "Running search: ${url}"
results=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
let "bases_left_on_page = -1" # Don't increase start if search fails
children=()
for id in $(grep -o 'index.php?id=[0-9]\+' <<< "$results" \
  | uniq); do
  (
  echo "Checking ID ${id}"
  status=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "https://factordb.com/${id}\&open=prime\&ct=Proof")
#  actual_digits=$(grep -o '&lt;[0-9]\+&gt;' <<< "$status" | head -n 1 | grep -o '[0-9]\+')
#  let "delay = ($actual_digits * $actual_digits) / 1000000"
#  echo "PRP with ID ${id} is ${actual_digits} digits; will wait ${delay} s between requests."
  bases_checked_html=$(grep -A1 'Bases checked' <<< "$status")
  echo "$bases_checked_html"
  bases_checked_lines=$(grep -o '[0-9]\+' <<< "$bases_checked_html")
  # echo "Bases already checked: ${bases_checked_lines}"
  bases=({2..255})
  declare -a bases_left
  readarray -t bases_left < <(echo "${bases[@]} ${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
  let "bases_left_on_page = ${#bases_left[@]}"
  let "bases_left_since_restart += ${#bases_left[@]}"
  for base in "${bases_left[@]}"; do
    touch /tmp/prp_base_checked
    url="https://factordb.com/${id}\&open=prime\&basetocheck=${base}"
    output=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
    if [ $? -eq 0 ]; then
      if grep -q 'set to C' <<< "$output"; then
        echo "Check ruled out PRP"
        break
      elif grep -q 'Verified' <<< "$output"; then
        echo "No longer PRP"
        break
      elif ! grep -q 'PRP' <<< "$output"; then
        echo "No longer PRP"
        break
#      else
#        sleep ${delay}
      fi
    fi
  done
  ) &
done
wait

# Restart once we have found enough PRP checks that weren't already done
if [ -e /tmp/prp_base_checked -a $start -gt 0 ]; then
  let "start = 0"
  let "bases_left_since_restart = 0"
  rm /tmp/prp_base_checked
else
  let "start += ${perpage}"
fi
done

