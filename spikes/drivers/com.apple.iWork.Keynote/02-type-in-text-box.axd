# name: type in text box
# reps: 3
# Double-click enters the box for text editing; cmd+a there selects its text, not
# the slide's objects, so the typing replaces the placeholder.
activate
doubleclick 30% 30%
key cmd+a
type Observation layer
key esc
sleep 600
doubleclick 55% 30%
key cmd+a
type Density spike
key esc
sleep 600
doubleclick 30% 65%
key cmd+a
type Canvas control
key esc
