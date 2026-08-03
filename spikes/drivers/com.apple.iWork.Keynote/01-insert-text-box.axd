# name: insert text box
# reps: 3
# Keynote drops a new text box in the middle of the canvas, in text-editing mode;
# esc steps out to object selection so the drag moves the box instead of selecting
# its placeholder text. The three boxes are parked at known fractions because every
# later canvas driver has to be able to find them again.
activate
menu Insert>Text Box
key esc
drag 45% 52% 30% 30%
sleep 600
menu Insert>Text Box
key esc
drag 45% 52% 55% 30%
sleep 600
menu Insert>Text Box
key esc
drag 45% 52% 30% 65%
