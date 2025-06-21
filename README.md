# Harmonic Log Fetcher

A utility for retrieving log files from Harmonic video playout servers, with a web interface for easier team access and dual-frequency collection for critical issue detection.

## Features

- **Dual-frequency log collection**: Hourly recent files + periodic full collection
- **Configurable retention**: Separate retention policies for different file types
- **Real-time issue capture**: Frequent collection prevents data loss from server cleanup
- **Web interface** for team access without requiring command-line knowledge
- **User roles** (admin/regular) for appropriate access control
- **Configuration separation** to keep credentials secure

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

# Retention period in days for regular and test logs
RETENTION_DAYS=10

# Retention period in hours for recent logs (default: 24)
RECENT_RETENTION_HOURS=24
```

### Web Users Configuration (web_users.cfg)

The web interface uses a separate configuration file for user management. This file is created automatically during setup.

## Usage

### Command-Line

Run the script with various modes:

```bash
# Full collection (all files)
./fetch_harmonic_logs.sh

# Recent files only (for frequent monitoring)
./fetch_harmonic_logs.sh -r -n 10

# Test mode (for development)
./fetch_harmonic_logs.sh -t -n 5
```

#### Parameters:
- `-c config_file`: Specify a different config file
- `-r`: Recent mode (download only recent files for frequent runs)
- `-t`: Test mode (download only recent files, separate retention)
- `-n num_files`: Number of recent files to download in recent or test mode (default: 1)
- `-h`: Display help information

#### Archive Naming:
- **Regular logs**: `harmonic_logs_YYYY_MM_DD_HH.tar.gz`
- **Recent logs**: `harmonic_recent_logs_YYYY_MM_DD_HH.tar.gz`
- **Test logs**: `harmonic_test_logs_YYYY_MM_DD_HH.tar.gz`

### Recommended Cron Setup

For optimal log capture without data loss:

```bash
# Every hour: get recent files only (captures real-time issues)
0 * * * * /path/to/fetch_harmonic_logs.sh -r -n 10 > /path/to/logs/cron_log_$(date +\%Y\%m\%d_\%H)_recent.log 2>&1

# Every 3 hours: full collection (complete backup)
0 */3 * * * /path/to/fetch_harmonic_logs.sh > /path/to/logs/cron_log_$(date +\%Y\%m\%d_\%H)_full.log 2>&1
```

This dual-frequency approach ensures:
- **No data loss**: Frequent collection prevents server cleanup from removing files
- **Complete coverage**: Regular full collections ensure nothing is missed
- **Efficient operation**: Recent mode downloads only what's needed for monitoring

### Web Interface

Access the web interface at http://your-server-ip:5001 (or the configured port).

## Retention Policies

The system uses different retention periods for different types of logs:

- **Regular logs**: Configurable via `RETENTION_DAYS` (default: 10 days)
- **Test logs**: Same as regular logs (`RETENTION_DAYS`)
- **Recent logs**: Configurable via `RECENT_RETENTION_HOURS` (default: 24 hours)

This allows for:
- Long-term storage of complete log sets
- Short-term storage of frequent monitoring snapshots
- Automatic cleanup to prevent disk space issues

## Recent Updates

### Version 2.1 (June 2025)
- **Added recent mode (`-r` flag)**: Enables frequent collection of recent files
- **Dual-frequency collection**: Support for hourly recent + periodic full collection
- **Enhanced retention**: Separate retention policies for different file types
- **Hourly timestamping**: Archives now include hour in filename
- **Improved log rotation**: Better debugging and error handling
- **Configuration enhancement**: Added `RECENT_RETENTION_HOURS` setting

### Version 2.0 (March 2025)
- **Web interface**: Added Flask-based web interface for team access
- **User management**: Role-based authentication (admin/regular users)
- **Job tracking**: Real-time job status and progress monitoring
- **Download capabilities**: Web-based archive downloads
- **Security improvements**: Secure session handling and input validation

## Security Notes

1. Never commit the actual config files to git
2. Keep credentials secure
3. Use HTTPS for production deployments of the web interface
4. Regularly audit the user list

## Troubleshooting

### Log Collection Issues
- Check server connectivity and credentials in `config.cfg`
- Verify disk space in the base directory
- Review cron logs for any error messages

### Web Interface Issues
- Check service status: `sudo systemctl status harmonic-web`
- Review application logs for errors
- Verify all template files are present

### Retention Issues
- Use the diagnostic script: `./check_log_retention.sh`
- Verify retention settings in configuration
- Check file permissions in the logs directory

## License

[MIT License](LICENSE)