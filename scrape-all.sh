#!/bin/sh
echo 11 > /tmp/scrape-composites-large-threads
gnome-terminal --tab --title=Stats -- nice -+19 ./scrape-stats.sh
gnome-terminal --tab --title=TinyComposites -- bash -c "nice -+19 ./scrape-composites-tiny.sh 2>&1 | tee /tmp/scrape-composites-tiny.txt"
gnome-terminal --tab --title=Unknowns -- bash -c "digits=2001 nice -+19 ./scrape-unknowns.sh 2>&1 | tee /tmp/scrape-unknowns.txt"
gnome-terminal --tab --title=PRPs -- bash -c "digits=300 start=0 perpage=2 nice -+19 ./scrape-prps.sh 2>&1 | tee /tmp/scrape-prps.txt"
gnome-terminal --tab --title=LargeFactoring -- bash -c "./scrape-composites-large.sh 2>&1 | tee /tmp/scrape-composites-large.txt"
# gnome-terminal --tab --title=HugeFactoring -- bash -c "./scrape-composites-huge.sh 2>&1 | tee /tmp/scrape-composites-huge.txt"
