# name: play and exit slideshow
# reps: 3
# The largest state change the app can make: it takes over the display and swaps
# the whole AX tree. The generous sleeps are for the transition animations, and
# the trailing escape is insurance against a slideshow that outlives the run.
activate
key cmd+opt+p
sleep 1800
key esc
sleep 1200
key cmd+opt+p
sleep 1800
key esc
sleep 1200
key cmd+opt+p
sleep 1800
key esc
sleep 800
key esc
