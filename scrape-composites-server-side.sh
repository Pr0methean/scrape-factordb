#!/bin/bash
while IFS=, read -r id value; do
  curl "https://factordb.com/sequences.php?check=${id}&fr=0&to=100&action=last20&aq=${value}"
done < C91.csv
