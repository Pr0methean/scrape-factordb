#!/bin/bash
while IFS=, read -r id value; do
  echo -n "${id} (${value}): "
  curl -S --retry 10 --retry-all-errors "https://factordb.com/sequences.php?check=${id}" \
    | grep "${id}" \
    | grep -o '<input type="submit"[^>]*>'
done < <(shuf < "${source}")
