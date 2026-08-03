# name: insert shape
# reps: 3
# The only driver in the set with no keyboard path at all: Keynote gives shape
# insertion neither a shortcut nor a stable toolbar identifier, so the menu is it.
# If this path does not resolve on the installed version, axdrive fails this one
# action loudly and the other nineteen still run.
activate
key esc
menu Insert>Shape>Rectangle
drag 45% 52% 62% 62%
sleep 600
menu Insert>Shape>Rectangle
drag 45% 52% 62% 40%
sleep 600
menu Insert>Shape>Rectangle
drag 45% 52% 20% 45%
