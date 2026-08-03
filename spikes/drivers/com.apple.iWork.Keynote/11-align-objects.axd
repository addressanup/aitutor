# name: align objects
# reps: 3
# Menu-driven because Keynote ships no default shortcut for alignment. That makes
# this the set's deliberate control on the "menu presses under-emit" finding: if
# the keyboard actions score Usable and this one does not, the actuator is the
# reason, not the app.
activate
key esc
key cmd+a
sleep 300
menu Arrange>Align Objects>Left
sleep 700
key cmd+z
sleep 500
key cmd+a
menu Arrange>Align Objects>Top
sleep 700
key cmd+z
sleep 500
key cmd+a
menu Arrange>Align Objects>Left
sleep 700
key cmd+z
