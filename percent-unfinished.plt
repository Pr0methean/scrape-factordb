#!/usr/bin/env -S gnuplot
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set format y "%5.4f %%"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced size 1800,1080
f(x) = b - a*x 
a=3.3e-8
b=65.0
FIT_LIMIT=1e-16 
fit f(x) 'stats.csv' using 1:(100. * ($3 + $5 + $6)/($2 + $3 + $4 + $5 + $6)) via a, b
set xrange noextend
plot 'stats.csv' using 1:(100. * ($3 + $5 + $6)/($2 + $3 + $4 + $5 + $6)) title "% unfinished entries", f(x) title "Trendline"
pause -1
