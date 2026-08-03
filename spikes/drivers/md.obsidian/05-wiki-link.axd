# name: insert wiki link
# reps: 3
# Typing the opening brackets auto-closes them and raises the link suggester;
# esc dismisses the suggester and leaves a complete link. That popup is the
# interesting part — it is rendered by the web view, not by AppKit.
activate
key cmd+a
key right
key return
type [[
type Note B
key esc
sleep 500
key return
type [[
type Note C
key esc
sleep 500
key return
type [[
type Scratch
key esc
