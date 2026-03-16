#!/bin/bash

set -o pipefail

DEVICE="http://crosspoint.local"
REMOTE_PATH="/"
SLEEP_REMOTE_PATH="/sleep"
BACKUP_DIR="remote_backup"
FILES_DIR="files"
LOCAL_PATH="$(pwd)/$FILES_DIR"

# Statistics counters
STATS_FILES_DOWNLOADED=0
STATS_FILES_UPLOADED=0
STATS_FILES_CONVERTED=0
STATS_FILES_NORMALIZED=0
STATS_BYTES_DOWNLOADED=0
STATS_BYTES_UPLOADED=0
STATS_START_TIME=0

# Log with timestamp to console
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$timestamp - $1"
    echo "$message"
}

# Start statistics tracking
start_stats() {
    STATS_START_TIME=$(date +%s)
    STATS_FILES_DOWNLOADED=0
    STATS_FILES_UPLOADED=0
    STATS_FILES_CONVERTED=0
    STATS_FILES_NORMALIZED=0
    STATS_BYTES_DOWNLOADED=0
    STATS_BYTES_UPLOADED=0
}

# Show statistics at end of operation
show_stats() {
    local operation_name="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - STATS_START_TIME))
    
    log "════════════════════════════════════════════"
    log "📊 STATISTICS: $operation_name"
    log "════════════════════════════════════════════"
    log "⏱️  Duration: $(format_duration $duration)"
    
    if [ $STATS_FILES_DOWNLOADED -gt 0 ]; then
        log "📥 Files downloaded: $STATS_FILES_DOWNLOADED ($(format_size $STATS_BYTES_DOWNLOADED))"
    fi
    
    if [ $STATS_FILES_UPLOADED -gt 0 ]; then
        log "📤 Files uploaded: $STATS_FILES_UPLOADED ($(format_size $STATS_BYTES_UPLOADED))"
    fi
    
    if [ $STATS_FILES_CONVERTED -gt 0 ]; then
        log "🔄 Images converted: $STATS_FILES_CONVERTED"
    fi
    
    if [ $STATS_FILES_NORMALIZED -gt 0 ]; then
        log "✏️  Files normalized: $STATS_FILES_NORMALIZED"
    fi
    
    if [ $duration -gt 0 ]; then
        local total_mb=$(( (STATS_BYTES_DOWNLOADED + STATS_BYTES_UPLOADED) / 1048576 ))
        if [ $total_mb -gt 0 ]; then
            local speed=$((total_mb * 60 / duration))
            log "⚡ Average speed: ${speed}MB/min"
        fi
    fi
    
    log "════════════════════════════════════════════"
}

# Check if file should be ignored (script/documentation files)
should_ignore_file() {
    local filename="$1"
    
    # Ignore script files, documentation, web files
    [[ "$filename" == *.sh ]] && return 0
    [[ "$filename" == *.md ]] && return 0
    [[ "$filename" == *.html ]] && return 0
    [[ "$filename" == *.py ]] && return 0
    
    return 1
}

# ==========================
# CHECK DEPENDENCIES
# ==========================

check_dependencies() {
    local missing_deps=()
    local dependencies=("curl" "jq" "convert")
    
    # Check each dependency silently
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # If all dependencies are present, continue silently
    if [ ${#missing_deps[@]} -eq 0 ]; then
        return 0
    fi
    
    # Dependencies are missing, show messages and try to install
    echo "============================================"
    echo "Checking required dependencies..."
    echo "============================================"
    
    for dep in "${dependencies[@]}"; do
        if command -v "$dep" &> /dev/null; then
            echo "  ✓ $dep"
        else
            echo "  ✗ $dep (missing)"
        fi
    done
    
    echo ""
    echo "Missing dependencies: ${missing_deps[*]}"
    # Detect package manager and install
    if command -v apt-get &> /dev/null; then
        echo "Installing with apt-get..."
        sudo apt-get update && sudo apt-get install -y curl jq imagemagick
        
    elif command -v brew &> /dev/null; then
        echo "Installing with Homebrew..."
        brew install curl jq imagemagick
        
    elif command -v yum &> /dev/null; then
        echo "Installing with yum..."
        sudo yum install -y curl jq ImageMagick
        
    elif command -v pacman &> /dev/null; then
        echo "Installing with pacman..."
        sudo pacman -S curl jq imagemagick
        
    else
        echo ""
        echo "ERROR: Could not detect package manager"
        echo "Please install manually:"
        echo "  - curl"
        echo "  - jq"
        echo "  - ImageMagick (convert command)"
        exit 1
    fi
    # Verify installation
    echo "Verifying installation..."
    local still_missing=()
    
    for dep in "${missing_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            still_missing+=("$dep")
        else
            echo "  ✓ $dep installed successfully"
        fi
    done
    
    # If some dependencies still missing, exit
    if [ ${#still_missing[@]} -gt 0 ]; then
        echo ""
        echo "ERROR: Could not install: ${still_missing[*]}"
        echo "Please install them manually and try again"
        exit 1
    fi
    echo "All dependencies are now installed. Proceeding..."
}

# Test device connectivity
test_device_connectivity() {
    log "Testing connectivity to device: $DEVICE"
    
    if curl --silent --show-error --fail --max-time 5 \
        "$DEVICE/api/files?path=/" > /dev/null 2>&1; then
        log "✓ Device is reachable and responding"
        return 0
    else
        log "ERROR: Cannot reach device at $DEVICE"
        log "Please verify:"
        log "  - Device is powered on and on the Wi-Fi transfer screen"
        log "  - Device address is correct: $DEVICE"
        log "  - Network connectivity is working"
        return 1
    fi
}

# Helper to download remote file
remote_download() {
    local remote_path=$1
    local local_path=$2
    local current=${3:-}
    local total=${4:-}
    
    # Show progress if provided
    if [ -n "$current" ] && [ -n "$total" ]; then
        log "  → [$current/$total] Downloading: $(basename "$remote_path")"
    else
        log "  → Starting download: $remote_path"
    fi
    
    # Silent mode - no progress bar
    curl --silent --show-error --fail --max-time 120 \
        "$DEVICE/download?path=$remote_path" \
        -o "$local_path"
    
    local status=$?
    
    if [ $status -eq 0 ]; then
        local size=$(stat -f%z "$local_path" 2>/dev/null || stat -c%s "$local_path" 2>/dev/null || echo "0")
        STATS_FILES_DOWNLOADED=$((STATS_FILES_DOWNLOADED + 1))
        STATS_BYTES_DOWNLOADED=$((STATS_BYTES_DOWNLOADED + size))
        log "  ✓ Downloaded: $(basename "$local_path") [$(format_size $size)]"
        return 0
    else
        log "  ✗ Download failed: $remote_path"
        return 1
    fi
}

# Helper to upload file
remote_upload() {
    local local_file=$1
    local remote_path=$2
    local current=${3:-}
    local total=${4:-}
    
    # Show progress if provided
    if [ -n "$current" ] && [ -n "$total" ]; then
        local size=$(stat -f%z "$local_file" 2>/dev/null || stat -c%s "$local_file" 2>/dev/null || echo "0")
        log "  → [$current/$total] Uploading: $(basename "$local_file") [$(format_size $size)]"
    else
        log "  → Starting upload: $(basename "$local_file")"
    fi
    
    # Silent mode - no progress bar
    curl --silent --show-error --fail --max-time 120 -X POST \
        -F "file=@$local_file" \
        "$DEVICE/upload?path=$remote_path"
    
    local status=$?
    
    if [ $status -eq 0 ]; then
        local size=$(stat -f%z "$local_file" 2>/dev/null || stat -c%s "$local_file" 2>/dev/null || echo "0")
        STATS_FILES_UPLOADED=$((STATS_FILES_UPLOADED + 1))
        STATS_BYTES_UPLOADED=$((STATS_BYTES_UPLOADED + size))
        log "  ✓ Upload completed: $(basename "$local_file")"
        return 0
    else
        log "  ✗ Upload failed: $local_file"
        return 1
    fi
}

# Helper to delete remote file/folder
remote_delete() {
    local path=$1
    local type=${2:-file}
    
    curl --silent --show-error --fail --max-time 30 -X POST \
        -d "path=$path&type=$type" \
        "$DEVICE/delete" \
        >>/dev/null 2>&1
}

# Helper to create remote folder
remote_mkdir() {
    local name=$1
    local path=$2
    
    curl --silent --show-error --fail -X POST \
        -d "name=$name&path=$path" \
        "$DEVICE/mkdir" 2>&1
}

# Helper to list remote files
remote_list_files() {
    local path=$1
    
    curl --silent --show-error --fail --max-time 15 \
        "$DEVICE/api/files?path=$path" 2>/dev/null | \
        jq -r '.[] | select(.isDirectory==false) | .name' 2>/dev/null
}

# Helper to rename remote file
remote_rename() {
    local old_path=$1
    local new_name=$2
    
    log "  [RENAME] Starting rename: path=$old_path | new_name=$new_name"
    
    local response=$(curl --silent --show-error --fail -X POST \
        -F "path=$old_path" \
        -F "name=$new_name" \
        "$DEVICE/rename" 2>&1)
    
    local status=$?
    
    if [ $status -eq 0 ]; then
        log "  [RENAME] Success: $old_path -> $new_name"
        return 0
    else
        log "  [RENAME] ERROR (status=$status): $old_path -> $new_name"
        log "  [RENAME] Response: $response"
        return 1
    fi
}

# ==========================
# UTILITY FUNCTIONS
# ==========================

# Check available disk space (in MB)
check_disk_space() {
    local path="$1"
    local required_mb="${2:-100}"  # Default: 100MB
    
    local available_mb=$(df -m "$path" | awk 'NR==2 {print $4}')
    
    if [ "$available_mb" -lt "$required_mb" ]; then
        log "⚠️  WARNING: Low disk space!"
        log "   Available: ${available_mb}MB | Required: ${required_mb}MB"
        return 1
    fi
    return 0
}

# Format duration in seconds to human readable
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# Format file size to human readable
format_size() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    else
        echo "$((bytes / 1048576))MB"
    fi
}

# ==========================
# BACKUP LOCAL ORIGINALS
# ==========================

backup_local_originals() {
    log "════════════════════════════════════════════"
    log "BACKING UP ORIGINAL FILES"
    log "════════════════════════════════════════════"
    
    # Ensure originals folder exists
    if [ ! -d "originals" ]; then
        mkdir originals
        log "Created local folder: originals"
    fi
    
    local files_backed_up=0
    
    # Backup image files in root
    for img in *; do
        [ -f "$img" ] || continue  # Only process files, skip directories
        [ "$img" != "$(basename "$0")" ] || continue  # Skip the script itself
        
        # Ignore script and documentation files
        should_ignore_file "$img" && continue
        
        if [ ! -e "originals/$img" ]; then
            cp "$img" "originals/" && log "Backed up: $img -> originals/"
            ((files_backed_up++))
        fi
    done
    
    # Backup image files in sleep folder (if exists)
    if [ -d "sleep" ]; then
        mkdir -p originals/sleep
        # Copy all files from sleep folder
        if cp sleep/* originals/sleep/ 2>/dev/null; then
            for item in sleep/*; do
                if [ -e "$item" ]; then
                    log "Backed up: $(basename "$item") -> originals/sleep/"
                    ((files_backed_up++))
                fi
            done
        fi
    fi
    
    if [ $files_backed_up -eq 0 ]; then
        log "No new files to backup (originals already exist or no image files found)"
    else
        log "✓ Backed up $files_backed_up file(s) to originals/"
    fi
}

# ==========================
# INTERACTIVE MENU
# ==========================

show_menu() {
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║        CROSSPOINT SYNC - SELECT OPERATION              ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "1) Normalize file names (local and remote)"
    echo "2) Full remote backup"
    echo "3) Sync files"
    echo "4) Run ALL (normalize + backup + sync)"
    echo "5) Exit"
    echo ""
    echo "────────────────────────────────────────────────────────"
    read -p "Choose an option (1-5): " choice
    # Validate input
    if ! [[ "$choice" =~ ^[1-5]$ ]]; then
        echo "ERROR: Invalid option. Please choose 1-5"
        show_menu
    fi
}

# Confirm destructive operations
confirm_operation() {
    local message=$1
    read -p "⚠️  $message Continue? (yes/no) [default: yes]: " confirm
    # If user presses Enter (empty), treat as "yes"
    confirm=${confirm:-yes}
    # If user types "no" or "n", cancel; otherwise continue
    if [[ "$confirm" == "no" || "$confirm" == "n" ]]; then
        log "Operation cancelled by user"
        return 1
    fi
    return 0
}

normalize_operation() {
    start_stats
    log "════════════════════════════════════════════"
    log "OPERATION: Normalize file names"
    log "════════════════════════════════════════════"
    
    # Normalize local files
    log "Normalizing file names (replacing spaces with underscore, removing special characters)"

    for file in *; do
        [ -f "$file" ] || continue
        
        # Ignore script and documentation files
        should_ignore_file "$file" && continue

        # Check if file needs normalization (spaces, dashes, colons, slashes, etc.)
        if [[ "$file" == *" "* ]] || [[ "$file" == *"-"* ]] || [[ "$file" == *"—"* ]] || [[ "$file" == *":"* ]] || [[ "$file" == *"/"* ]] || [[ "$file" == *"\\"* ]] || [[ "$file" == *"__"* ]]; then
            NEW_NAME="$file"
            # Replace spaces with underscore
            NEW_NAME="${NEW_NAME// /_}"
            # Remove regular dash
            NEW_NAME="${NEW_NAME//-/}"
            # Remove em-dash
            NEW_NAME="${NEW_NAME//—/}"
            # Remove colons
            NEW_NAME="${NEW_NAME//:/}"
            # Remove forward slashes
            NEW_NAME="${NEW_NAME//\//}"
            # Remove backslashes
            NEW_NAME="${NEW_NAME//\\/}"
            # Remove double underscores (repeat until no more doubles)
            while [[ "$NEW_NAME" == *"__"* ]]; do
                NEW_NAME="${NEW_NAME//__/_}"
            done

            if [ ! -e "$NEW_NAME" ] && [ "$file" != "$NEW_NAME" ]; then
                mv "$file" "$NEW_NAME"
                STATS_FILES_NORMALIZED=$((STATS_FILES_NORMALIZED + 1))
                log "Renamed locally: '$file' -> '$NEW_NAME'"
            else
                log "Skipping rename (target exists or no change needed): $NEW_NAME"
            fi
        fi
    done

    # Normalize remote files
    log "Normalizing remote file names (replacing spaces with underscore, removing special characters)"

    REMOTE_ROOT_FILES=$(remote_list_files "/")
    if [ -z "$REMOTE_ROOT_FILES" ]; then
        log "  No files found in remote root to rename"
    else
        log "  Found $(echo "$REMOTE_ROOT_FILES" | wc -l) file(s) in remote root"
        echo "$REMOTE_ROOT_FILES" | while IFS= read -r remote_file; do
            [ -z "$remote_file" ] && continue
            
            # Ignore script and documentation files
            should_ignore_file "$remote_file" && continue
            
            # Check if file needs normalization
            if [[ "$remote_file" == *" "* ]] || [[ "$remote_file" == *"-"* ]] || [[ "$remote_file" == *"—"* ]] || [[ "$remote_file" == *":"* ]] || [[ "$remote_file" == *"/"* ]] || [[ "$remote_file" == *"\\"* ]] || [[ "$remote_file" == *"__"* ]]; then
                NEW_NAME="$remote_file"
                # Replace spaces with underscore
                NEW_NAME="${NEW_NAME// /_}"
                # Remove regular dash
                NEW_NAME="${NEW_NAME//-/}"
                # Remove em-dash
                NEW_NAME="${NEW_NAME//—/}"
                # Remove colons
                NEW_NAME="${NEW_NAME//:/}"
                # Remove forward slashes
                NEW_NAME="${NEW_NAME//\//}"
                # Remove backslashes
                NEW_NAME="${NEW_NAME//\\/}"
                # Remove double underscores (repeat until no more doubles)
                while [[ "$NEW_NAME" == *"__"* ]]; do
                    NEW_NAME="${NEW_NAME//__/_}"
                done
                
                if [ "$remote_file" != "$NEW_NAME" ]; then
                    remote_rename "/$remote_file" "$NEW_NAME"
                fi
            fi
        done
    fi

    # Normalize remote /sleep (if exists)
    REMOTE_SLEEP_FILES=$(remote_list_files "$SLEEP_REMOTE_PATH")
    if [ -n "$REMOTE_SLEEP_FILES" ]; then
        log "  Found $(echo "$REMOTE_SLEEP_FILES" | wc -l) file(s) in remote /sleep"
        echo "$REMOTE_SLEEP_FILES" | while IFS= read -r remote_file; do
            [ -z "$remote_file" ] && continue
            
            # Ignore script and documentation files
            should_ignore_file "$remote_file" && continue
            
            # Check if file needs normalization
            if [[ "$remote_file" == *" "* ]] || [[ "$remote_file" == *"-"* ]] || [[ "$remote_file" == *"—"* ]] || [[ "$remote_file" == *":"* ]] || [[ "$remote_file" == *"/"* ]] || [[ "$remote_file" == *"\\"* ]] || [[ "$remote_file" == *"__"* ]]; then
                NEW_NAME="$remote_file"
                # Replace spaces with underscore
                NEW_NAME="${NEW_NAME// /_}"
                # Remove regular dash
                NEW_NAME="${NEW_NAME//-/}"
                # Remove em-dash
                NEW_NAME="${NEW_NAME//—/}"
                # Remove colons
                NEW_NAME="${NEW_NAME//:/}"
                # Remove forward slashes
                NEW_NAME="${NEW_NAME//\//}"
                # Remove backslashes
                NEW_NAME="${NEW_NAME//\\/}"
                # Remove double underscores (repeat until no more doubles)
                while [[ "$NEW_NAME" == *"__"* ]]; do
                    NEW_NAME="${NEW_NAME//__/_}"
                done
                
                if [ "$remote_file" != "$NEW_NAME" ]; then
                    log "Attempting to rename in /sleep: '$remote_file' -> '$NEW_NAME'"
                    remote_rename "$SLEEP_REMOTE_PATH/$remote_file" "$NEW_NAME"
                fi
            fi
        done
    else
        log "  Remote /sleep is empty or does not exist"
    fi
    
    log "✓ Normalization completed"
    show_stats "Normalization"
}

backup_operation() {
    start_stats
    log "════════════════════════════════════════════"
    log "OPERATION: Full remote backup"
    log "════════════════════════════════════════════"
    
    # Check disk space (require at least 500MB for backup)
    if ! check_disk_space "." 500; then
        log "ERROR: Insufficient disk space for backup operation"
        log "TIP: Free up some space and try again"
        return 1
    fi
    
    # Test device connectivity before starting
    log "Testing device connectivity..."
    if ! test_device_connectivity; then
        log "ERROR: Cannot reach device. Backup operation aborted."
        return 1
    fi
    
    # Confirm if backup folder already exists
    if [ -d "$BACKUP_DIR" ]; then
        if ! confirm_operation "Backup folder '$BACKUP_DIR' already exists. It will be replaced."; then
            return 1
        fi
    fi
    
    # Reset local backup
    log "Resetting local backup folder"

    if [ -d "$BACKUP_DIR" ]; then
        rm -rf "$BACKUP_DIR" || { log "ERROR: Failed to delete $BACKUP_DIR"; return 1; }
        log "Local folder $BACKUP_DIR deleted"
    fi

    mkdir -p "$BACKUP_DIR" || { log "ERROR: Failed to create $BACKUP_DIR"; return 1; }
    log "Local folder $BACKUP_DIR created"

    # Remote backup
    log "Starting remote backup process"

    mkdir -p "$BACKUP_DIR"

    log "Fetching remote root file list for backup..."

    REMOTE_ALL_FILES=$(remote_list_files "/")
    if [ -z "$REMOTE_ALL_FILES" ]; then
        log "WARNING: No files found in remote root"
    fi

    # Download files from root
    local total_root=$(echo "$REMOTE_ALL_FILES" | grep -v '^$' | wc -l)
    local current_root=0
    
    echo "$REMOTE_ALL_FILES" | while IFS= read -r REMOTE_FILE; do
        [ -z "$REMOTE_FILE" ] && continue
        
        # Ignore script and documentation files
        should_ignore_file "$REMOTE_FILE" && continue
        
        current_root=$((current_root + 1))
        log "📥 Downloading from root: $REMOTE_FILE"

        if remote_download "/$REMOTE_FILE" "$BACKUP_DIR/$REMOTE_FILE" "$current_root" "$total_root"; then
            : # Success message already logged in remote_download
        else
            log "ERROR: Backup failed: $REMOTE_FILE"
        fi
    done

    # Backup /sleep folder (if exists)
    log "Checking remote /sleep folder for backup"

    REMOTE_SLEEP_FILES=$(remote_list_files "$SLEEP_REMOTE_PATH")

    if [ -n "$REMOTE_SLEEP_FILES" ]; then
        mkdir -p "$BACKUP_DIR/sleep" || { log "ERROR: Failed to create $BACKUP_DIR/sleep"; }
        
        local total_sleep=$(echo "$REMOTE_SLEEP_FILES" | grep -v '^$' | wc -l)
        log "  Found $total_sleep file(s) in remote /sleep - downloading in random order"
        
        local current_sleep=0
        echo "$REMOTE_SLEEP_FILES" | shuf | while IFS= read -r REMOTE_FILE; do
            [ -z "$REMOTE_FILE" ] && continue
            
            # Ignore script and documentation files
            should_ignore_file "$REMOTE_FILE" && continue
            
            current_sleep=$((current_sleep + 1))
            log "📥 Downloading from /sleep: $REMOTE_FILE"

            if remote_download "$SLEEP_REMOTE_PATH/$REMOTE_FILE" "$BACKUP_DIR/sleep/$REMOTE_FILE" "$current_sleep" "$total_sleep"; then
                : # Success message already logged in remote_download
            else
                log "ERROR: Backup failed: /sleep/$REMOTE_FILE"
            fi
        done
    else
        log "Remote /sleep folder is empty or doesn't exist"
    fi

    log "Remote backup completed"
    log "✓ Backup completed"
    show_stats "Backup"
}

sync_operation() {
    start_stats
    log "════════════════════════════════════════════"
    log "OPERATION: File synchronization"
    log "════════════════════════════════════════════"
    
    # Check disk space (require at least 100MB for temp files)
    if ! check_disk_space "." 100; then
        log "WARNING: Low disk space detected"
        log "TIP: Synchronization may fail if files are large"
    fi
    
    log "Starting synchronization"

    # Ensure processed folder exists
    if [ ! -d "processed" ]; then
        mkdir processed
        log "Created local folder: processed"
    fi

    # Get remote root file list
    log "Fetching remote root file list..."
    REMOTE_FILES=$(remote_list_files "$REMOTE_PATH")

    # Convert non-BMP images in root
    for img in *.jpg *.jpeg *.png *.gif; do
        [ -e "$img" ] || continue
        NEW_NAME="${img%.*}.bmp"

        log "Converting image to BMP: $img -> $NEW_NAME"

        if convert "$img" "$NEW_NAME" >>/dev/null 2>&1; then
            rm -f "$img"
            STATS_FILES_CONVERTED=$((STATS_FILES_CONVERTED + 1))
            log "Conversion successful: $NEW_NAME"
        else
            log "ERROR: Conversion failed: $img"
        fi
    done

    # Handle BMP files in root
    BMP_FILES=( *.bmp )
    BMP_COUNT=0
    for f in "${BMP_FILES[@]}"; do
        [ -e "$f" ] && ((BMP_COUNT++))
    done

    if [ "$BMP_COUNT" -eq 1 ]; then
        FILE="${BMP_FILES[0]}"
        if [ "$FILE" != "sleep.bmp" ]; then
            log "Renaming $FILE -> sleep.bmp"
            mv "$FILE" sleep.bmp || { log "ERROR: Failed to rename $FILE"; }
            FILE="sleep.bmp"
        fi

        if echo "$REMOTE_FILES" | grep -qx "sleep.bmp"; then
            log "sleep.bmp already exists remotely - moving locally to processed"
            mv "$FILE" processed/ || { log "ERROR: Failed to move $FILE"; }
        else
            log "Removing remote sleep.bmp (if exists)"
            remote_delete "/sleep.bmp" "file"

            log "Uploading sleep.bmp to root"
            if remote_upload "$FILE" "/"; then
                log "Upload successful: sleep.bmp"
                mv "$FILE" processed/ || { log "ERROR: Failed to move $FILE"; }
            else
                log "ERROR: Upload failed: sleep.bmp"
            fi
        fi
    elif [ "$BMP_COUNT" -gt 1 ]; then
        log "Multiple BMP files detected"

        log "Fetching remote /sleep file list..."
        REMOTE_SLEEP_FILES=$(remote_list_files "$SLEEP_REMOTE_PATH")

        log "Creating remote folder: sleep (if not exists)"
        RESPONSE=$(remote_mkdir "sleep" "/")

        if echo "$RESPONSE" | grep -q "Folder already exists"; then
            log "Remote folder /sleep already exists"
        else
            log "Remote folder /sleep created"
        fi

        log "Removing root sleep.bmp (if exists)"
        remote_delete "/sleep.bmp" "file"

        for FILE in "${BMP_FILES[@]}"; do
            [ -e "$FILE" ] || continue
            if echo "$REMOTE_SLEEP_FILES" | grep -qx "$FILE"; then
                log "$FILE already exists in /sleep remotely - moving locally to processed"
                mv "$FILE" processed/ || { log "ERROR: Failed to move $FILE"; }
            else
                log "Uploading $FILE to /sleep"
                if remote_upload "$FILE" "$SLEEP_REMOTE_PATH"; then
                    log "Upload successful: $FILE"
                    mv "$FILE" processed/ || { log "ERROR: Failed to move $FILE"; }
                else
                    log "ERROR: Upload failed: $FILE"
                fi
            fi
        done
    fi

    # Handle other files in root
    for file in *; do
        # Skip directories completely - only process regular files
        [ ! -d "$file" ] || continue
        [ -f "$file" ] || continue
        [[ "$file" == *.log ]] && continue
        [[ "$file" == *.bmp ]] && continue
        [[ "$file" == "$(basename "$0")" ]] && continue
        
        # Ignore script and documentation files
        should_ignore_file "$file" && continue

        if echo "$REMOTE_FILES" | grep -qx "$file"; then
            log "$file already exists remotely - moving locally to processed"
            mv "$file" processed/ || { log "ERROR: Failed to move $file"; }
        else
            log "Uploading: $file"
            if remote_upload "$file" "$REMOTE_PATH"; then
                log "Upload successful: $file"
                mv "$file" processed/ || { log "ERROR: Failed to move $file"; }
            else
                log "ERROR: Upload failed: $file"
            fi
        fi
    done

    # Process local sleep folder (if exists)
    if [ -d "sleep" ]; then
        log "Processing local folder 'sleep'"

        cd "sleep" || { log "ERROR: Failed to access sleep folder"; return 1; }

        # Convert non-BMP images
        for img in *.jpg *.jpeg *.png *.gif; do
            [ -e "$img" ] || continue
            NEW_NAME="${img%.*}.bmp"
            log "Converting image to BMP: $img -> $NEW_NAME"
            if convert "$img" "$NEW_NAME" >>/dev/null 2>&1; then
                rm -f "$img"
                STATS_FILES_CONVERTED=$((STATS_FILES_CONVERTED + 1))
                log "Conversion successful: $NEW_NAME"
            else
                log "ERROR: Conversion failed: $img"
            fi
        done

        # Handle BMP files
        BMP_FILES=( *.bmp )
        for FILE in "${BMP_FILES[@]}"; do
            [ -e "$FILE" ] || continue
            log "Uploading $FILE to /sleep"
            if remote_upload "$FILE" "$SLEEP_REMOTE_PATH"; then
                log "Upload successful: $FILE"
                mkdir -p ../processed/sleep || { log "WARNING: Failed to create processed/sleep"; }
                mv "$FILE" ../processed/sleep/ || { log "ERROR: Failed to move $FILE"; }
            else
                log "ERROR: Upload failed: $FILE"
            fi
        done

        cd "$LOCAL_PATH" || { log "ERROR: Failed to return to local directory"; return 1; }
    fi

    # Clean processed folder
    if [ -d "processed" ]; then
        if [ -z "$(ls -A processed)" ]; then
            rmdir processed
            log "Processed folder empty - deleted"
        else
            log "Processed folder not empty - kept"
        fi
    fi
    
    log "Synchronization completed"
    
    # Clean up directory after sync
    cleanup_after_sync
    
    log "✓ Sync completed"
    show_stats "Synchronization"
}

# ==========================
# CLEANUP AFTER SYNC
# ==========================

cleanup_after_sync() {
    log "Cleaning up working directory..."
    
    local script_name="$(basename "$0")"
    
    # Remove all items except script, remote_backup, and originals
    for item in *; do
        [ -e "$item" ] || continue
        
        # Skip if it's the script itself, remote_backup, or originals
        if [ "$item" = "$script_name" ] || [ "$item" = "remote_backup" ] || [ "$item" = "originals" ]; then
            continue
        fi
        
        # Remove everything else (files and directories)
        if [ -d "$item" ]; then
            # Remove directory and all contents (including empty sleep folder)
            rm -rf "$item" && log "  Removed folder: $item"
        else
            # Remove file
            rm -f "$item" && log "  Removed file: $item"
        fi
    done
    
    # Double-check and remove any remaining empty sleep folder
    if [ -d "sleep" ] && [ -z "$(ls -A sleep 2>/dev/null)" ]; then
        rmdir sleep && log "  Removed empty folder: sleep"
    fi
    
    log "✓ Cleanup completed"
}

# ==========================
# MAIN ENTRY POINT
# ==========================

# Parse command line arguments
CLI_MODE=false
CLI_OPERATION=""

if [ $# -gt 0 ]; then
    CLI_MODE=true
    case "$1" in
        normalize|1)
            CLI_OPERATION="1"
            ;;
        backup|2)
            CLI_OPERATION="2"
            ;;
        sync|3)
            CLI_OPERATION="3"
            ;;
        all|4)
            CLI_OPERATION="4"
            ;;
        *)
            echo "Usage: $0 [normalize|backup|sync|all]"
            echo "  normalize - Normalize file names (option 1)"
            echo "  backup    - Full remote backup (option 2)"
            echo "  sync      - File synchronization (option 3)"
            echo "  all       - Run all operations (option 4)"
            echo ""
            echo "Run without arguments for interactive menu"
            exit 1
            ;;
    esac
fi

log "Starting Crosspoint Sync..."
check_dependencies

# Create and change to files directory
SCRIPT_DIR="$(pwd)"
if [ ! -d "$FILES_DIR" ]; then
    mkdir "$FILES_DIR" && log "Created working directory: $FILES_DIR/"
fi
cd "$FILES_DIR" || { log "ERROR: Failed to access $FILES_DIR directory"; exit 1; }
log "Working directory: $FILES_DIR/"

# Test connectivity before showing menu
if ! test_device_connectivity; then
    log "Aborting: Cannot communicate with device"
    cd "$SCRIPT_DIR"
    exit 1
fi

# Interactive mode or CLI mode
if [ "$CLI_MODE" = true ]; then
    choice="$CLI_OPERATION"
    log "Running in CLI mode: Operation $choice"
else
    show_menu
fi

# Backup local originals before any operation (except exit)
if [ "$choice" != "5" ]; then
    backup_local_originals
fi

case $choice in
    1)
        normalize_operation
        ;;
    2)
        backup_operation
        ;;
    3)
        sync_operation
        ;;
    4)
        normalize_operation
        backup_operation
        sync_operation
        ;;
    5)
        log "Exiting..."
        cd "$SCRIPT_DIR"
        exit 0
        ;;
    *)
        echo "Invalid option."
        cd "$SCRIPT_DIR"
        exit 1
        ;;
esac

log "✓ Execution completed. Script finalized."
cd "$SCRIPT_DIR"
exit 0