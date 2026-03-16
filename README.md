# Crosspoint Sync

A Bash script for synchronizing files with Crosspoint devices, with support for file name normalization, automatic backup, and image conversion.

## 📋 What the Script Does

**Crosspoint Sync** is a synchronization tool that offers:

- **Name Normalization**: Cleans file names (replaces spaces with underscores, removes dashes)
- **Remote Backup**: Creates a complete backup of files from the remote device
- **File Synchronization**: Uploads files to the remote device
- **Image Conversion**: Automatically converts JPG, PNG, and GIF to BMP format
- **Original Preservation**: Maintains a copy of original files before conversion
- **Automatic Organization**: Organizes files in folders (processed, backup, originals)
- **Interactive Menu**: User-friendly interface with 5 operation options

## ⚠️ IMPORTANT WARNINGS - READ BEFORE USE

### Mandatory Backup
**It is MANDATORY to perform a complete manual backup of all content on your Crosspoint device before using this script.**

This script modifies and uploads files to your device. Any error, code bug, or improper usage can result in irreversible data loss.

### Legal Disclaimer
**I am not responsible for:**
- Data loss
- Device malfunction
- Damage caused by script usage
- Code errors or limitations

Use this script **at your own risk**.

## ℹ️ About This Project

- **Type**: Hobby and testing project
- **Status**: Under continuous development
- **Contributions**: Improvements and suggestions are very welcome!
- **License**: Free code - can be copied, distributed, and modified freely

## 🚀 System Requirements

### Supported Operating Systems
- ✅ **Linux** (Debian/Ubuntu, Red Hat/CentOS, Arch Linux)
- ✅ **macOS**
- ❌ Windows (not tested; may work via WSL)

### Required Dependencies
The script automatically checks and installs the following dependencies:

- **curl**: For HTTP requests to the remote device
- **jq**: For processing JSON responses from the API
- **ImageMagick** (`convert` command): For converting images to BMP

If dependencies are not installed, the script will attempt to install them automatically using your system's package manager.

### Hardware Requirements
- Network connectivity with the Crosspoint device
- Sufficient disk space for files and backups
- Read/write permissions in the working directory

### Device Setup Requirements
**⚠️ Important: Your Crosspoint device MUST be on the Wi-Fi transfer screen before running the script.**

The device needs to be actively in the Wi-Fi transfer mode for the script to communicate with it and transfer files successfully.

## 📦 Installation

### 1. Clone or Download the Script

```bash
# Via Git
git clone https://github.com/Pedroasilva/crosspoint-sync.git
cd crosspoint-sync

# Or download manually and extract the file
```

### 2. Grant Execute Permission

```bash
chmod +x crosspoint-sync.sh
chmod +x web-server.py  # For web interface
```

### 3. (Optional) Check Dependencies

```bash
./crosspoint-sync.sh
```

The script will automatically detect missing dependencies and offer to install them.

### 4. 📁 Prepare Your Files

**Important:** All files for synchronization should be placed in the `files/` directory.

```bash
# The script will create the files/ directory automatically on first run
# Or create it manually:
mkdir files

# Copy your images to sync:
cp /path/to/your/images/*.jpg files/
cp /path/to/your/images/*.png files/

# For sleep mode images, create a sleep subfolder:
mkdir files/sleep
cp /path/to/sleep/images/* files/sleep/
```

**Note:** The `files/` directory keeps all your work organized and separate from the script files.

## 🎬 Quick Start

**Want to start right away? Here are the fastest ways:**

### 🌐 Option 1: Web Interface (Easiest)

```bash
# Super quick way - just run this:
./start-web.sh

# Or manually:
./web-server.py

# Then: Browser will open automatically at http://localhost:8182
```

**What you'll see:**
- 🖱️ 4 beautiful operation cards (click to execute)
- 📊 Real-time logs with colors
- 🎯 Visual status indicator
- 🌐 Auto-opens in your default browser

### 💨 Option 2: Quick Command

```bash
# Run a specific operation directly
./crosspoint-sync.sh backup    # Backup everything
./crosspoint-sync.sh sync       # Upload files
./crosspoint-sync.sh all        # Do everything
```

### 📋 Option 3: Interactive Menu

```bash
# Classic interactive mode
./crosspoint-sync.sh
# Follow the on-screen menu
```

## 🚀 Usage Guide

### Basic Execution

There are **three ways** to use Crosspoint Sync:

#### 1. 🌐 Web Interface (Recommended - New!)

Start the web server and control everything through your browser:

```bash
# Quick start (auto-opens browser)
./start-web.sh

# Or manually
chmod +x web-server.py
./web-server.py
```

Access: **http://localhost:8182**

**Features:**
- 🖱️ Click-to-execute operations
- 📊 Real-time logs in the browser
- 🎯 Visual status indicators
- 🌈 Modern and intuitive interface
- 🚀 Auto-opens in your default browser

**Stopping the server:**
```bash
# Option 1: Press Ctrl+C in the terminal where the server is running
# The server will stop gracefully

# Option 2: Run the stop script from another terminal
./stop-web.sh
```

#### 2. 💻 Command Line Interface (CLI)

Execute operations directly from the terminal:

```bash
# Run specific operation
./crosspoint-sync.sh normalize    # Normalize file names
./crosspoint-sync.sh backup       # Full backup
./crosspoint-sync.sh sync         # Synchronization
./crosspoint-sync.sh all          # All operations

# Examples:
./crosspoint-sync.sh backup       # Quick backup
./crosspoint-sync.sh sync         # Upload new files
```

**Advantages:**
- ⚡ Fast execution
- 🤖 Easy to automate (cron, scripts)
- 📝 Direct log output

#### 3. 📋 Interactive Menu (Classic)

Run the script without parameters for the traditional menu:

```bash
./crosspoint-sync.sh
```

You will see an interactive menu with the following options:

```
╔════════════════════════════════════════════════════════╗
║        CROSSPOINT SYNC - SELECT OPERATION              ║
╚════════════════════════════════════════════════════════╝

1) Normalize file names (local and remote)
2) Full remote backup
3) Sync files
4) Run ALL (normalize + backup + sync)
5) Exit
```

### Detailed Operation Options

#### 1️⃣ Normalize file names (local and remote)

Cleans file names by:
- Replacing spaces with underscore
- Removing dashes (`-`) and em-dashes (`—`)
- Removing double underscores (converts multiple underscores to single)

Examples:
- **Local**: `My File-Photo.jpg` → `My_FilePhoto.jpg`
- **Remote**: `Image — 2024.png` → `Image_2024.png`
- **Double spaces**: `My  File.jpg` → `My_File.jpg`

Useful to ensure compatibility with systems that don't support special characters in file names.

#### 2️⃣ Full remote backup

Creates a complete backup of **all** files on the remote device:

- Creates local folder `remote_backup/`
- If `remote_backup/` already exists, replaces it
- Downloads files from device root
- Downloads files from `/sleep` folder (if it exists)

Use this option regularly as a safety measure.

#### 3️⃣ Sync files

Performs synchronization of your local files with the remote device:

1. Backs up original files in the `originals/` folder
2. Converts images (JPG, PNG, GIF) to BMP format
3. Uploads files to the device
4. Keeps original files preserved
5. Organizes processed files in the `processed/` folder

**Important behavior**:
- Checks if file already exists remotely before uploading
- Files from `files/` root are uploaded to `/` on the device
- Files from `files/sleep/` folder are uploaded to `/sleep` on the device
- Images are converted to BMP (format expected by Crosspoint)
- Does not delete any files, only moves them to the `files/processed/` folder
- **Place your images to sync in the `files/` directory**
- **Ignored files**: Script files (.sh), documentation (.md), web files (.html, .py) are automatically ignored in all operations (backup, normalization, sync)

#### 4️⃣ Run ALL (normalize + backup + sync)

Executes all operations in sequence:

1. Backup of originals
2. Name normalization
3. Remote backup
4. Complete synchronization

Use this option for a complete workflow.

#### 5️⃣ Exit

Exits the script.

### Folder Structure Created

After using the script, you will have the following structure:

```
crosspoint-sync.sh              # The main script
web-server.py                   # Web server for browser interface
web-interface.html              # Web control interface
start-web.sh                    # Quick start script for web interface
stop-web.sh                     # Stop web server script
files/                          # Working directory (all sync files here)
├── remote_backup/              # Backup of remote files
│   ├── file1.bmp
│   ├── file2.bmp
│   └── sleep/                  # Backup of remote /sleep folder
│       ├── image1.bmp
│       └── image2.bmp
├── originals/                  # Original files before conversion
│   ├── original_file.jpg
│   ├── original_file.png
│   └── sleep/                  # Originals from sleep folder
│       ├── image.jpg
│       └── image.png
├── processed/                  # Files already processed and uploaded
│   ├── file1.bmp
│   ├── file2.bmp
│   └── sleep/
│       ├── image1.bmp
│       └── image2.bmp
└── [your image files]          # Place your files to sync here
└── sleep/
    ├── image1.bmp
    └── image2.bmp
```

### What is the Web Interface?

The Web Interface is a **new modern way** to control Crosspoint Sync through your web browser. No need to use the terminal - everything is visual and intuitive!

### Starting the Web Server

```bash
# 1. Make the server executable (first time only)
chmod +x web-server.py

# 2. Start the server
./web-server.py

# Output:
# ============================================================
# 🚀 Crosspoint Sync Web Server Started
# ============================================================
# Server running on: http://localhost:8182
# Web Interface:     http://localhost:8182/
# ============================================================
```

### Accessing the Interface

Open your web browser and go to: **http://localhost:8182**

### Interface Features

#### 1. 🎯 Operation Cards
Click on any card to execute:
- **✏️ Normalization**: Clean file names (replace spaces, remove dashes)
- **📦 Full Backup**: Download all files from device
- **🔄 Synchronization**: Upload files to device
- **🚀 Run All**: Execute all operations in sequence

#### 2. 📊 Real-Time Logs
- Watch operation progress live
- Colored logs (errors in red, success in green)
- Auto-scroll to latest message
- Clear logs button

#### 3. 🔔 Status Indicator
- **⚫ Idle**: System ready
- **🟢 Running**: Operation in progress (with animation)
- **🔵 Completed**: Operation finished successfully

#### 4. 📈 Quick Actions
- **Clear**: Clean the logs display

### Web Interface Advantages

✅ **User-Friendly**: No need to remember commands  
✅ **Visual Feedback**: See exactly what's happening  
✅ **Remote Access**: Access from any device on the network*  
✅ **Safe**: Confirms before executing operations  
✅ **Modern**: Beautiful and professional interface  
✅ **Responsive**: Works on desktop, tablet, and mobile  

*To access from other devices, replace `localhost` with your computer's IP address

### Web Server Technical Details

**Technology:**
- Python 3 HTTP server
- Server-Sent Events (SSE) for real-time logs
- RESTful API for operations
- Zero external dependencies

**Endpoints:**
- `GET /` - Web control interface
- `GET /logs` - Stream logs (SSE)
- `GET /status` - Check system status
- `POST /execute` - Execute operation
- `POST /stop` - Stop current operation

**Port:** 8182 (configurable in web-server.py)

### Stopping the Server

Press `Ctrl+C` in the terminal where the server is running.

### Troubleshooting Web Interface

**Port already in use?**
```bash
# Check what's using port 8182
sudo lsof -i :8182

# Or edit web-server.py and change PORT = 8182 to another port
```

**Cannot connect?**
- Make sure the server is running
- Check firewall settings
- Verify Python 3 is installed: `python3 --version`

**Operation not starting?**
- Ensure Crosspoint device is on and in Wi-Fi transfer mode
- Check device connectivity from the terminal first

## 🔧 Configuration

### Device Address

By default, the script tries to connect to:

```bash
DEVICE="http://crosspoint.local"
```

If your device is at a different address, edit line 5 of the script:

```bash
DEVICE="http://your-address-here"
```

## 📝 Usage Examples

### Example 1: Complete Backup

```bash
./crosspoint-sync.sh
# Select option 2
```

Creates `remote_backup/` with all files from the device.

### Example 2: Synchronize New Files

```bash
# Place your files in the files/ folder
./crosspoint-sync.sh
# Select option 3
```

Converts and uploads files to the device.

### Example 3: Complete Workflow

```bash
./crosspoint-sync.sh
# Select option 4
```

Normalizes names, makes a remote backup, and syncs everything in a single operation.

## 🐛 Troubleshooting

### Error: "curl: command not found"

The script will try to install automatically. Otherwise:

**Debian/Ubuntu:**
```bash
sudo apt-get install curl
```

**macOS:**
```bash
brew install curl
```

### Error: "jq: command not found"

**Debian/Ubuntu:**
```bash
sudo apt-get install jq
```

**macOS:**
```bash
brew install jq
```

### Error: "convert: command not found"

**Debian/Ubuntu:**
```bash
sudo apt-get install imagemagick
```

**macOS:**
```bash
brew install imagemagick
```

### Device not responding

Check:
1. Is the device powered on?
2. Is it connected to the network?
3. Is the address correct? (check the `DEVICE` variable)
4. Is there a firewall blocking the connection?

### Script doesn't have execute permission

```bash
chmod +x crosspoint-sync.sh
```

## 📚 Additional Topics

### Image Conversion

The script uses ImageMagick to convert images:
- **Input**: JPG, JPEG, PNG, GIF (any size)
- **Output**: BMP (Crosspoint native format)
- **Compression**: Maintains original quality
- **Support**: Preserves transparency and animations when possible

### Original File Preservation

All files are automatically backed up in `originals/` before conversion:
- **Originals remain intact**: Not modified
- **Easy recovery**: If you need the original file later
- **Documentation**: Maintains history of what was sent

### Security and Best Practices

- ✅ Always make a manual backup before using
- ✅ Test the script in a test environment first
- ✅ Monitor files created in each folder
- ✅ Keep copies of originals in another location
- ✅ Review the logs of each operation

## 🤝 Contributing

This project is open to contributions! If you found a bug, have a suggestion for improvement, or want to add a feature:

1. **Report bugs**: Describe the issue with details
2. **Suggest improvements**: Ideas are very welcome
3. **Send code**: Forks and pull requests are accepted
4. **Provide feedback**: Your opinion matters

### Ideas for Future Improvements

- Windows support (WSL)
- Graphical interface
- Automatic/scheduled synchronization
- Support for other image formats
- File compression
- File type exclusion
- File logging

## 📄 License

This code is **FREE** and can be:
- ✅ Copied
- ✅ Distributed
- ✅ Modified
- ✅ Used in personal or commercial projects

No attribution or prior permission needed.

## 📞 Support

If you have questions or difficulties:

1. Review this README completely
2. Check the script logs (displayed in the terminal)
3. Test with a small file first
4. Report issues with details

## 🎓 History and Purpose

This script was developed as a **hobby and testing project** to facilitate synchronization with Crosspoint devices. It is not professional production software, but a practical tool for personal use.

## 📋 Changelog

### v2.0 (Current - March 2026)
- ✅ **NEW**: 🌐 Web Interface for browser-based control
- ✅ **NEW**: 🖥️ Web server with Python (web-server.py)
- ✅ **NEW**: 💻 Command-line interface (CLI mode)
- ✅ **NEW**: 📈 Statistics dashboard with visual metrics
- ✅ **NEW**: 🔍 Advanced filters (operation, date, file search)
- ✅ **NEW**: 📝 Real-time log streaming in browser
- ✅ **NEW**: 🎯 Visual status indicators
- ✅ **NEW**: 💾 Cumulative history across executions
- ✅ **NEW**: 📋 Detailed tracking of all file operations
- ✅ Interactive menu
- ✅ Name normalization
- ✅ Remote backup
- ✅ File synchronization
- ✅ Image conversion
- ✅ Original file preservation
- ✅ Automatic dependency detection

### v1.0
- ✅ Interactive menu
- ✅ Name normalization
- ✅ Remote backup
- ✅ File synchronization
- ✅ Image conversion
- ✅ Original file preservation
- ✅ Automatic dependency detection

---

**Developed with ❤️ as a hobby project**

**Last update**: March 15, 2026

**Have fun syncing! 🚀**
