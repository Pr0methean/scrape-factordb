#!/bin/bash
set -u
mkdir -p "/tmp/factordb-composites"
let "minute_ns = 60 * 1000 * 1000 * 1000"
let "hour_ns = 60 * ${minute_ns}"

#	if [ ${origstart} == -1 ]; then
#		start="$(($RANDOM * 3))"
#	fi
        # Requesting lots of composites seems to trigger the server to factor the ones it's returning, so
        # request more than we intend to process and choose a subrange of the results at random to process.
        let "stimulate = 100"
        let "now = $(date +%s%N)"
        results=
        let "day_start = (${now} / (24 * ${hour_ns})) * (24 * ${hour_ns})"
        let "now_ns_of_day = ${now} - ${day_start}"
        let "now_hour_of_day = ${now_ns_of_day} / ${hour_ns}"
        if [ ${now_hour_of_day} -lt 16 -a ${now_hour_of_day} -ge 2 ]; then
          # when starting between 02:00 and 16:00 UTC (18:00 and 08:00 PST), softmax extends until 16:00 UTC
          let "min_softmax_ns = 16 * ${hour_ns} - ${now_ns_of_day}"
          let "digits = 89 + (($job * 5) % 13)" # Range of 89-101 digits at night
          let "softmax_ns = (150 - ${digits}) * ${minute_ns}"
          if [ ${softmax_ns} -lt ${min_softmax_ns} ]; then
            let "softmax_ns = ${min_softmax_ns}"
          fi
        else
          let "digits = 60 + (($job * 20) % 37)" # Range of 60-96 digits during day
          let "softmax_ns = (110 - ${digits}) * ${minute_ns}"
        fi
        let "last_start = $(date +%s%N) + $softmax_ns"
        if [ $digits -ge 89 ]; then
          let "start = (($job * 523) % 1050) * 100"
        else
          let "start = 0"
        fi
        if [ ${start} -ge 100000 ]; then
            let "start = 100000"
          let "stimulate = 5000"
        fi
        # Don't choose ones ending in 0,2,4,5,6,8, because those are still being trial-factored which may
        # duplicate our work.
        url="https://factordb.com/listtype.php?t=3&mindig=${digits}&perpage=${stimulate}&start=${start}&download=1"
        results=$(sem --id 'factordb-curl' --fg -j 4 xargs wget -e robots=off -nv --no-check-certificate --retry-connrefused --retry-on-http-error=502 -O- <<< "$url")
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
        declare exact_size_results
        if [ $digits -ge 89 ]; then
          # Assume exact size, since there are so many numbers in these sizes
          echo "${id}: Fetched batch of ${stimulate} composites with ${digits} digits"
          exact_size_results="${results}"
        else
          exact_size_results=$(grep "^[0-9]\{${digits}\}\$" <<< "$results")
          result_count=$(wc -l <<< "$exact_size_results")
          if [ ${result_count} -eq 0 ]; then
            exact_size_results=$(shuf -n 1 <<< ${results})
            echo "${id}: No results with exactly ${digits} digits, so factoring one larger composite instead"
          else
            echo "${id}: Fetched batch of ${result_count} composites with ${digits} digits"
          fi
        fi
        echo "${id}: I will factor these composites until at least $(date --date=@$((last_start / 1000000000)))"
        let "factors_so_far = 0"
        let "composites_so_far = 0"
	for num in $(shuf <<< ${exact_size_results}); do
          exec 9>/tmp/factordb-composites/${num}
          if flock -xn 9; then
              start_time=$(date +%s%N)
              if [ ${factors_so_far} -gt 0 -a ${start_time} -gt ${last_start} ]; then
                echo "${id}: $(date -Is): Running time limit reached after ${factors_so_far} factors and ${composites_so_far} composites"
                exit 0
              fi
              echo "${id}: $(date -Is): ${factors_so_far} factors and ${composites_so_far} composites done so far. Factoring ${num} with msieve"
              declare factor
              let "composites_so_far += 1"
              while read -r factor; do
                let "factors_so_far += 1"
                echo "${id}: $(date -Is): Found factor ${factor} of ${num}"
                output=$(curl -X POST --retry 10 --retry-all-errors --retry-delay 10 http://factordb.com/reportfactor.php -d "number=${num}&factor=${factor}")
                if [ $? -ne 0 ]; then
                  echo "${id}: Error submitting factor ${factor} of ${num}!"
                  echo "${num},${factor}" >> "failed-submissions.csv"
                else
                  grep -q "Already" <<< "$output"
                  if [ $? -eq 0 ]; then
                    echo "${id}: Factor ${factor} of ${num} already known! Aborting batch after ${factors_so_far} factors and ${composites_so_far} composites."
                    exit 0
                  else
                    echo "${id}: Factor ${factor} of ${num} accepted."
                  fi
                fi
              done < <(msieve -e -q -s "/tmp/msieve_${num}.dat" -t "${threads}" filter_mem_mb=512 "${num}" | grep -o ':[0-9 ]\+' | grep -o '[0-9]\+' | head -n -1 | uniq)
              end_time=$(date +%s%N)
              echo "${id}: $(date -Is): Done factoring ${num} after $(./format-nanos.sh $(($end_time - $start_time)))"
              rm "/tmp/msieve_${num}.dat"
          else
              echo "${id}: Skipping ${num} because it's already being factored"
          fi
	done
if [ ${factors_so_far} -gt 0 ]; then
  echo "${id}: Finished all factoring after ${composites_so_far} composites and ${factors_so_far} factors."
fi
