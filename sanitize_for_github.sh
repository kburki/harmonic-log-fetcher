#!/bin/bash

# Sanitize Harmonic Log Fetcher for GitHub
# This script prepares the repository for GitHub by ensuring no sensitive data is committed

echo "Sanitizing Harmonic Log Fetcher repository for GitHub..."

# Check if we are in the correct directory
if [ ! -f "fetch_harmonic_logs.sh" ]; then
    echo "Error: Cannot find fetch_harmonic_logs.sh"
    echo "Please run this script from the root of the Harmonic Log Fetcher repository"
    exit 1
fi

# Ensure config.example.cfg exists
if [ ! -f "config.example.cfg" ]; then
    echo "Creating config.example.cfg template..."
    cat > config.example.cfg << EOF
# EXAMPLE Configuration file for Harmonic Log Fetcher
# Copy this file to config.cfg and update with your actual values
# DO NOT commit the actual config.cfg to GitHub, only this example

# Base directory for log storage
BASE_DIR="/path/to/logs/directory"

# MediaCenter Server Information
MEDIACENTER_IP="server1_ip_address"
MEDIACENTER_USER="username"
MEDIACENTER_PASS="password"
MEDIACENTER_PATH="/path/to/logs"

# MediaDeck Server Information
MEDIADECK_IP="server2_ip_address"
MEDIADECK_USER="username"
MEDIADECK_PASS="password"
MEDIADECK_PATH="/path/to/logs"

# Retention period in days
RETENTION_DAYS=5
EOF
    echo "Created config.example.cfg"
fi

# Ensure .gitignore exists
if [ ! -f ".gitignore" ]; then
    echo "Creating .gitignore..."
    cat > .gitignore << EOF
# Ignore configuration files with credentials
config.cfg
web_users.cfg
*.bak

# Python virtual environment
venv/
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# Log files and data
*.log
*.tar.gz
*_20??_??_??/

# IDE files
.idea/
.vscode/
*.swp
*.swo

# OS specific files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Flask specific
instance/
.webassets-cache

# Debug files
*.debug
EOF
    echo "Created .gitignore"
fi

# Check if config.cfg exists and warn if it does
if [ -f "config.cfg" ]; then
    echo "WARNING: config.cfg exists in the repository"
    echo "This file contains sensitive credentials and should not be committed to GitHub"
    echo "It has been added to .gitignore, but you should manually verify it won't be committed"
fi

# Check if web_users.cfg exists and warn if it does
if [ -f "web_users.cfg" ]; then
    echo "WARNING: web_users.cfg exists in the repository"
    echo "This file contains user credentials and should not be committed to GitHub"
    echo "It has been added to .gitignore, but you should manually verify it won't be committed"
fi

# Create a web_users.example.cfg if it doesn't exist
if [ ! -f "web_users.example.cfg" ]; then
    echo "Creating web_users.example.cfg template..."
    cat > web_users.example.cfg << EOF
# Web users configuration for Harmonic Log Fetcher
# Format: username:role=password_hash
# This is an example file. Do not commit the actual web_users.cfg to GitHub.
# The real file will be created during setup.
EOF
    echo "Created web_users.example.cfg"
fi

# Ensure README.md exists
if [ ! -f "README.md" ]; then
    echo "WARNING: README.md does not exist"
    echo "You should create a README.md file to document your project"
fi

# Make sure the web directory has a README
if [ -d "web" ] && [ ! -f "web/README.md" ]; then
    echo "WARNING: web/README.md does not exist"
    echo "You should create a README.md file in the web directory to document the web interface"
fi

# Check for any accidental committed log files
log_files=$(find . -name "*.log" -o -name "*.tar.gz" | grep -v "venv")
if [ -n "$log_files" ]; then
    echo "WARNING: Found log files that should not be committed:"
    echo "$log_files"
    echo "Consider removing these files from the repository"
fi

echo "Sanitization complete."
echo "Please review the repository contents before committing to GitHub."
echo "Remember to carefully check 'git status' and 'git diff' to ensure no credentials are included."