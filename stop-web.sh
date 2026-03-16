#!/bin/bash
# Stop Crosspoint Sync Web Server

echo "🛑 Stopping Crosspoint Sync Web Server..."
echo ""

# Find and kill all web-server.py processes
PIDS=$(pgrep -f "web-server.py")

if [ -z "$PIDS" ]; then
    echo "✓ No web server processes found running"
    exit 0
fi

# Kill each process
for PID in $PIDS; do
    echo "  Stopping process $PID..."
    kill $PID 2>/dev/null
    
    # Wait a bit for graceful shutdown
    sleep 1
    
    # Force kill if still running
    if kill -0 $PID 2>/dev/null; then
        echo "  Force stopping process $PID..."
        kill -9 $PID 2>/dev/null
    fi
done

echo ""
echo "✅ Web server stopped successfully!"
