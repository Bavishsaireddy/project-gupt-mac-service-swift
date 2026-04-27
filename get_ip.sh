#!/bin/bash
# GUPT - Local IP Address Finder
# Run this to get the IP address to use in the GUPT app

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 GUPT - Local Network IP Address"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get the primary local IP (Wi-Fi or Ethernet, excludes loopback)
LOCAL_IP=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)

if [ -z "$LOCAL_IP" ]; then
    echo "  ❌ No network connection found."
    echo "     Make sure you are connected to Wi-Fi or Ethernet."
else
    echo "  ✅ Your Local IP Address:"
    echo ""
    echo "     $LOCAL_IP"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📋 Copy this into the GUPT app:"
    echo ""
    echo "     Relay Server URL:  ws://$LOCAL_IP:3900"
    echo "     Localhost URL:     ws://localhost:3900"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📝 Quick Steps:"
    echo "    1. Run relay:   cd RelayServer && node server.js"
    echo "    2. Host app:    Use ws://localhost:3900"
    echo "    3. Client app:  Use ws://$LOCAL_IP:3900"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
