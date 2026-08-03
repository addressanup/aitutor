# name: heading via hash
# reps: 3
# Obsidian has no default heading hotkey; a learner types the hashes. They cannot
# be typed with `type` because the DSL treats a literal hash as a comment, so they
# go through the keycode table as shift+3.
activate
key cmd+a
key right
key return
key shift+3
key space
type First heading level one
sleep 500
key return
key shift+3
key shift+3
key space
type Second heading level two
sleep 500
key return
key shift+3
key shift+3
key shift+3
key space
type Third heading level three
