#!/bin/bash
let "next_cpu_budget_reset = 0"
let "cpu_budget_max = 7 * 60 * 1000 * 1000 * 1000"
let "cpu_budget_reset_period_secs = 60 * 60"
let "cpu_budget = 0"

set -u
id=""
bases_left=()
while read id; do
        read actual_digits
        read -a bases_left
	let "stopped_early = 0"
	let "bases_actually_checked = 0"
        let "cpu_cost = ($actual_digits * $actual_digits * $actual_digits + 8000000000)"
        echo "{id}: This PRP has ${actual_digits} digits and ${#bases_left[@]} bases left to check; estimated CPU cost is $(./format-nanos.sh $(($cpu_cost * ${#bases_left[@]})))"
	for base in "${bases_left[@]}"; do
                if [ $now -lt $next_cpu_budget_reset ]; then
                        let "cpu_budget = $cpu_budget - $cpu_cost"
                        if [ $cpu_budget -lt 0 ]; then
                                let "delay = $next_cpu_budget_reset - $now"
                                echo "Throttling for $delay seconds, because our budget is $(./format-nanos.sh $((-$cpu_budget))) short. Press SPACE to skip."
                                if read -t $delay -n 1; then
                                        echo "$(date -Is): Throttling skipped."
                                        let "time_after = $(date '+%s')"
                                        let "delay = $time_after - $now"
                                else
                                        echo "$(date -Is): Throttling delay finished."
                                        let "cpu_budget = $cpu_budget_max - $cpu_cost"
                                fi
                        fi
                else
                        echo "$(date -Is): CPU budget has been refreshed."
                        let "next_cpu_budget_reset = $now + $cpu_budget_reset_period_secs"
                        let "cpu_budget = $cpu_budget_max - $cpu_cost"
                fi
                echo "Remaining CPU budget is $(./format-nanos.sh $cpu_budget)."

		let "bases_actually_checked += 1"
		url="https://factordb.com/${id}\&open=prime\&basetocheck=${base}"
		output=$(sem --id 'factordb-curl' -j 4 --fg xargs wget -e robots=off --no-check-certificate -nv -O- -t 10 -T 10 --retry-connrefused --retry-on-http-error=502 <<<"$url")
		if [ $? -eq 0 ]; then
			if grep -q 'set to C' <<<"$output"; then
				echo "${id}: No longer PRP (ruled out by PRP check)"
				let "stopped_early = 1"
				break
			elif grep -q '\(Verified\|Processing\)' <<<"$output"; then
				echo "${id}: No longer PRP (certificate received)"
				let "stopped_early = 1"
				break
			elif ! grep -q 'PRP' <<<"$output"; then
				echo "${id}: No longer PRP (ruled out by factor or N-1/N+1 check)"
				let "stopped_early = 1"
				break
			fi
		fi
	done
        if [ "$stopped_early" -eq "0" ]; then
		echo "${id}: All bases checked"
	fi
done
