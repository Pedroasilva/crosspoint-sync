#!/bin/bash
# Quick Start Script for Crosspoint Sync Web Interface

# Trap Ctrl+C and cleanup
cleanup() {
    echo ""
    echo ""
    echo "🛑 Stopping web server..."
    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null
        wait $SERVER_PID 2>/dev/null
    fi
    echo "✅ Server stopped successfully!"
    exit 0
}

trap cleanup SIGINT SIGTERM

echo "╔════════════════════════════════════════════════════════╗"
echo "║         CROSSPOINT SYNC - WEB INTERFACE                ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Starting web server..."
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    echo "Please install Python 3 and try again"
    exit 1
fi

# Check if web-server.py exists
if [ ! -f "web-server.py" ]; then
    echo "ERROR: web-server.py not found"
    echo "Make sure you're in the crosspoint-sync directory"
    exit 1
fi

# Make web-server.py executable
chmod +x web-server.py

# Start the server in the background
python3 web-server.py &
SERVER_PID=$!

# Wait for server to start
echo "Waiting for server to start..."
sleep 2

# Check if server is running
if kill -0 $SERVER_PID 2>/dev/null; then
    echo ""
    echo "✅ Server started successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Opening browser at: http://localhost:8182/"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Open browser (try multiple methods for compatibility)
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://localhost:8182/" 2>/dev/null &
    elif command -v gnome-open &> /dev/null; then
        gnome-open "http://localhost:8182/" 2>/dev/null &
    elif command -v python3 &> /dev/null; then
        python3 -c "import webbrowser; webbrowser.open('http://localhost:8182/')" 2>/dev/null &
    fi
    
    echo "Press Ctrl+C to stop the server"
    echo ""
    
    # Wait for server process
    wait $SERVER_PID
else
    echo ""
    echo "❌ ERROR: Failed to start server"
    exit 1
fi
