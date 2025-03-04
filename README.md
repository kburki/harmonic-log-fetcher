# Harmonic Log Fetcher

This utility script automatically fetches log files from Harmonic video playout servers via FTP and archives them for later analysis. It's designed to be run as a cron job and can handle multiple servers.

## Features

- Automatically downloads log files from multiple Harmonic servers
- Preserves original file timestamps
- Creates compressed archives of logs organized by date
- Configurable retention policy (defaults to 5 days)
- Multiple download methods for reliability (ncftp, wget, standard ftp)
- Secure configuration storage separate from code

## Installation

1. Copy the setup script to your system and run it:
   ```bash
   chmod +x setup_harmonic_logs.sh
   ./setup_harmonic_logs.sh
   ```

2. The setup script will:
   - Create necessary directories
   - Install required dependencies
   - Create configuration files
   - Set up a cron job to run daily
   - Add a proper .gitignore to protect sensitive data

## Configuration

The script uses a separate configuration file to store sensitive information like server credentials. This allows the script itself to be safely checked into version control.

The default configuration file is located at:
```
/home/kburki/KTOO/Harmonic/config.cfg
```

An example configuration file (`config.example.cfg`) is provided as a template. The actual configuration file should never be committed to version control.

## Manual Execution

You can run the script manually with:
```bash
/home/kburki/KTOO/Harmonic/fetch_harmonic_logs.sh
```

Or specify a different configuration file:
```bash
/home/kburki/KTOO/Harmonic/fetch_harmonic_logs.sh -c /path/to/alternate/config.cfg
```

## Security Considerations

- The configuration file contains sensitive information and should be protected
- The script automatically adds `config.cfg` to the `.gitignore` file
- Only commit the example configuration file (`config.example.cfg`) to version control
- Consider restricting permissions on the configuration file:
  ```bash
  chmod 600 /home/kburki/KTOO/Harmonic/config.cfg
  ```

## Logs and Archives

Logs are stored in dated directories under the base directory specified in the configuration:
```
/home/kburki/KTOO/Harmonic/logs/YYYY_MM_DD/
```

And are also archived as compressed tar files:
```
/home/kburki/KTOO/Harmonic/logs/harmonic_logs_YYYY_MM_DD.tar.gz
```

## Troubleshooting

Check the cron logs for any errors:
```
/home/kburki/KTOO/Harmonic/logs/cron_log_YYYYMMDD.log
```

Common issues:
- FTP connection problems (check server IPs and credentials)
- File permission issues
- Missing required utilities (ncftp, wget)

## GitHub Configuration

When pushing this code to GitHub, make sure to:

1. Create a GitHub repository
2. Initialize git in your local directory:
   ```bash
   cd /home/kburki/KTOO/Harmonic
   git init
   ```

3. Add and commit the files (the .gitignore will prevent config.cfg from being included):
   ```bash
   git add .
   git commit -m "Initial commit of Harmonic Log Fetcher"
   ```

4. Connect to your GitHub repository:
   ```bash
   git remote add origin https://github.com/yourusername/harmonic-log-fetcher.git
   git push -u origin main
   ```

## License

This script is provided under the MIT License.
