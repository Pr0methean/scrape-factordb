#!/bin/bash
set -u
let "start = 0"
urlstart='https://factordb.com/listtype.php?t=1\&mindig='
let "bases_left_since_restart = 0"
let "bases_per_restart = 254 * $perpage * 2"
while true; do
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
echo "Running search: ${url}"
results=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
let "bases_left_on_page = -1" # Don't increase start if search fails
for id in $(pup 'a[href*="index.php?id"] attr{href}' <<< "$results" \
  | uniq \
  | sed 's_.*index.php_https://factordb.com/index.php_' \
); do
  if [ ${bases_left_on_page} -eq -1 ]; then
    let "bases_left_on_page = 0"
  fi
  echo "Checking ID ${id}"
  status=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "${id}\&open=prime\&ct=Proof")
  digits=$(grep -o '&lt;[0-9]\+&gt;' <<< "$status" | head -n 1 | grep -o '[0-9]\+')
  let "delay = ($digits * $digits) / (800 * 800)"
  echo "PRP with ID ${id} is ${digits} digits; will wait ${delay} s between requests."
  bases_checked_html=$(grep -A1 'Bases checked' <<< "$status")
  echo "$bases_checked_html"
  bases_checked_lines=$(grep -o '[0-9]\+' <<< "$bases_checked_html")
  # echo "Bases already checked: ${bases_checked_lines}"
  bases=({2..255})
  declare -a bases_left
  readarray -t bases_left < <(echo "${bases[@]} ${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
  let "bases_left_on_page = ${#bases_left[@]}"
  let "bases_left_since_restart += ${#bases_left[@]}"
  urls=()
  for base in "${bases_left[@]}"; do
    urls+=("${id}\&open=prime\&basetocheck=${base}")
  done
  for url in "${urls[@]}"; do
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
      else
        sleep ${delay}
      fi
    fi
   done
done
# Restart once we have found enough PRP checks that weren't already done
if [ ${bases_left_since_restart} -ge ${bases_per_restart} -o ${bases_left_on_page} -eq -1 ]; then
  let "start = 0"
  let "bases_left_since_restart = 0"
else
  let "start += ${perpage}"
fi
done

