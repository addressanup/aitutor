# name: command palette
# reps: 3
# Opens and filters the palette but never runs a command — a run would change the
# app state under the following drivers, and the palette itself is the surface
# being measured.
activate
key cmd+p
sleep 400
type fold
sleep 400
key esc
sleep 500
key cmd+p
sleep 400
type theme
sleep 400
key esc
sleep 500
key cmd+p
sleep 400
type outline
sleep 400
key esc
