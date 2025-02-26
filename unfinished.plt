#!/usr/bin/env gnuplot
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced persist size 1800,1080
# set yrange [7.03e8:*]
f(x) = b - a*x
FIT_LIMIT=1e-16
fit f(x) 'stats.csv' using 1:($3 + $5 + $6) via a, b
plot 'stats.csv' using 1:($3 + $5 + $6) title "Unfinished entries", f(x) title "Trendline"
