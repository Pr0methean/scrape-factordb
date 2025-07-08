#!/usr/bin/env -S gnuplot -c
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced size 1800,1080
set grid xtics ytics
start=time(0) - (86400 * (ARG1 + 0))
# set yrange [7.03e8:*]
f(x) = b - a*x
a=0.01
b=1e6
FIT_LIMIT=1e-16
fit [start:] f(x) 'stats.csv' using 1:3 via a, b
set xrange noextend
plot [start:] 'stats.csv' using 1:3 title "Probable primes", f(x) title "Trendline"
pause -1
