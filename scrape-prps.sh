#!/bin/bash
set -u
let "min_start = 0"
urlstart='https://factordb.com/listtype.php?t=1&mindig='
let "min_checks_per_restart = 30 * 254"
let "min_checks_per_id_at_restart = 254 / 4"
let "checks_since_restart = 0"
fifo="$1"
echo "Writing to $fifo"
while true; do
	url="${urlstart}${digits}&perpage=${perpage}\&start=${start}"
	echo "Running search: ${url}"
	results=$(sem --id 'factordb-curl' -j 2 --fg xargs wget -e robots=off --no-check-certificate -t 10 -T 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<<"$url")
	for id in $(grep -o 'index.php?id=[0-9]\+' <<<"$results" |
                grep -o '[0-9]\+' |
		uniq); do
		let "restart = 0"
		echo "Checking ID ${id}"
		status=$(sem --id 'factordb-curl' -j 2 --fg xargs wget -e robots=off --no-check-certificate -t 10 -T 10 -nv -O- --retry-connrefused --retry-on-http-error=502 <<<"https://factordb.com/index.php\?id=${id}\&open=prime\&ct=Proof")
		bases_checked_html=$(grep -A1 'Bases checked' <<<"$status")
		bases_checked_lines=$(grep -o '[0-9]\+' <<<"$bases_checked_html")
		declare -a bases_left
		readarray -t bases_left < <(echo {2..255} "${bases_checked_lines}" | tr ' ' '\n' | sort -n | uniq -u | grep .)
		if [ ${#bases_left[@]} -eq 0 ]; then
			echo "ID ${id} already has all bases checked"
			continue
		fi
		actual_digits=$(grep -o '&lt;[0-9]\+&gt;' <<<"$status" | head -n 1 | grep -o '[0-9]\+')
                if [ "$actual_digits" != "" ]; then
		  echo "${id}: This PRP is ${actual_digits} digits with ${#bases_left[@]} bases left to check: ${bases_left[@]}"
	 	  # Use a subprocess to check this PRP while searching for another
		  echo "$id $actual_digits ${bases_left[@]}" >> $fifo
		  let "checks_since_restart += ${#bases_left[@]}"
                fi
	done

	if [ $restart -eq 0 ]; then
		if [ $(($start + $perpage)) -gt 100000 ]; then
			echo "${checks_since_restart} PRP checks launched; restarting since we reached max start of 100000"
			let "restart = 1"
                else
		  # Restart once we have found enough PRP checks that weren't already done
                  let "expected_checks_per_restart = ${start} * ${min_checks_per_id_at_restart}"
                  if [ ${expected_checks_per_restart} -lt ${min_checks_per_restart} ]; then
                        let "expected_checks_per_restart = ${min_checks_per_restart}"
                  fi
       		  if [ ${checks_since_restart} -ge ${expected_checks_per_restart} ]; then
			echo "${checks_since_restart} PRP checks launched; restarting due to sufficient number"
			let "restart = 1"
                  fi
                fi
	fi
	if [ $restart -ne 0 ]; then
		let "checks_since_restart = 0"
		let "start = ${min_start}"
		continue
	else
		let "start += ${perpage}"
		echo "${checks_since_restart} PRP checks launched after checking ${start} IDs; advancing"
	fi
done
