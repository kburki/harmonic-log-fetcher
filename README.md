# Harmonic Log Fetcher

A utility for retrieving log files from Harmonic video playout servers, with a web interface for easier team access.

## Features

- Automated collection of log files from MediaCenter and MediaDeck servers
- Support for fetching all logs or just the most recent files (test mode)
- Web interface for team access without requiring command-line knowledge
- User roles (admin/regular) for appropriate access control
- Configuration separation to keep credentials secure

## Components

1. **Command-Line Tool**
   - `fetch_harmonic_logs.sh`: Main script for fetching logs
   - `config.example.cfg`: Example configuration (copy to config.cfg)

2. **Web Interface**
   - Flask-based web application
   - User authentication and management
   - Job tracking and download capabilities

## Setup Instructions

### Command-Line Tool

1. Clone this repository
2. Copy the example config:
   ```bash
   cp config.example.cfg config.cfg
   ```
3. Edit `config.cfg` with your server details and credentials
4. Make the script executable:
   ```bash
   chmod +x fetch_harmonic_logs.sh
   ```

### Web Interface

See the [Setup Guide for Web Interface](web/README.md) for detailed instructions.

## Configuration

### Main Configuration (config.cfg)

Create a `config.cfg` file with the following structure:

```bash
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
```

### Web Users Configuration (web_users.cfg)

The web interface uses a separate configuration file for user management. This file is created automatically during setup.

## Usage

### Command-Line

Run the script directly:

```bash
./fetch_harmonic_logs.sh
```

Optional parameters:
- `-c config_file`: Specify a different config file
- `-t`: Test mode (only download recent files)
- `-n num_files`: Number of recent files to download in test mode
- `-h`: Display help information

Example:
```bash
./fetch_harmonic_logs.sh -t -n 5
```

### Web Interface

Access the web interface at http://your-server-ip:5001 (or the configured port).

## Security Notes

1. Never commit the actual config files to git
2. Keep credentials secure
3. Use HTTPS for production deployments of the web interface

## Maintenance

The script automatically handles log rotation based on the `RETENTION_DAYS` setting.

## License

[MIT License](LICENSE)