#!/bin/bash
while IFS=, read -r id value; do
  echo -n "${id} (${value}): "
  curl -Ss --retry 10 --retry-all-errors "https://factordb.com/sequences.php?check=${id}"
  if [ $? -eq 0 ]; then
    echo "Checked ID ${id} (${value})"
  else
    echo "ERROR: Got exit status $? checking ID ${id} (${value})"
  fi
done < <(shuf < "${source}")
