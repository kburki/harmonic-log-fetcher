#!/bin/bash

# Script to fetch all logs from Harmonic video playout servers
# Created: March 04, 2025
# Purpose: Automatically retrieve all log files each night and maintain a history

# crontab -l or -e Every hour: get recent files only (7-10 most recent)
# 0 * * * * /home/kburki/KTOO/Harmonic/fetch_harmonic_logs.sh -r -n 10 > /home/kburki/KTOO/Harmonic/logs/cron_log_$(date +\%Y\%m\%d_\%H)_recent.log 2>&1

# Every 3 hours: full collection 
# 0 */3 * * * /home/kburki/KTOO/Harmonic/fetch_harmonic_logs.sh > /home/kburki/KTOO/Harmonic/logs/cron_log_$(date +\%Y\%m\%d_\%H)_full.log 2>&1

# Default config file location
CONFIG_FILE="/home/kburki/KTOO/Harmonic/config.cfg"
TEST_MODE=false
NUM_FILES=1  # Default to just 1 file in test mode

# Function to display usage information
usage() {
    echo "Usage: $0 [-c config_file] [-t] [-r] [-n num_files]"
    echo "  -c config_file    Path to configuration file (default: $CONFIG_FILE)"
    echo "  -t                Test mode: download only recent files from each server"
    echo "  -r                Recent mode: download only recent files (for frequent runs)"
    echo "  -n num_files      Number of recent files to download in test or recent mode (default: 1)"
    echo "  -h                Display this help message"
    exit 1
}

# Parse command line arguments
# Default values
RECENT_MODE=false

# Parse command line arguments
while getopts "c:trn:h" opt; do
    case $opt in
        c) CONFIG_FILE="$OPTARG" ;;
        t) TEST_MODE=true ;;
        r) RECENT_MODE=true ;;
        n) NUM_FILES="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate NUM_FILES is a positive integer
if ! [[ "$NUM_FILES" =~ ^[0-9]+$ ]] || [ "$NUM_FILES" -lt 1 ]; then
    echo "Error: Number of files (-n) must be a positive integer"
    usage
fi

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
TIMESTAMP=$(date +"%Y_%m_%d_%H")
LOG_DIR="$BASE_DIR/$TIMESTAMP"
ARCHIVE_NAME="harmonic_logs_$TIMESTAMP.tar.gz"

# If in test mode, use a different directory to avoid interfering with production logs
if [ "$TEST_MODE" = true ]; then
    LOG_DIR="${BASE_DIR}/test_${TIMESTAMP}"
    ARCHIVE_NAME="harmonic_test_logs_${TIMESTAMP}.tar.gz"
    if [ "$NUM_FILES" -eq 1 ]; then
        echo "TEST MODE ENABLED: Will only download the most recent file from each server"
    else
        echo "TEST MODE ENABLED: Will download the $NUM_FILES most recent files from each server"
    fi
elif [ "$RECENT_MODE" = true ]; then
    LOG_DIR="${BASE_DIR}/recent_${TIMESTAMP}"
    ARCHIVE_NAME="harmonic_recent_logs_${TIMESTAMP}.tar.gz"
    if [ "$NUM_FILES" -eq 1 ]; then
        echo "RECENT MODE ENABLED: Will only download the most recent file from each server"
    else
        echo "RECENT MODE ENABLED: Will download the $NUM_FILES most recent files from each server"
    fi
fi

# Create directories for storing logs
mkdir -p "$LOG_DIR/mediacenter"
mkdir -p "$LOG_DIR/mediadeck"

echo "=========================================================="
echo "Harmonic Server Log Fetcher"
if [ "$TEST_MODE" = true ]; then
    echo "Test mode - downloading only recent files"
else
    echo "Fetching all logs from both servers"
fi
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
    echo "Found $total_files log files on $server_name"
    
    # In test mode, only get the N most recent files
    if [ "$TEST_MODE" = true ] || [ "$RECENT_MODE" = true ]; then
        if [ "$NUM_FILES" -eq 1 ]; then
            echo "Test mode: Will download only the most recent file"
        else
            echo "Test mode: Will download the $NUM_FILES most recent files"
        fi
        
        # Create a temporary file for sortable timestamps
        local timestamps_with_sort_key=$(mktemp)
        
        # Extract the most recent files based on timestamp
        # Add a timestamp field that's properly sortable
        while read -r line; do
            filename=$(echo "$line" | awk '{print $1}')
            month=$(echo "$line" | awk '{print $2}')
            day=$(echo "$line" | awk '{print $3}')
            time=$(echo "$line" | awk '{print $4}')
            
            # Convert month name to number for sorting
            if [[ "$month" =~ ^[0-9]+$ ]]; then
                month_num="$month"
            else
                case "$month" in
                    Jan) month_num="01" ;;
                    Feb) month_num="02" ;;
                    Mar) month_num="03" ;;
                    Apr) month_num="04" ;;
                    May) month_num="05" ;;
                    Jun) month_num="06" ;;
                    Jul) month_num="07" ;;
                    Aug) month_num="08" ;;
                    Sep) month_num="09" ;;
                    Oct) month_num="10" ;;
                    Nov) month_num="11" ;;
                    Dec) month_num="12" ;;
                    *) month_num="01" ;;  # Default to January if unknown
                esac
            fi
            
            # Format day with leading zero if needed
            day_num=$(printf "%02d" "$day")
            
            # Add a sortable timestamp field to each line
            echo "$(date +%Y)$month_num$day_num$time $filename $month $day $time" >> "$timestamps_with_sort_key"
        done < "$file_timestamps"
        
        # Sort by the timestamp field and take the N most recent files
        # We'll take the minimum of NUM_FILES and total_files
        local num_to_download
        if [ "$NUM_FILES" -gt "$total_files" ]; then
            num_to_download=$total_files
            echo "Note: Only $num_to_download files available (fewer than requested $NUM_FILES)"
        else
            num_to_download=$NUM_FILES
        fi
        
        # Create a new file with just the most recent N files
        sort -r "$timestamps_with_sort_key" | head -n "$num_to_download" | cut -d' ' -f2- > "${file_timestamps}.newest"
        mv "${file_timestamps}.newest" "$file_timestamps"
        rm "$timestamps_with_sort_key"
        
        # Show which files were selected
        echo "Selected the $num_to_download most recent files for download:"
        cat "$file_timestamps" | awk '{print "- " $1}'
        
        total_files=$num_to_download
    fi
    
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
                
                # More robust date handling
                if [[ "$month" =~ ^[0-9]+$ ]]; then
                    # If month is numeric, use it directly
                    formatted_month="$month"
                else
                    # Convert month name to number
                    case "$month" in
                        Jan) formatted_month="01" ;;
                        Feb) formatted_month="02" ;;
                        Mar) formatted_month="03" ;;
                        Apr) formatted_month="04" ;;
                        May) formatted_month="05" ;;
                        Jun) formatted_month="06" ;;
                        Jul) formatted_month="07" ;;
                        Aug) formatted_month="08" ;;
                        Sep) formatted_month="09" ;;
                        Oct) formatted_month="10" ;;
                        Nov) formatted_month="11" ;;
                        Dec) formatted_month="12" ;;
                        *) formatted_month="01" ;;  # Default to January if unknown
                    esac
                fi

                # Ensure day has leading zero if needed
                formatted_day=$(printf "%02d" "$day")

                # Format time properly for touch
                formatted_time=$(echo "$time" | sed 's/\([0-9][0-9]\)\([0-9][0-9]\)/\1\2/')

                # Create the properly formatted date string for touch
                touch_date="${current_year}${formatted_month}${formatted_day}${formatted_time}"
                
                # Restore timestamp
                if [ -f "${output_dir}/$filename" ]; then
                    touch -t "$touch_date" "${output_dir}/$filename"
                    echo "Set timestamp for $filename: $touch_date"
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

# Log rotation - handle different types of files with different retention periods
if [ "$TEST_MODE" = false ] && [ "$RECENT_MODE" = false ]; then
    echo "Performing log rotation..."
    
    # Regular log rotation (keeping only the last $RETENTION_DAYS days)
    echo "Cleaning up regular logs older than $RETENTION_DAYS days..."
    
    # Debug output for regular files
    echo "Looking for regular directories older than $RETENTION_DAYS days..."
    OLD_DIRS=$(find "$BASE_DIR" -type d -name "????_??_??_??" -mtime +$RETENTION_DAYS -print)
    if [ -n "$OLD_DIRS" ]; then
        echo "Found regular directories to delete: $OLD_DIRS"
    else
        echo "No regular directories found older than $RETENTION_DAYS days"
    fi
    
    # Debug output for regular archives
    echo "Looking for regular archives older than $RETENTION_DAYS days..."
    OLD_ARCHIVES=$(find "$BASE_DIR" -name "harmonic_logs_????_??_??_??.tar.gz" -mtime +$RETENTION_DAYS -print)
    if [ -n "$OLD_ARCHIVES" ]; then
        echo "Found regular archives to delete: $OLD_ARCHIVES"
    else
        echo "No regular archives found older than $RETENTION_DAYS days"
    fi
    
    # Debug output for test files (same retention as regular)
    echo "Looking for test directories older than $RETENTION_DAYS days..."
    OLD_TEST_DIRS=$(find "$BASE_DIR" -type d -name "test_????_??_??_??" -mtime +$RETENTION_DAYS -print)
    if [ -n "$OLD_TEST_DIRS" ]; then
        echo "Found test directories to delete: $OLD_TEST_DIRS"
    else
        echo "No test directories found older than $RETENTION_DAYS days"
    fi
    
    echo "Looking for test archives older than $RETENTION_DAYS days..."
    OLD_TEST_ARCHIVES=$(find "$BASE_DIR" -name "harmonic_test_logs_????_??_??_??.tar.gz" -mtime +$RETENTION_DAYS -print)
    if [ -n "$OLD_TEST_ARCHIVES" ]; then
        echo "Found test archives to delete: $OLD_TEST_ARCHIVES"
    else
        echo "No test archives found older than $RETENTION_DAYS days"
    fi
    
    # Recent files cleanup (different retention period)
    if [ -n "$RECENT_RETENTION_HOURS" ] && [ "$RECENT_RETENTION_HOURS" -gt 0 ]; then
        echo "Cleaning up recent logs older than $RECENT_RETENTION_HOURS hours..."
        
        # Convert hours to minutes for find command
        RECENT_RETENTION_MINUTES=$((RECENT_RETENTION_HOURS * 60))
        
        echo "Looking for recent directories older than $RECENT_RETENTION_HOURS hours..."
        OLD_RECENT_DIRS=$(find "$BASE_DIR" -type d -name "recent_????_??_??_??" -mmin +$RECENT_RETENTION_MINUTES -print)
        if [ -n "$OLD_RECENT_DIRS" ]; then
            echo "Found recent directories to delete: $OLD_RECENT_DIRS"
        else
            echo "No recent directories found older than $RECENT_RETENTION_HOURS hours"
        fi
        
        echo "Looking for recent archives older than $RECENT_RETENTION_HOURS hours..."
        OLD_RECENT_ARCHIVES=$(find "$BASE_DIR" -name "harmonic_recent_logs_????_??_??_??.tar.gz" -mmin +$RECENT_RETENTION_MINUTES -print)
        if [ -n "$OLD_RECENT_ARCHIVES" ]; then
            echo "Found recent archives to delete: $OLD_RECENT_ARCHIVES"
        else
            echo "No recent archives found older than $RECENT_RETENTION_HOURS hours"
        fi
    fi
    
    # Actual deletion with error capture
    echo "Attempting to delete old regular directories..."
    find "$BASE_DIR" -type d -name "????_??_??_??" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>&1 || echo "Error deleting regular directories: $?"
    
    echo "Attempting to delete old regular archives..."
    find "$BASE_DIR" -name "harmonic_logs_????_??_??_??.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \; 2>&1 || echo "Error deleting regular archives: $?"
    
    echo "Attempting to delete old test directories..."
    find "$BASE_DIR" -type d -name "test_????_??_??_??" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>&1 || echo "Error deleting test directories: $?"
    
    echo "Attempting to delete old test archives..."
    find "$BASE_DIR" -name "harmonic_test_logs_????_??_??_??.tar.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \; 2>&1 || echo "Error deleting test archives: $?"
    
    # Delete recent files if retention is configured
    if [ -n "$RECENT_RETENTION_HOURS" ] && [ "$RECENT_RETENTION_HOURS" -gt 0 ]; then
        RECENT_RETENTION_MINUTES=$((RECENT_RETENTION_HOURS * 60))
        
        echo "Attempting to delete old recent directories..."
        find "$BASE_DIR" -type d -name "recent_????_??_??_??" -mmin +$RECENT_RETENTION_MINUTES -exec rm -rf {} \; 2>&1 || echo "Error deleting recent directories: $?"
        
        echo "Attempting to delete old recent archives..."
        find "$BASE_DIR" -name "harmonic_recent_logs_????_??_??_??.tar.gz" -mmin +$RECENT_RETENTION_MINUTES -exec rm -f {} \; 2>&1 || echo "Error deleting recent archives: $?"
    fi
    
    echo "Log rotation completed"
else
    if [ "$TEST_MODE" = true ]; then
        echo "Test mode: Skipping log rotation"
        echo "You may want to manually remove the test logs at: $LOG_DIR"
    elif [ "$RECENT_MODE" = true ]; then
        echo "Recent mode: Skipping log rotation"
        echo "Recent logs stored at: $LOG_DIR"
    fi
fi

exit 0