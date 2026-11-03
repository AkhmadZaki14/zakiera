#!/bin/bash
# zakiera-update.sh — narik zakiera_bot.lua terbaru dari GitHub

DEST="/Users/macbookpro/orca/projects/zakiera/zakiera_bot.lua"

echo "Narik zakiera_bot.lua terbaru..."
curl -s "https://raw.githubusercontent.com/AkhmadZaki14/zakiera/master/zakiera_bot.lua" -o "$DEST"

echo "Done. File: $DEST"
open /Users/macbookpro/orca/projects/zakiera/
