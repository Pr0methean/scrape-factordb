#!/bin/bash
set -u
urlstart="https://factordb.com/listtype.php?t=2\&mindig="
let "entries = 0"
while IFS=, read -r id expr; do
url="https://factordb.com/?id=${id}\&prp=Assign+to+worker"
while true; do
  result=$(sem --fg --id 'factordb-curl' -j 2 xargs -n 3 wget -e robots=off --no-check-certificate -q -T 30 -t 3 --retry-connrefused --retry-on-http-error=502 -O- -o/dev/null -- <<< "${url}" \
    | grep '\(ssign\|queue\|>C<\|>P<\|>PRP<\)')
  echo $result
  if [ -z "$result" ]; then
    echo "Got no response for $id"
    sleep 30
  else
    grep -q 'Please wait' <<< $result
    if [ $? -eq 0 ]; then
      echo "Got 'Please wait' for $id"
      sleep 10
    else
      break
    fi
  fi
done
let "entries += 1"
echo "Processed ${entries} entries in U_all.csv"
done < U_all.csv
done
