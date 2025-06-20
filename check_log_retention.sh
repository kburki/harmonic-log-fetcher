#!/bin/bash

# Script to diagnose log retention issues
# This script analyzes why old log files may not be getting deleted

# Configuration
CONFIG_FILE="/home/kburki/KTOO/Harmonic/config.cfg"
SCRIPT_PATH="/home/kburki/KTOO/Harmonic/fetch_harmonic_logs.sh"

echo "============================================="
echo "Log Retention Diagnostic Tool"
echo "============================================="

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

# Load configuration
echo "Loading configuration from $CONFIG_FILE"
source "$CONFIG_FILE"

# Display retention settings
echo "Retention period: $RETENTION_DAYS days"
echo "Base directory: $BASE_DIR"

# Check if base directory exists
if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Base directory does not exist: $BASE_DIR"
    exit 1
fi

# Check directory content
echo
echo "Current log directory content:"
ls -la "$BASE_DIR"

# Count log files
TOTAL_DIRS=$(find "$BASE_DIR" -type d -name "????_??_??" | wc -l)
TOTAL_ARCHIVES=$(find "$BASE_DIR" -name "harmonic_logs_????_??_??.tar.gz" | wc -l)
TOTAL_TEST_ARCHIVES=$(find "$BASE_DIR" -name "harmonic_test_logs_????_??_??.tar.gz" | wc -l)

echo
echo "Found:"
echo "- $TOTAL_DIRS date directories"
echo "- $TOTAL_ARCHIVES regular log archives"
echo "- $TOTAL_TEST_ARCHIVES test log archives"

# Check which files would be deleted
echo
echo "Files older than $RETENTION_DAYS days that should be deleted:"
OLD_DIRS=$(find "$BASE_DIR" -type d -name "????_??_??" -mtime +$RETENTION_DAYS)
OLD_ARCHIVES=$(find "$BASE_DIR" -name "harmonic_logs_????_??_??.tar.gz" -mtime +$RETENTION_DAYS)

if [ -n "$OLD_DIRS" ]; then
    echo "Directories:"
    echo "$OLD_DIRS"
else
    echo "No directories found older than $RETENTION_DAYS days (by modification time)"
fi

if [ -n "$OLD_ARCHIVES" ]; then
    echo "Archives:"
    echo "$OLD_ARCHIVES"
else
    echo "No archives found older than $RETENTION_DAYS days (by modification time)"
fi

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo
    echo "Error: Script not found at $SCRIPT_PATH"
    exit 1
fi

# Extract and show the log rotation code from the script
echo
echo "Log rotation code in the script:"
grep -A 10 "Log rotation" "$SCRIPT_PATH"

# Check for cron jobs
echo
echo "Checking for cron jobs that might run the script:"
crontab -l | grep -i "harmonic\|fetch"

# Testing find command with verbose output
echo
echo "Testing find command with verbose output:"
find "$BASE_DIR" -type d -name "????_??_??" -mtime +$RETENTION_DAYS -ls

# Check file timestamps more explicitly
echo
echo "Checking file timestamps in different formats:"
for dir in $(find "$BASE_DIR" -type d -name "????_??_??"); do
    DIRNAME=$(basename "$dir")
    MTIME=$(stat -c '%Y' "$dir")
    MTIME_HUMAN=$(stat -c '%y' "$dir")
    DAYS_OLD=$(( ($(date +%s) - $MTIME) / 86400 ))
    echo "Directory: $DIRNAME, Modified: $MTIME_HUMAN, Days old: $DAYS_OLD"
done

# Test deletion permissions
echo
echo "Testing deletion permissions:"
for dir in $OLD_DIRS; do
    if [ -n "$dir" ]; then
        echo -n "Can delete $dir? "
        if [ -w "$dir" ] && [ -w "$(dirname "$dir")" ]; then
            echo "Yes"
        else
            echo "No - Permission issue"
        fi
    fi
done

for file in $OLD_ARCHIVES; do
    if [ -n "$file" ]; then
        echo -n "Can delete $file? "
        if [ -w "$file" ] && [ -w "$(dirname "$file")" ]; then
            echo "Yes"
        else
            echo "No - Permission issue"
        fi
    fi
done

# Check if any test logs are being skipped
echo
echo "Checking if test mode might be affecting rotation:"
grep -A 5 "TEST_MODE" "$SCRIPT_PATH" | grep "if"

# Recommendation
echo
echo "============================================="
echo "Recommendation:"
echo "1. Verify that the script is running with TEST_MODE=false"
echo "2. Consider manually testing the rotation commands:"
echo "   find \"$BASE_DIR\" -type d -name \"????_??_??\" -mtime +$RETENTION_DAYS -exec rm -rf {} \\;"
echo "   find \"$BASE_DIR\" -name \"harmonic_logs_????_??_??.tar.gz\" -mtime +$RETENTION_DAYS -exec rm -f {} \\;"
echo
echo "3. Check if there are any errors when running these commands manually"
echo "4. If needed, you can force deletion based on the filename date pattern:"
echo "   find \"$BASE_DIR\" -type d -name \"2025_03_04\" -exec rm -rf {} \\;"
echo "   find \"$BASE_DIR\" -name \"harmonic_logs_2025_03_04.tar.gz\" -exec rm -f {} \\;"
echo "============================================="