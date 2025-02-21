#!/usr/bin/env gnuplot
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced persist
set logscale y 1.001
# set yrange [0:*]
plot 'stats.csv' using 1:($2 + $4)
