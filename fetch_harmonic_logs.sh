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
if [ -z "$BASE_DIR" ] || [ -z "$MEDIACHANNEL_IP" ] || [ -z "$MEDIACHANNEL_USER" ] || [ -z "$MEDIACHANNEL_PASS" ] || 
   [ -z "$MEDIACHANNEL_PATH" ] || [ -z "$MEDIADECK_IP" ] || [ -z "$MEDIADECK_USER" ] || [ -z "$MEDIADECK_PASS" ] || 
   [ -z "$MEDIADECK_PATH" ] || [ -z "$RETENTION_DAYS" ]; then
    echo "Error: Configuration file is incomplete. Please check all required variables are set."
    exit 1
fi

# Define variables
TIMESTAMP=$(date +"%Y_%m_%d")
LOG_DIR="$BASE_DIR/$TIMESTAMP"
ARCHIVE_NAME="harmonic_logs_$TIMESTAMP.tar.gz"

# Create directories for storing logs
mkdir -p "$LOG_DIR/mediachannel"
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
    
    # Try ncftp first - it can preserve timestamps with the -z flag
    if command -v ncftp &> /dev/null; then
        echo "Using ncftp with timestamp preservation..."
        local ncftp_script=$(mktemp)
        cat > "$ncftp_script" << EOF
open -u $user -p $pass $ip
cd $path
set auto-resume yes
# Turn on timestamp preservation
set preserve-date yes
# Get all log files
mget *.log
# Get any compressed logs
mget *.gz
# Get any text files
mget *.txt
quit
EOF
        # Execute the ncftp script
        cd "$output_dir" && ncftp -f "$ncftp_script" > /dev/null 2>&1
        local result=$?
        rm "$ncftp_script"
        
        if [ $result -eq 0 ]; then
            success=true
            echo "ncftp download completed successfully with preserved timestamps."
        else
            echo "ncftp download failed, trying alternative methods..."
        fi
    fi
    
    # If ncftp failed or isn't installed, try wget
    if [ "$success" = false ] && command -v wget &> /dev/null; then
        echo "Using wget with timestamp preservation..."
        cd "$output_dir" && wget -r -np -nH --cut-dirs=1 -N --user="$user" --password="$pass" "ftp://$ip$path/" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            success=true
            echo "wget download completed successfully with preserved timestamps."
        else
            echo "wget download failed, trying standard ftp..."
        fi
    fi
    
    # If wget failed or isn't installed, try standard ftp with timestamp list + touch
    if [ "$success" = false ]; then
        echo "Using standard ftp with manual timestamp preservation..."
        
        # First get a directory listing with timestamps
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
        
        # Create a download script
        local download_script=$(mktemp)
        cat > "$download_script" << EOF
open $ip
user $user $pass
binary
cd $path
prompt off
EOF

        # Extract filenames and timestamps
        local file_timestamps=$(mktemp)
        grep -v "^d" "$file_list" | grep -v "^total" | awk '{print $NF, $6, $7, $8}' > "$file_timestamps"
        
        # Add each file to the download script
        while read -r line; do
            filename=$(echo "$line" | awk '{print $1}')
            month=$(echo "$line" | awk '{print $2}')
            day=$(echo "$line" | awk '{print $3}')
            time=$(echo "$line" | awk '{print $4}')
            
            if [ -n "$filename" ] && [ "$filename" != "." ] && [ "$filename" != ".." ]; then
                echo "get \"$filename\" \"$output_dir/$filename\"" >> "$download_script"
                
                # Store timestamp info for later use with touch
                echo "$filename $month $day $time" >> "${output_dir}/file_timestamps.txt"
            fi
        done < "$file_timestamps"
        
        # Add final command
        echo "bye" >> "$download_script"
        
        # Execute the download
        ftp -n < "$download_script"
        rm "$download_script" "$file_list" "$file_timestamps"
        
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
    fi
    
    # Count the number of files downloaded
    local file_count=$(ls -1 "$output_dir" | wc -l)
    echo "Downloaded $file_count files from $server_name"
    
    if [ $file_count -eq 0 ]; then
        echo "WARNING: No files were downloaded from $server_name!"
    else
        echo "Successfully downloaded logs from $server_name with preserved timestamps"
    fi
}

# Fetch logs from both servers
fetch_all_logs "$MEDIACHANNEL_IP" "$MEDIACHANNEL_USER" "$MEDIACHANNEL_PASS" "$MEDIACHANNEL_PATH" "$LOG_DIR/mediachannel" "MediaChannel"
fetch_all_logs "$MEDIADECK_IP" "$MEDIADECK_USER" "$MEDIADECK_PASS" "$MEDIADECK_PATH" "$LOG_DIR/mediadeck" "MediaDeck"

# Create compressed archive
echo "Creating compressed archive at $BASE_DIR/$ARCHIVE_NAME"
tar -czf "$BASE_DIR/$ARCHIVE_NAME" -C "$(dirname "$LOG_DIR")" "$(basename "$LOG_DIR")"

echo "=========================================================="
echo "Log collection complete"
echo "Archive created: $BASE_DIR/$ARCHIVE_NAME"
echo "Log files stored in: $LOG_DIR"

# List the files that were downloaded
echo "Files downloaded from MediaChannel:"
ls -la "$LOG_DIR/mediachannel" | tail -n +4
echo "Files downloaded from MediaDeck:"
ls -la "$LOG_DIR/mediadeck" | tail -n +4

echo "=========================================================="

# Log rotation - keep only the last N days worth of logs
echo "Performing log rotation (keeping only the last $RETENTION_DAYS days)..."
find "$BASE_DIR" -type d -name "????_??_??" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null
find "$BASE_DIR" -name "harmonic_logs_????_??_??.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \; 2>/dev/null

exit 0
