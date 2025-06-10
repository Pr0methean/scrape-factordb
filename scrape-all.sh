#!/bin/sh
# echo 1 > /tmp/scrape-composites-large-threads
# echo 1 > /tmp/scrape-composites-medium-threads
gnome-terminal --tab --title=Stats -- nice -+19 ./scrape-stats.sh
gnome-terminal --tab --title=HugeComposites -- nice -+19 ./scrape-composites-overhuge.sh 2>&1 | tee /tmp/scrape-composites-overhuge.txt
gnome-terminal --tab --title=Unknowns -- bash -c "digits=3000 nice -+19 ./scrape-unknowns.sh 2>&1 | tee /tmp/scrape-unknowns.txt"
gnome-terminal --tab --title=PRPs -- bash -c "digits=300 start=0 perpage=5 nice -+19 ./scrape-prps.sh 2>&1 | tee /tmp/scrape-prps.txt"
# gnome-terminal --tab --title=LargeFactoring -- ./scrape-composites-large.sh 2>&1 | tee /tmp/scrape-composites-large.txt
# gnome-terminal --tab --title=MedFactoring -- ./scrape-composites-medium.sh 2>&1 | tee /tmp/scrape-composites-large.txt

