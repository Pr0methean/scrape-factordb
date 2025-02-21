#!/bin/bash
set -u

urlstart='https://factordb.com/listtype.php?t=1\&mindig='
if [ ${start} == -1 ]; then
  start="$(($RANDOM * 3))"
fi
while true; do
url="${urlstart}${digits}\&perpage=${perpage}\&start=${start}"
results=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O- <<< "$url")
for id in $(pup 'a[href*="index.php?id"] attr{href}' <<< "$results" \
  | uniq \
  | sed 's_.*index.php_https://factordb.com/index.php_' \
); do
  echo "Checking ID ${id}"
  status=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off -t 10 -nv <<< "${id}\&open=prime\&ct=Proof")
  bases_checked_html=$(grep -A1 'Bases checked' <<< "$status")
  echo "$bases_checked_html"
  bases_checked_lines=$(grep -o '[0-9]\+' <<< "$bases_checked_html")
  # echo "Bases already checked: ${bases_checked_lines}"
  bases=({2..255})
  declare -a bases_left
  readarray -t bases_left < <(echo "${bases[@]} ${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
  urls=()
  for base in "${bases_left[@]}"; do
    urls+=("${id}\&open=prime\&basetocheck=${base}")
  done
  for url in "${urls[@]}"; do
    if sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O /tmp/lastscrape-prp.html <<< "$url"; then
      if grep -q 'set to C' /tmp/lastscrape-prp.html; then
        echo "Check ruled out PRP"
        break
      elif grep -q 'Verified' /tmp/lastscrape-prp.html; then
        echo "No longer PRP"
        break
      elif ! grep -q 'PRP' /tmp/lastscrape-prp.html; then
        echo "No longer PRP"
        break
      fi
    fi
   done
done
start=$((($start + $perpage) % (100000 + $perpage)))
done

