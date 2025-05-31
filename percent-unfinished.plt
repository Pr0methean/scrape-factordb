#!/usr/bin/env gnuplot
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S%z"
set format x "%m-%d %H:%M"
set format y "%5.4f %%"
set key autotitle columnheader
set style data lines
set datafile separator ','
set terminal wxt enhanced persist size 1800,1080
f(x) = b - a*x 
a=0.45 
b=1.5e9 
FIT_LIMIT=1e-16 
fit f(x) 'stats.csv' 
plot 'stats.csv' using 1:(100. * ($3 + $5 + $6)/($2 + $3 + $4 + $5 + $6))
title "Trendline"
