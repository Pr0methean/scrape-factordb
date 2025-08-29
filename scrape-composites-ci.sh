#!/bin/bash
set -u
touch "/tmp/delete_to_cancel_scrape_composites_batch_${id}"
mkdir -p "/tmp/factordb-composites"
let "minute_ns = 60 * 1000 * 1000 * 1000"
let "hour_ns = 60 * ${minute_ns}"
        # Requesting lots of composites seems to trigger the server to factor the ones it's returning, so
        # request the next power of 2 up from the maximum number we can possibly process
        let "stimulate = 64"
        results=
        if [ ${digits} -le 89 ]; then
          let "start = 0"
          let "stimulate = 5000"
        elif [ ${start} -ge 100000 ]; then
          let "start = 100000"
          let "stimulate = 5000"
        fi
        # Don't choose ones ending in 0,2,4,5,6,8, because those are still being trial-factored which may
        # duplicate our work.
        url="https://factordb.com/listtype.php?t=3&mindig=${digits}&perpage=${stimulate}&start=${start}&download=1"
        results=$(wget -e robots=off -nv --no-check-certificate --retry-connrefused --retry-on-http-error=502 -O- "$url")
        declare exact_size_results
        if [ $digits -ge 90 ]; then
          # Assume exact size, since there are so many numbers in these sizes
          echo "${id}: Fetched batch of ${stimulate} composites with ${digits} digits"
          exact_size_results="${results}"
        else
          let "start = 0"
          let "stimulate = 5000"
          exact_size_results=$(grep "^[0-9]\{${digits}\}\$" <<< "$results")
          result_count=$(wc -l <<< "$exact_size_results")
          if [ ${result_count} -le 1 ]; then
            exact_size_results=$(shuf -n 64 <<< ${results})
            echo "${id}: No results with exactly ${digits} digits, so factoring larger composites instead"
          else
            echo "${id}: Fetched batch of ${result_count} composites with ${digits} digits"
          fi
        fi
        let "factors_so_far = 0"
        let "composites_so_far = 0"
	for num in $(shuf <<< ${exact_size_results}); do
          if [ ! -f "/tmp/delete_to_cancel_scrape_composites_batch_${id}" ]; then
            echo "${id}: $(date -Is): Aborting because /tmp/delete_to_cancel_scrape_composites_batch_${id} was deleted"
            exit 0
          fi
          exec 9>/tmp/factordb-composites/${num}
          if flock -xn 9; then
              start_time=$(date +%s%N)
              echo "${id}: $(date -Is): ${factors_so_far} factors and ${composites_so_far} composites done so far. Factoring ${num} with msieve"
              declare factor
              let "composites_so_far += 1"
              while read -r factor; do
                let "factors_so_far += 1"
                now="$(date -Is)"
                echo "${id}: ${now}: Found factor ${factor} of ${num}"
                output=$(curl -X POST --retry 10 --retry-all-errors --retry-delay 10 http://factordb.com/reportfactor.php -d "number=${num}&factor=${factor}")
                if [ $? -ne 0 ]; then
                  echo "${id}: Error submitting factor ${factor} of ${num}!"
                  echo "\"${now}\",${num},${factor}" >> "failed-submissions.csv"
                else
                  echo "\"${now}\",${num},${factor}" >> "factor-submissions.csv"
                  grep -q "Already" <<< "$output"
                  if [ $? -eq 0 ]; then
                    echo "${id}: Factor ${factor} of ${num} already known! Aborting batch after ${factors_so_far} factors and ${composites_so_far} composites."
                    exit 0
                  else
                    echo "${id}: Submitting factor ${factor}: $output"
                    echo "${id}: Factor ${factor} of ${num} accepted."
                  fi
                fi
              done < <(./msieve -e -q -s "/tmp/msieve_${num}.dat" -t "${threads}" "${num}" | grep -o ':[0-9 ]\+' | grep -o '[0-9]\+' | head -n -1 | uniq)
              end_time=$(date +%s%N)
              echo "${id}: $(date -Is): Done factoring ${num} after $(./format-nanos.sh $(($end_time - $start_time)))"
          else
              echo "${id}: Skipping ${num} because it's already being factored"
          fi
	done
echo "${id}: Finished all factoring after ${composites_so_far} composites and ${factors_so_far} factors."
