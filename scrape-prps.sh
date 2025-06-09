#!/bin/bash
set -u

urlstart='https://factordb.com/listtype.php?t=1\&mindig='
let "bases_left_since_restart = 0"
while true; do
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
echo "Running search: ${url}"
results=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- <<< "$url")
let "bases_left_on_page = -1" # Don't increase start if search fails
for id in $(pup 'a[href*="index.php?id"] attr{href}' <<< "$results" \
  | uniq \
  | sed 's_.*index.php_https://factordb.com/index.php_' \
); do
  if [ ${bases_left_on_page} -eq -1 ]; then
    let "bases_left_on_page = 0"
  fi
  echo "Checking ID ${id}"
  status=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- <<< "${id}\&open=prime\&ct=Proof")
  bases_checked_html=$(grep -A1 'Bases checked' <<< "$status")
  echo "$bases_checked_html"
  bases_checked_lines=$(grep -o '[0-9]\+' <<< "$bases_checked_html")
  # echo "Bases already checked: ${bases_checked_lines}"
  bases=({2..255})
  declare -a bases_left
  readarray -t bases_left < <(echo "${bases[@]} ${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
  let "bases_left_on_page += ${#bases_left[@]}"
  urls=()
  for base in "${bases_left[@]}"; do
    urls+=("${id}\&open=prime\&basetocheck=${base}")
  done
  for url in "${urls[@]}"; do
    output=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O- <<< "$url")
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
      fi
    fi
   done
done
# Restart once we find and attempt 3 * 254 PRP checks that aren't already done
if [ ${bases_left_since_restart} -ge 762 ]; then
  start=0
  let "bases_left_since_restart = 0"
else
  start=$((($start + $perpage) % (100000 + $perpage)))
fi
done

