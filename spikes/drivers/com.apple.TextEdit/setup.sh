#!/bin/bash
# Seed a rich-text scratch doc (formatting actions need RTF, not plain text)
# and open it in TextEdit. Run once before the headless density run.
set -euo pipefail
printf 'Seed line one for the density spike.\nSeed line two with more words to select and format.\n' > /tmp/aitutor-spike-seed.txt
textutil -convert rtf -output /tmp/aitutor-spike-textedit.rtf /tmp/aitutor-spike-seed.txt
open -a TextEdit /tmp/aitutor-spike-textedit.rtf
sleep 2
