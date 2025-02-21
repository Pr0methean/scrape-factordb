#!/usr/bin/env gnuplot
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced persist
plot 'stats.csv' using 1:($2 + $4), '' using 1:($3 + $5 + $6) axes x1y2
