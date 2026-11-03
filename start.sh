#!/bin/bash
# zakiera start — jalanin server + ngrok, auto-update URL di bot Lua
cd /Users/macbookpro/orca/projects/zakiera

# Kill existing
kill $(lsof -ti:3000) 2>/dev/null
pkill -f "ngrok http 3000" 2>/dev/null
sleep 1

# Start server
node server.js &
sleep 1

# Start ngrok
ngrok http 3000 --log=stdout &
sleep 3

# Ambil URL ngrok
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "import sys,json; print(json.load(sys.stdin)['tunnels'][0]['public_url'])")
echo "Ngrok URL: $NGROK_URL"

# Update zakiera_bot.lua
sed -i '' "s|local ZAKIERA_URL = \".*\"|local ZAKIERA_URL = \"$NGROK_URL\"|" zakiera_bot.lua
echo "Bot Lua updated."

# Buka browser
open "http://localhost:3000"
open /Users/macbookpro/orca/projects/zakiera/

echo ""
echo "==================================="
echo " ZAKIERA RUNNING"
echo " Web GUI : http://localhost:3000"
echo " Bot URL : $NGROK_URL"
echo " Lua file: $(pwd)/zakiera_bot.lua"
echo "==================================="
