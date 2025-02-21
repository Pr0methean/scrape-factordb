#!/usr/bin/env gnuplot
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced persist
# set logscale y 1.001
# set yrange [7.03e8:*]
plot 'stats.csv' using 1:3, '' using 1:6, '' using 1:($3 + $6)
