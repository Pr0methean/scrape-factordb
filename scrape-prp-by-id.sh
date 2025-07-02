#!/bin/bash
set -u
echo "$1: Checking status"
status=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -t 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "https://factordb.com/$1\&open=prime\&ct=Proof")
bases_checked_html=$(grep -A1 'Bases checked' <<< "$status")
echo "$bases_checked_html"
bases_checked_lines=$(grep -o '[0-9]\+' <<< "$bases_checked_html")
bases=({2..255})
declare -a bases_left
readarray -t bases_left < <(echo "${bases[@]} ${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
  for base in "${bases_left[@]}"; do
    url="https://factordb.com/$1\&open=prime\&basetocheck=${base}"
    output=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O- --retry-connrefused --retry-on-http-error=502 <<< "$url")
    if [ $? -eq 0 ]; then
      if grep -q 'set to C' <<< "$output"; then
        echo "$1: Check ruled out PRP"
        break
      elif grep -q 'Verified' <<< "$output"; then
        echo "$1: No longer PRP"
        break
      elif ! grep -q 'PRP' <<< "$output"; then
        echo "$1: No longer PRP"
        break
#      else
#        sleep ${delay}
      fi
    fi
    touch /tmp/prp_base_checked
  done
echo "$1: Done"
