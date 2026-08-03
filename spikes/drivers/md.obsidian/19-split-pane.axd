# name: split pane
# reps: 3
# Deliberately does NOT close the panes afterwards. The close shortcut is cmd+w,
# and if the split shortcut turns out to be wrong on this build, cmd+w would close
# the window instead — taking the rest of the run with it. Leaving three extra
# panes open costs nothing: the only driver after this one is save.
activate
key cmd+\
sleep 700
key cmd+\
sleep 700
key cmd+\
