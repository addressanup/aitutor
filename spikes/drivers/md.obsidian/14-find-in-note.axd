# name: find in note
# reps: 3
# Search inside the open note. Distinct from global search (15): this is an
# in-editor bar, that is a sidebar view, and telling them apart is exactly the
# kind of discrimination the density bar is asking about.
activate
key cmd+f
sleep 300
type notes
key return
sleep 400
key esc
sleep 500
key cmd+f
sleep 300
type heading
key return
sleep 400
key esc
sleep 500
key cmd+f
sleep 300
type link
key return
sleep 400
key esc
