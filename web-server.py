#!/usr/bin/env python3
"""
Crosspoint Sync Web Server
Simple web server to control the crosspoint-sync.sh script via web interface
"""

import os
import sys
import subprocess
import threading
import urllib.request
import socket
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import json
import time

# Configuration
PORT = 8182
SCRIPT_PATH = "./crosspoint-sync.sh"
DEVICE_URL = "http://crosspoint.local"
DEVICE_CHECK_ENDPOINT = "/api/files?path=/"

# Global state
current_process = None
current_logs = []
process_lock = threading.Lock()


def check_device_connectivity():
    """Check if Crosspoint device is reachable"""
    try:
        request = urllib.request.Request(
            DEVICE_URL + DEVICE_CHECK_ENDPOINT,
            headers={'User-Agent': 'CrosspointSync/2.0'}
        )
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status == 200
    except (urllib.error.URLError, socket.timeout, Exception):
        return False


class CrosspointHandler(SimpleHTTPRequestHandler):
    """Custom HTTP handler for Crosspoint Sync operations"""
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Serve the web control interface
        if path == '/' or path == '/index.html':
            self.serve_control_interface()
        
        # Get current logs (Server-Sent Events endpoint)
        elif path == '/logs':
            self.stream_logs()
        
        # Get status
        elif path == '/status':
            self.get_status()
        
        # Check device connectivity
        elif path == '/device-status':
            self.get_device_status()
        
        # Default file serving
        else:
            super().do_GET()
    
    def do_POST(self):
        """Handle POST requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Execute operation
        if path == '/execute':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))
            operation = data.get('operation')
            
            self.execute_operation(operation)
        
        # Stop current operation
        elif path == '/stop':
            self.stop_operation()
        
        else:
            self.send_error(404, "Not Found")
    
    def serve_control_interface(self):
        """Serve the web control interface HTML"""
        try:
            with open('web-interface.html', 'r', encoding='utf-8') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(content.encode('utf-8'))
        except FileNotFoundError:
            self.send_error(404, "Web interface not found. Make sure web-interface.html exists.")
    
    def stream_logs(self):
        """Stream logs using Server-Sent Events"""
        global current_logs
        
        self.send_response(200)
        self.send_header('Content-type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Connection', 'keep-alive')
        self.end_headers()
        
        # Send existing logs
        for log in current_logs:
            self.wfile.write(f"data: {json.dumps({'log': log})}\n\n".encode('utf-8'))
            self.wfile.flush()
        
        # Keep connection alive and send new logs
        last_count = len(current_logs)
        timeout = 0
        while timeout < 300:  # 5 minutes timeout
            time.sleep(0.5)
            timeout += 0.5
            
            if len(current_logs) > last_count:
                for log in current_logs[last_count:]:
                    self.wfile.write(f"data: {json.dumps({'log': log})}\n\n".encode('utf-8'))
                    self.wfile.flush()
                last_count = len(current_logs)
            
            # Check if process finished
            with process_lock:
                if current_process is None or current_process.poll() is not None:
                    # Send completion event
                    self.wfile.write(f"data: {json.dumps({'status': 'completed'})}\n\n".encode('utf-8'))
                    self.wfile.flush()
                    break
    
    def get_status(self):
        """Get current operation status"""
        global current_process
        
        with process_lock:
            if current_process is None:
                status = "idle"
            elif current_process.poll() is None:
                status = "running"
            else:
                status = "completed"
        
        # Also check device connectivity
        device_connected = check_device_connectivity()
        
        response = {
            "status": status,
            "device_connected": device_connected
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode('utf-8'))
    
    def get_device_status(self):
        """Get device connectivity status only"""
        device_connected = check_device_connectivity()
        
        response = {
            "connected": device_connected,
            "device_url": DEVICE_URL
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode('utf-8'))
    
    def execute_operation(self, operation):
        """Execute the sync script with specified operation"""
        global current_process, current_logs
        
        # Validate operation
        valid_operations = ['normalize', 'backup', 'sync', 'all']
        if operation not in valid_operations:
            self.send_error(400, f"Invalid operation. Must be one of: {', '.join(valid_operations)}")
            return
        
        # Check if already running
        with process_lock:
            if current_process is not None and current_process.poll() is None:
                response = {"error": "Operation already in progress"}
                self.send_response(409)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode('utf-8'))
                return
        
        # Start the operation in a separate thread
        thread = threading.Thread(target=self.run_script, args=(operation,))
        thread.daemon = True
        thread.start()
        
        response = {"status": "started", "operation": operation}
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode('utf-8'))
    
    def run_script(self, operation):
        """Run the bash script and capture output"""
        global current_process, current_logs
        
        # Clear previous logs
        current_logs = []
        
        # Make sure script is executable
        os.chmod(SCRIPT_PATH, 0o755)
        
        # Start the process
        with process_lock:
            current_process = subprocess.Popen(
                [SCRIPT_PATH, operation],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                bufsize=1
            )
        
        # Read output line by line
        for line in iter(current_process.stdout.readline, ''):
            if line:
                current_logs.append(line.rstrip())
        
        current_process.stdout.close()
        current_process.wait()
        
        # Add completion message
        if current_process.returncode == 0:
            current_logs.append(f"✓ Operation '{operation}' completed successfully!")
        else:
            current_logs.append(f"✗ Operation '{operation}' failed with exit code {current_process.returncode}")
    
    def stop_operation(self):
        """Stop the current operation"""
        global current_process
        
        with process_lock:
            if current_process is not None and current_process.poll() is None:
                current_process.terminate()
                current_logs.append("⚠️ Operation stopped by user")
                response = {"status": "stopped"}
            else:
                response = {"status": "no_operation_running"}
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode('utf-8'))
    
    def log_message(self, format, *args):
        """Override to customize logging"""
        sys.stderr.write(f"[{self.log_date_time_string()}] {format % args}\n")


def main():
    """Main entry point"""
    # Check if script exists
    if not os.path.exists(SCRIPT_PATH):
        print(f"ERROR: Script not found: {SCRIPT_PATH}")
        print("Make sure crosspoint-sync.sh is in the current directory")
        sys.exit(1)
    
    # Check if web interface exists
    if not os.path.exists('web-interface.html'):
        print("WARNING: web-interface.html not found")
        print("The web interface will not be available")
    
    # Start server
    server = HTTPServer(('', PORT), CrosspointHandler)
    print("=" * 60)
    print("🚀 Crosspoint Sync Web Server Started")
    print("=" * 60)
    print(f"Server running on: http://localhost:{PORT}")
    print(f"Web Interface:     http://localhost:{PORT}/")
    print("")
    print("Press Ctrl+C to stop the server")
    print("=" * 60)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\n🛑 Server stopped by user")
        print("Goodbye!")
        sys.exit(0)


if __name__ == '__main__':
    main()
