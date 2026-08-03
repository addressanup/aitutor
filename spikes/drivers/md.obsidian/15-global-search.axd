# name: global search
# reps: 3
# Leaves focus in the left sidebar's search field. Driver 17 (switch note) is what
# puts focus back in an editor, which is why it comes after this one.
activate
key cmd+shift+f
sleep 400
type vault
sleep 600
key cmd+shift+f
sleep 400
type notes
sleep 600
key cmd+shift+f
sleep 400
type link
