#!/usr/bin/env -S gnuplot
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced size 1800,1080
# set yrange [7.03e8:*]
f(x) = b + a*x
a=33
b=-5e+10
FIT_LIMIT=1e-16
fit f(x) 'stats.csv' using 1:($2 + $4) via a, b
set xrange noextend
plot 'stats.csv' using 1:($2 + $4) title "Finished entries", f(x) title "Trendline"
pause -1
