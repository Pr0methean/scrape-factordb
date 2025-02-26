#!/bin/bash
set -u
#	if [ ${origstart} == -1 ]; then
#		start="$(($RANDOM * 3))"
#	fi
        # Requesting lots of composites seems to trigger the server to factor the ones it's returning, so
        # request more than we intend to process and choose a subrange of the results at random to process.
        stimulate=5000
        if [ ${digits} -ge 83 ]; then # have found 82-digit number that failed trial-factor check! It was 1198868704222996263303115787159415601283338389691502276178405658986301757674152006 on 2025-02-14 ~04:00Z
          if [ ${start} -ge 100000 ]; then
            let "start = 100000"
          else
            let "stimulate = 500"
          fi
        fi
        results=
        url="https://factordb.com/listtype.php?t=3&mindig=${digits}&perpage=${stimulate}&start=${start}&download=1"
        # Don't choose ones ending in 0,2,4,5,6,8, because those are still being trial-factored which may
        # duplicate our work.
        results=$(sem --id 'factordb-curl' --fg -j 4 xargs wget -e robots=off -nv --no-check-certificate -O- <<< "$url")
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
          echo "${id}: $(date -Is): Factoring ${num}"
          start_time=$(date +%s%N)
          out=$(./factor "${num}")
          end_time=$(date +%s%N)
          echo "${id}: $(date -Is): Found factors ${out} of ${num} after $(($end_time - $start_time)) ns"
          factors=$(grep -o '[0-9]\+' <<< "${out}")
          if [ "${factors}" != "" ]; then
            echo "${id}: Reporting factors of ${num}"
            xargs -I 'FF' curl -X POST --retry 10 --retry-all-errors --retry-delay 10 http://factordb.com/reportfactor.php -d "number=${num}&factor=FF" <<< "${factors}" \
                    | grep -q "Already"
            if [ $? -eq 0 ]; then
              echo "${id}: ${num} already fully factored! Aborting batch."
              exit 0
            else
              echo "${id}: Reported factors of ${num}."
            fi
          fi
          let "remaining--"
          echo "${id}: ${remaining} composites left in this batch."
	done
echo "${id}: Finished batch"
