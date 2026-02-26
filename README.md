# Crosspoint Sync

A Bash script for synchronizing files with Crosspoint devices, with support for file name normalization, automatic backup, and image conversion.

## 📋 What the Script Does

**Crosspoint Sync** is a synchronization tool that offers:

- **Name Normalization**: Removes spaces from file names (local and remote)
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
```

### 3. (Optional) Check Dependencies

```bash
./crosspoint-sync.sh
```

The script will automatically detect missing dependencies and offer to install them.

## 🎯 Usage Guide

### Basic Execution

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

Renames files by removing spaces (replacing with underscore):

- **Local**: `My File.jpg` → `My_File.jpg`
- **Remote**: Syncs names on the device

Useful to ensure compatibility with systems that don't support spaces in file names.

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
- Files from root are uploaded to `/` on the device
- Files from `sleep/` folder are uploaded to `/sleep` on the device
- Images are converted to BMP (format expected by Crosspoint)
- Does not delete any files, only moves them to the `processed/` folder

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
remote_backup/                  # Backup of remote files
├── file1.bmp
├── file2.bmp
└── sleep/                      # Backup of remote /sleep folder
    ├── image1.bmp
    └── image2.bmp
originals/                      # Original files before conversion
├── original_file.jpg
├── original_file.png
└── sleep/                      # Originals from sleep folder
    ├── image.jpg
    └── image.png
processed/                      # Files already processed and uploaded
├── file1.bmp
├── file2.bmp
└── sleep/
    ├── image1.bmp
    └── image2.bmp
```

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
./crosspoint-sync.sh
# Place your files in the folder
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

### v1.0 (Current)
- ✅ Interactive menu
- ✅ Name normalization
- ✅ Remote backup
- ✅ File synchronization
- ✅ Image conversion
- ✅ Original file preservation
- ✅ Automatic dependency detection

---

**Developed with ❤️ as a hobby project**

**Last update**: February 26, 2026

**Have fun syncing! 🚀**
