# Harmonic Log Fetcher Web Interface

Web interface for the Harmonic log fetcher utility, allowing team members to retrieve logs without command-line access.

## Prerequisites

- Python 3.6 or higher
- pip (Python package manager)
- The main Harmonic log fetcher script and its configuration

## Installation

1. Create the web application directory:

```bash
mkdir -p web
cd web
```

2. Set up a Python virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate
```

3. Install required packages:

```bash
pip install flask
```

4. Create the application structure:

```bash
mkdir -p templates
```

5. Copy all the provided files to their correct locations:
   - Python files to the main directory
   - HTML templates to the `templates` directory

## Configuration

The web interface uses these configuration files:

1. **Main configuration** (`config.cfg`): Shared with the CLI tool, contains server credentials
2. **Web users configuration** (`web_users.cfg`): Contains web interface user credentials

Both files should be kept out of version control for security.

## Running the Application

### Development Mode

```bash
cd web
source venv/bin/activate
python app.py
```

### Production Deployment (Systemd Service)

1. Create a systemd service file:

```bash
sudo nano /etc/systemd/system/harmonic-web.service
```

2. Add the following content (adjust paths as needed):

```ini
[Unit]
Description=Harmonic Log Fetcher Web Interface
After=network.target

[Service]
User=kburki
WorkingDirectory=/home/kburki/KTOO/Harmonic/web
ExecStart=/home/kburki/KTOO/Harmonic/web/venv/bin/python /home/kburki/KTOO/Harmonic/web/app.py
Restart=always

[Install]
WantedBy=multi-user.target
```

3. Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable harmonic-web
sudo systemctl start harmonic-web
```

## User Management

The web interface supports two user roles:

1. **Administrators** - Can manage users and fetch logs
2. **Regular Users** - Can only fetch logs

The first user created during setup will be an administrator.

## Security Recommendations

1. Run behind a reverse proxy (like Nginx) with HTTPS
2. Use strong passwords for all accounts
3. Consider IP restrictions if appropriate for your environment
4. Regularly audit the user list