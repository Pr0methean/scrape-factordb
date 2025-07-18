#!/bin/sh
gnome-terminal --tab --title=Stats -- nice -+19 ./scrape-stats.sh
# gnome-terminal --tab --title=TinyComposites -- bash -c "nice -+19 ./scrape-composites-tiny.sh 2>&1 | tee /tmp/scrape-composites-tiny.txt"
gnome-terminal --tab --title=U -- bash -c "digits=2001 nice -+19 ./scrape-unknowns.sh 2>&1 | tee /tmp/scrape-unknowns.txt"
gnome-terminal --tab --title=PRP -- bash -c "digits=300 start=0 perpage=2 nice -+19 ./scrape-prps.sh 2>&1 | tee /tmp/scrape-prps.txt"
echo 5 > /tmp/scrape-composites-large-threads
gnome-terminal --tab --title=LargeC -- bash -c "./scrape-composites-large.sh 2>&1 | tee /tmp/scrape-composites-large.txt"
# gnome-terminal --tab --title=HugeFactoring -- bash -c "./scrape-composites-huge.sh 2>&1 | tee /tmp/scrape-composites-huge.txt"
