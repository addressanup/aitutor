# name: delete slide
# reps: 3
# The click moves focus into the slide navigator, where delete removes a slide
# rather than an object. Every deletion is undone in its own burst, so the deck
# still has four slides when the reorder driver starts.
activate
click 7% 30%
sleep 400
key delete
sleep 600
key cmd+z
sleep 600
key delete
sleep 600
key cmd+z
sleep 600
key delete
sleep 600
key cmd+z
