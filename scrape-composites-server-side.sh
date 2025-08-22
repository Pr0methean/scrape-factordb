#!/bin/bash
while IFS=, read -r id value; do
  curl -S --retry 10 --retry-all-errors "https://factordb.com/sequences.php?check=${id}&fr=0&to=100&action=last20&aq=${value}" | grep "${id}"
done < <(shuf < "${source}")
