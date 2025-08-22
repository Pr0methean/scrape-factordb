#!/bin/bash
while IFS=, read -r id; do
  curl -Ss --retry 10 --retry-all-errors "https://factordb.com/sequences.php?check=${id}" >/dev/null
  if [ $? -eq 0 ]; then
    echo "Checked ID ${id}"
  else
    echo "ERROR: Got exit status $? checking ID ${id}"
  fi
done
