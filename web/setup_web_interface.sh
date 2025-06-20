#!/bin/bash

# Harmonic Log Fetcher Web Interface Setup Script
# This script will set up the web interface for the Harmonic log fetcher

# Configuration - Edit these variables
BASE_DIR="/home/kburki/KTOO/Harmonic"
WEB_DIR="$BASE_DIR/web"
PORT=5001  # Change this if you need to use a different port

# Ensure script is run as the correct user
if [[ $(whoami) != "kburki" ]]; then
    echo "This script should be run as the 'kburki' user."
    echo "Please run: sudo -u kburki $0"
    exit 1
fi

echo "=== Harmonic Log Fetcher Web Interface Setup ==="

# Create necessary directories
echo "Creating directories..."
mkdir -p "$WEB_DIR"
mkdir -p "$WEB_DIR/templates"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is not installed. Please install it first."
    exit 1
fi

# Set up virtual environment
echo "Setting up Python virtual environment..."
cd "$WEB_DIR" || exit 1
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install required packages
echo "Installing required packages..."
pip install flask

# Create the web_users.cfg file if it doesn't exist
if [ ! -f "$BASE_DIR/web_users.cfg" ]; then
    echo "# Web users configuration for Harmonic Log Fetcher" > "$BASE_DIR/web_users.cfg"
    echo "# Format: username=password_hash" >> "$BASE_DIR/web_users.cfg"
    echo "Created web_users.cfg file"
fi

# Ensure the script is executable
chmod +x "$BASE_DIR/fetch_harmonic_logs.sh"

# Create a simple test script to check if the app is running correctly
cat > "$WEB_DIR/test_app.py" << EOF
import os
import sys

# Check if Flask is installed
try:
    from flask import Flask
    print("Flask is installed correctly!")
except ImportError:
    print("ERROR: Flask is not installed. Please run: pip install flask")
    sys.exit(1)

# Check if the app.py file exists
if os.path.exists("app.py"):
    print("app.py exists!")
else:
    print("ERROR: app.py does not exist in the current directory.")
    sys.exit(1)

# Check if templates directory exists
if os.path.exists("templates") and os.path.isdir("templates"):
    print("templates directory exists!")
else:
    print("ERROR: templates directory does not exist.")
    sys.exit(1)
    
# Check if template files exist
template_files = ["base.html", "dashboard.html", "job_status.html", "login.html", "setup.html", "users.html"]
missing_templates = []

for file in template_files:
    if not os.path.exists(f"templates/{file}"):
        missing_templates.append(file)

if missing_templates:
    print(f"ERROR: The following template files are missing: {', '.join(missing_templates)}")
    sys.exit(1)
else:
    print("All template files exist!")

print("\nAll checks passed! The web interface should be ready to run.")
EOF

# Inform user about next steps
echo
echo "=== Setup Complete ==="
echo
echo "To finalize the setup:"
echo
echo "1. Copy the app.py file to $WEB_DIR"
echo "2. Copy all HTML template files to $WEB_DIR/templates"
echo "3. Run a basic test with: cd $WEB_DIR && source venv/bin/activate && python test_app.py"
echo
echo "To run the web interface temporarily:"
echo "  cd $WEB_DIR && source venv/bin/activate && python app.py"
echo
echo "For a permanent installation, create a systemd service using the instructions in the setup guide."
echo "The web interface will be available at: http://your-server-ip:$PORT"
echo
echo "First-time access will prompt you to create an admin user."