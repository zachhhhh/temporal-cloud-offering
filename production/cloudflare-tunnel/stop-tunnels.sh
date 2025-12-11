#!/bin/bash
echo "Stopping all tunnels..."
pkill -f "cloudflared tunnel" 2>/dev/null
echo "Done."
