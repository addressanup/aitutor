# name: toggle checkbox
# reps: 3
# First burst builds one task line by hand (the brackets auto-pair, hence the
# right arrow to step over the closing one); the three that follow are the action.
activate
key cmd+a
key right
key return
type -
key space
key [
key space
key right
key space
type Read the linked note
sleep 500
key cmd+return
sleep 500
key cmd+return
sleep 500
key cmd+return
