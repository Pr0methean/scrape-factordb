#!/usr/bin/env -S gnuplot -persist
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced size 1800,1080
# set yrange [7.03e8:*]
start=time(0) - 86400
# end=strftime("%Y-%m-%dT%H:%M:%S%z", time(0))
f(x) = b - a*x
a=0.45
b=1.5e9
FIT_LIMIT=1e-16
fit [start:] f(x) 'stats.csv' using 1:($3 + $5 + $6) via a, b
plot [start:] 'stats.csv' using 1:($3 + $5 + $6) title "Unfinished entries", f(x) title "Trendline"
