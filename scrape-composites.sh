#!/bin/bash
set -u
mkdir -p "/tmp/factordb-composites"
#	if [ ${origstart} == -1 ]; then
#		start="$(($RANDOM * 3))"
#	fi
        # Requesting lots of composites seems to trigger the server to factor the ones it's returning, so
        # request more than we intend to process and choose a subrange of the results at random to process.
        stimulate=5000
        if [ ${digits} -ge 83 ]; then # have found 82-digit number that failed trial-factor check! It was 1198868704222996263303115787159415601283338389691502276178405658986301757674152006 on 2025-02-14 ~04:00Z
          if [ ${start} -ge 100000 ]; then
            let "start = 100000"
          fi
        fi
        results=
        url="https://factordb.com/listtype.php?t=3&mindig=${digits}&perpage=${stimulate}&start=${start}&download=1"
        # Don't choose ones ending in 0,2,4,5,6,8, because those are still being trial-factored which may
        # duplicate our work.
        results=$(sem --id 'factordb-curl' --fg -j 4 xargs wget -e robots=off -nv --no-check-certificate --retry-connrefused --retry-on-http-error=502 -O- <<< "$url")
        result_count=$(wc -l <<< "$results")
        echo "${id}: Fetched batch of ${result_count} composites with ${digits} or more digits; will factor ${perpage} of them"
        not_trial_factored=$(grep '[024568]$' <<< "$results")
        if [ $? -eq 0 ]; then
          count=$(wc -l <<< "$not_trial_factored")
          first=$(head -n 1 <<< "$not_trial_factored")
          echo "${id}: Found ${count} composites of ${digits} or more digits with undetected factors of 2 or 5! First is:"
          echo "${id}: ${first}"
          echo "${id}: Skipping to wait for trial factoring to catch up..."
          # sleep $(bc -l <<< "0.003 * $digits * $digits")
          exit 0
        fi
        remaining=$perpage
	for num in $(shuf -n ${perpage} <<< $results); do
          if [ $remaining -le 0 ]; then
            break
          fi
          exec 9>/tmp/factordb-composites/${num}
          if flock -xn 9; then
              echo "${id}: $(date -Is): Factoring ${num} with msieve"
              start_time=$(date +%s%N)
              declare factor
              while read -r factor; do
                echo "${id}: $(date -Is): Found factor ${factor} of ${num}"
                output=$(curl -X POST --retry 10 --retry-all-errors --retry-delay 10 http://factordb.com/reportfactor.php -d "number=${num}&factor=${factor}")
                if [ $? -ne 0 ]; then
                  echo "${id}: Error submitting factor ${factor} of ${num}!"
                  echo "${num},${factor}" >> "failed-submissions.csv"
                else
                  grep -q "Already" <<< "$output"
                  if [ $? -eq 0 ]; then
                    echo "${id}: Factor ${factor} of ${num} already known! Aborting batch."
                    let "remaining = 0"
                  else
                    echo "${id}: Factor ${factor} of ${num} accepted."
                  fi
                fi
              done < <(msieve -e -q "${num}" -s "/tmp/msieve_${num}.dat" | grep -o ':[0-9 ]\+' | grep -o '[0-9]\+' | head -n -1 | uniq)
              end_time=$(date +%s%N)
              echo "${id}: $(date -Is): Done factoring ${num} after $(./format-nanos.sh $(($end_time - $start_time)))"
          fi
          let "remaining -= 1"
          echo "${id}: ${remaining} composites left in this batch."
	done
echo "${id}: Finished batch"
