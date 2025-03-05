#!/bin/bash

# Script to fetch all logs from Harmonic video playout servers
# Created: March 04, 2025
# Purpose: Automatically retrieve all log files each night and maintain a history

# Default config file location
CONFIG_FILE="/home/kburki/KTOO/Harmonic/config.cfg"

# Function to display usage information
usage() {
    echo "Usage: $0 [-c config_file]"
    echo "  -c config_file    Path to configuration file (default: $CONFIG_FILE)"
    echo "  -h                Display this help message"
    exit 1
}

# Parse command line arguments
while getopts "c:h" opt; do
    case $opt in
        c) CONFIG_FILE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please create a config file using the example template."
    exit 1
fi

# Load configuration
echo "Loading configuration from $CONFIG_FILE"
source "$CONFIG_FILE"

# Validate required configuration variables
if [ -z "$BASE_DIR" ] || [ -z "$MEDIACENTER_IP" ] || [ -z "$MEDIACENTER_USER" ] || [ -z "$MEDIACENTER_PASS" ] || 
   [ -z "$MEDIACENTER_PATH" ] || [ -z "$MEDIADECK_IP" ] || [ -z "$MEDIADECK_USER" ] || [ -z "$MEDIADECK_PASS" ] || 
   [ -z "$MEDIADECK_PATH" ] || [ -z "$RETENTION_DAYS" ]; then
    echo "Error: Configuration file is incomplete. Please check all required variables are set."
    exit 1
fi

# Define variables
TIMESTAMP=$(date +"%Y_%m_%d")
LOG_DIR="$BASE_DIR/$TIMESTAMP"
ARCHIVE_NAME="harmonic_logs_$TIMESTAMP.tar.gz"

# Create directories for storing logs
mkdir -p "$LOG_DIR/mediacenter"
mkdir -p "$LOG_DIR/mediadeck"

echo "=========================================================="
echo "Harmonic Server Log Fetcher"
echo "Fetching all logs from both servers"
echo "Current timestamp: $(date)"
echo "=========================================================="

# Function to fetch all logs from a server
fetch_all_logs() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local path="$4"
    local output_dir="$5"
    local server_name="$6"

    echo "Connecting to $server_name ($ip)..."
    
    local success=false
    
    # First get a directory listing to know what files to download
    echo "Getting file listing from $server_name..."
    local ftp_ls_cmd=$(mktemp)
    cat > "$ftp_ls_cmd" << EOF
open $ip
user $user $pass
cd $path
ls -la
bye
EOF

    # Get directory listing with timestamps
    local file_list=$(mktemp)
    ftp -n < "$ftp_ls_cmd" > "$file_list" 2>/dev/null
    rm "$ftp_ls_cmd"
    
    # Extract filenames and timestamps
    local file_timestamps=$(mktemp)
    grep "\.log\|\.gz\|\.txt" "$file_list" | grep -v "^d" | grep -v "^total" | awk '{print $NF, $6, $7, $8}' > "$file_timestamps"
    
    # Count how many files we need to download
    local total_files=$(wc -l < "$file_timestamps")
    echo "Found $total_files log files to download from $server_name"
    
    # Try standard ftp with timestamp preservation and progress display
    echo "Using standard FTP with manual timestamp preservation..."
    
    # Create a download script
    local download_script=$(mktemp)
    cat > "$download_script" << EOF
open $ip
user $user $pass
binary
cd $path
prompt off
EOF

    # Add each file to the download script and prepare timestamp restoration
    local count=0
    echo > "${output_dir}/file_timestamps.txt"
    
    while read -r line; do
        filename=$(echo "$line" | awk '{print $1}')
        month=$(echo "$line" | awk '{print $2}')
        day=$(echo "$line" | awk '{print $3}')
        time=$(echo "$line" | awk '{print $4}')
        
        if [ -n "$filename" ] && [ "$filename" != "." ] && [ "$filename" != ".." ]; then
            echo "get \"$filename\" \"$output_dir/$filename\"" >> "$download_script"
            echo "$filename $month $day $time" >> "${output_dir}/file_timestamps.txt"
            
            # Increment counter
            count=$((count + 1))
            
            # Show progress
            echo -ne "Preparing to download: $count of $total_files files\r"
        fi
    done < "$file_timestamps"
    echo ""
    
    # Add final command
    echo "bye" >> "$download_script"
    
    # Execute the download
    echo "Starting download of $total_files files from $server_name..."
    echo "This may take a while for large log files. Progress will be shown for each file."
    
    ftp -n < "$download_script"
    local result=$?
    rm "$download_script" "$file_list" "$file_timestamps"
    
    if [ $result -eq 0 ]; then
        # Now restore timestamps using touch
        if [ -f "${output_dir}/file_timestamps.txt" ]; then
            echo "Restoring original timestamps..."
            current_year=$(date +"%Y")
            while read -r line; do
                filename=$(echo "$line" | awk '{print $1}')
                month=$(echo "$line" | awk '{print $2}')
                day=$(echo "$line" | awk '{print $3}')
                time=$(echo "$line" | awk '{print $4}')
                
                # Format date for touch command
                touch_date="${current_year}${month}${day}${time}"
                
                # Restore timestamp
                if [ -f "${output_dir}/$filename" ]; then
                    touch -t "$touch_date" "${output_dir}/$filename"
                fi
            done < "${output_dir}/file_timestamps.txt"
            
            # Remove the temporary timestamp file
            rm "${output_dir}/file_timestamps.txt"
            success=true
        fi
    else
        echo "Standard FTP failed, trying wget as fallback..."
        
        # If standard FTP failed, try wget as a fallback
        if command -v wget &> /dev/null; then
            echo "Using wget with timestamp preservation (verbose mode)..."
            
            # Make wget more verbose to show progress
            cd "$output_dir" && wget -v -r -np -nH --cut-dirs=3 -N --user="$user" --password="$pass" "ftp://$ip$path/" 2>&1 | grep --line-buffered -E 'URL|saved'
            
            if [ $? -eq 0 ]; then
                success=true
                echo "wget download completed successfully with preserved timestamps."
            else
                echo "wget download failed."
            fi
        fi
    fi
    
    # Count the number of files downloaded
    local file_count=$(ls -1 "$output_dir" | wc -l)
    echo "Downloaded $file_count files from $server_name"
    
    if [ $file_count -eq 0 ]; then
        echo "WARNING: No files were downloaded from $server_name!"
    else
        echo "Successfully downloaded logs from $server_name with preserved timestamps"
    fi
    
    # Check for any nested directories that were created and move files up
    echo "Checking for nested directories..."
    if ls -la "$output_dir"/*/ >/dev/null 2>&1; then
        echo "Found nested directories, moving files up..."
        find "$output_dir" -mindepth 2 -type f -exec mv {} "$output_dir"/ \;
        find "$output_dir" -mindepth 1 -type d -exec rm -rf {} \;
    fi
}

# Fetch logs from both servers
fetch_all_logs "$MEDIACENTER_IP" "$MEDIACENTER_USER" "$MEDIACENTER_PASS" "$MEDIACENTER_PATH" "$LOG_DIR/mediacenter" "MediaCenter"
fetch_all_logs "$MEDIADECK_IP" "$MEDIADECK_USER" "$MEDIADECK_PASS" "$MEDIADECK_PATH" "$LOG_DIR/mediadeck" "MediaDeck"

# Create compressed archive
echo "Creating compressed archive at $BASE_DIR/$ARCHIVE_NAME"
tar -czf "$BASE_DIR/$ARCHIVE_NAME" -C "$(dirname "$LOG_DIR")" "$(basename "$LOG_DIR")"

echo "=========================================================="
echo "Log collection complete"
echo "Archive created: $BASE_DIR/$ARCHIVE_NAME"
echo "Log files stored in: $LOG_DIR"

# List the files that were downloaded
echo "Files downloaded from MediaCenter:"
ls -la "$LOG_DIR/mediacenter" | grep -v "directory_listing" | tail -n +4
echo "Files downloaded from MediaDeck:"
ls -la "$LOG_DIR/mediadeck" | grep -v "directory_listing" | tail -n +4

echo "=========================================================="

# Log rotation - keep only the last N days worth of logs
echo "Performing log rotation (keeping only the last $RETENTION_DAYS days)..."
find "$BASE_DIR" -type d -name "????_??_??" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null
find "$BASE_DIR" -name "harmonic_logs_????_??_??.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \; 2>/dev/null

exit 0