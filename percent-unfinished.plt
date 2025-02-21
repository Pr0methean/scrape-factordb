#!/usr/bin/env gnuplot
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set format y "%5.4f %%"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced persist size 1800,1080
# set logscale y 1.001
# set yrange [0:*]
plot 'stats.csv' using 1:(100. * ($3 + $5 + $6)/($2 + $3 + $4 + $5 + $6))

