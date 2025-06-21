#!/usr/bin/env python3
import os
import subprocess
import threading
import time
import hashlib
from functools import wraps
import datetime
from flask import Flask, render_template, request, redirect, url_for, session, send_file, flash

app = Flask(__name__)
app.secret_key = os.urandom(24)  # Generate a random secret key for sessions

# Pass the current date to all templates
@app.context_processor
def inject_now():
    return {'now': datetime.datetime.now()}

# Default configuration
DEFAULT_CONFIG_FILE = "/home/kburki/KTOO/Harmonic/config.cfg"
WEB_USERS_CONFIG = "/home/kburki/KTOO/Harmonic/web_users.cfg"
SCRIPT_PATH = "/home/kburki/KTOO/Harmonic/fetch_harmonic_logs.sh"

# Status tracking for background jobs
jobs = {}

def load_config():
    """Load configuration settings from config file"""
    config = {}
    try:
        with open(DEFAULT_CONFIG_FILE, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    key, value = line.split('=', 1)
                    config[key.strip()] = value.strip().strip('"')
        return config
    except Exception as e:
        print(f"Error loading config: {e}")
        return {}

def load_users():
    """Load web users from web_users.cfg file"""
    users = {}
    try:
        if os.path.exists(WEB_USERS_CONFIG):
            with open(WEB_USERS_CONFIG, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        parts = line.split('=', 1)
                        if len(parts) == 2:
                            user_info = parts[0].strip()
                            password_hash = parts[1].strip()
                            
                            # Check if role is specified in the username
                            if ':' in user_info:
                                username, role = user_info.split(':', 1)
                            else:
                                # Default to admin for backward compatibility
                                username, role = user_info, 'admin'
                                
                            users[username] = {
                                'password_hash': password_hash,
                                'role': role
                            }
        return users
    except Exception as e:
        print(f"Error loading users: {e}")
        return {}

def save_user(username, password, role='user'):
    """Save a new user to the web_users.cfg file"""
    try:
        # Hash the password
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        users = load_users()
        users[username] = {
            'password_hash': password_hash,
            'role': role
        }
        
        with open(WEB_USERS_CONFIG, 'w') as f:
            f.write("# Web users configuration for Harmonic Log Fetcher\n")
            f.write("# Format: username:role=password_hash\n")
            for user, data in users.items():
                f.write(f"{user}:{data['role']}={data['password_hash']}\n")
        return True
    except Exception as e:
        print(f"Error saving user: {e}")
        return False

def check_auth(username, password):
    """Check if username/password combination is valid"""
    users = load_users()
    if username in users:
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        return users[username]['password_hash'] == password_hash
    return False

def login_required(f):
    """Decorator to require login for routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def admin_required(f):
    """Decorator to require admin role for routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        
        users = load_users()
        username = session.get('username')
        
        if username not in users or users[username]['role'] != 'admin':
            flash('Admin access required for this page', 'error')
            return redirect(url_for('dashboard'))
            
        return f(*args, **kwargs)
    return decorated_function

def run_script_async(job_id, test_mode=False, num_files=1):
    """Run the log fetcher script asynchronously"""
    try:
        cmd = [SCRIPT_PATH]
        if test_mode:
            cmd.extend(["-t", "-n", str(num_files)])
            
        jobs[job_id] = {
            'status': 'running',
            'start_time': time.time(),
            'cmd': ' '.join(cmd),
            'output': []
        }
        
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # Capture output line by line
        for line in process.stdout:
            jobs[job_id]['output'].append(line.strip())
        
        process.wait()
        
        if process.returncode == 0:
            jobs[job_id]['status'] = 'completed'
            # Find the archive file path from the output
            for line in jobs[job_id]['output']:
                if "Archive created:" in line:
                    archive_path = line.split("Archive created:")[1].strip()
                    jobs[job_id]['archive_path'] = archive_path
                    break
        else:
            jobs[job_id]['status'] = 'failed'
            
    except Exception as e:
        jobs[job_id]['status'] = 'failed'
        jobs[job_id]['output'].append(f"Error: {str(e)}")

# Routes
@app.route('/')
def home():
    """Redirect to login or dashboard based on login status"""
    if 'logged_in' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Handle user login"""
    error = None
    
    # Check if any users exist, if not show setup page
    users = load_users()
    if not users:
        return redirect(url_for('setup'))
    
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        if check_auth(username, password):
            session['logged_in'] = True
            session['username'] = username
            # Store user role in session
            session['role'] = users[username]['role']
            return redirect(url_for('dashboard'))
        else:
            error = 'Invalid credentials. Please try again.'
    
    return render_template('login.html', error=error)

@app.route('/setup', methods=['GET', 'POST'])
def setup():
    """First-time setup to create an admin user"""
    users = load_users()
    if users:
        # If users already exist, redirect to login
        return redirect(url_for('login'))
    
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        confirm_password = request.form['confirm_password']
        
        if not username or not password:
            return render_template('setup.html', error='Username and password are required')
        
        if password != confirm_password:
            return render_template('setup.html', error='Passwords do not match')
        
        # First user is always an admin
        if save_user(username, password, role='admin'):
            flash('Admin user created successfully! Please log in.')
            return redirect(url_for('login'))
        else:
            return render_template('setup.html', error='Failed to create user')
    
    return render_template('setup.html')

@app.route('/logout')
def logout():
    """Log the user out"""
    session.pop('logged_in', None)
    session.pop('username', None)
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    """Main dashboard for running log fetcher"""
    config = load_config()
    
    # Get a list of recent jobs
    recent_jobs = []
    for job_id, job in sorted(jobs.items(), key=lambda x: x[1]['start_time'], reverse=True)[:10]:
        job_info = {
            'id': job_id,
            'status': job['status'],
            'start_time': time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(job['start_time'])),
            'command': job['cmd']
        }
        
        if 'archive_path' in job and job['status'] == 'completed':
            job_info['archive_path'] = job['archive_path']
            job_info['archive_filename'] = os.path.basename(job['archive_path'])
            
        recent_jobs.append(job_info)
    
    # Get all available log archives from the logs directory
    available_archives = []
    try:
        base_dir = config.get('BASE_DIR', '/home/kburki/KTOO/Harmonic/logs/')
        if os.path.exists(base_dir):
            for filename in sorted(os.listdir(base_dir), reverse=True):
                if filename.endswith('.tar.gz') and filename.startswith('harmonic_'):
                    file_path = os.path.join(base_dir, filename)
                    if os.path.isfile(file_path):
                        # Extract date from filename or use file modification time
                        try:
                            # Try to extract date from filename format harmonic_logs_YYYY_MM_DD.tar.gz
                            if '_logs_' in filename:
                                date_part = filename.split('_logs_')[1].split('.')[0]
                                # Convert YYYY_MM_DD to a readable format
                                year, month, day = date_part.split('_')
                                friendly_date = f"{year}-{month}-{day}"
                            elif '_test_logs_' in filename:
                                date_part = filename.split('_test_logs_')[1].split('.')[0]
                                # Convert YYYY_MM_DD to a readable format
                                year, month, day = date_part.split('_')
                                friendly_date = f"{year}-{month}-{day} (Test)"
                            else:
                                # Fallback to file modification time
                                mtime = os.path.getmtime(file_path)
                                friendly_date = time.strftime('%Y-%m-%d', time.localtime(mtime))
                        except:
                            # Fallback to file modification time
                            mtime = os.path.getmtime(file_path)
                            friendly_date = time.strftime('%Y-%m-%d', time.localtime(mtime))
                        
                        # Get file size
                        size_bytes = os.path.getsize(file_path)
                        # Convert to human-readable format
                        if size_bytes < 1024:
                            size_str = f"{size_bytes} B"
                        elif size_bytes < 1024 * 1024:
                            size_str = f"{size_bytes / 1024:.1f} KB"
                        else:
                            size_str = f"{size_bytes / (1024 * 1024):.1f} MB"
                        
                        # Add to available archives
                        available_archives.append({
                            'filename': filename,
                            'path': file_path,
                            'date': friendly_date,
                            'size': size_str,
                            'mtime': os.path.getmtime(file_path)  # For sorting
                        })
            
            # Sort by modification time (newest first)
            available_archives = sorted(available_archives, key=lambda x: x['mtime'], reverse=True)
    except Exception as e:
        print(f"Error listing archives: {e}")
    
    return render_template('dashboard.html', 
                          config=config, 
                          recent_jobs=recent_jobs,
                          available_archives=available_archives,
                          username=session.get('username', 'User'),
                          is_admin=(session.get('role') == 'admin'))

@app.route('/fetch_logs', methods=['POST'])
@login_required
def fetch_logs():
    """Start a log fetching job"""
    test_mode = 'test_mode' in request.form
    num_files = request.form.get('num_files', '1')
    
    try:
        num_files = int(num_files)
        if num_files < 1:
            num_files = 1
    except:
        num_files = 1
    
    job_id = int(time.time())
    
    # Start a background thread to run the script
    thread = threading.Thread(
        target=run_script_async,
        args=(job_id, test_mode, num_files)
    )
    thread.daemon = True
    thread.start()
    
    flash(f"Log fetching job started. Job ID: {job_id}")
    return redirect(url_for('job_status', job_id=job_id))

@app.route('/job/<int:job_id>')
@login_required
def job_status(job_id):
    """Show status of a specific job"""
    if job_id not in jobs:
        flash("Job not found")
        return redirect(url_for('dashboard'))
    
    job = jobs[job_id]
    
    return render_template('job_status.html',
                          job_id=job_id,
                          status=job['status'],
                          start_time=time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(job['start_time'])),
                          output=job['output'],
                          archive_path=job.get('archive_path'),
                          archive_filename=os.path.basename(job.get('archive_path', '')) if 'archive_path' in job else None)

@app.route('/download/<int:job_id>')
@login_required
def download_archive(job_id):
    """Download the archive file for a completed job"""
    if job_id not in jobs or 'archive_path' not in jobs[job_id]:
        flash("Archive not available")
        return redirect(url_for('dashboard'))
    
    archive_path = jobs[job_id]['archive_path']
    
    if not os.path.exists(archive_path):
        flash("Archive file not found")
        return redirect(url_for('dashboard'))
    
    return send_file(archive_path, as_attachment=True)

@app.route('/download-file/<path:filename>')
@login_required
def download_file(filename):
    """Download a specific archive file by name"""
    try:
        # Get the base directory from config
        config = load_config()
        base_dir = config.get('BASE_DIR', '/home/kburki/KTOO/Harmonic/logs/')
        
        # Construct the full path, but sanitize the filename for security
        safe_filename = os.path.basename(filename)
        file_path = os.path.join(base_dir, safe_filename)
        
        # Verify the file exists and is within the base directory
        if not os.path.exists(file_path) or not os.path.isfile(file_path):
            flash("File not found")
            return redirect(url_for('dashboard'))
        
        # Check if the file is a tar.gz archive and has the expected prefix
        if not (safe_filename.endswith('.tar.gz') and 
                (safe_filename.startswith('harmonic_logs_') or 
                 safe_filename.startswith('harmonic_test_logs_') or
                 safe_filename.startswith('harmonic_recent_logs_'))):
            flash("Invalid file type")
            return redirect(url_for('dashboard'))
        
        # Send the file
        return send_file(file_path, as_attachment=True)
    except Exception as e:
        flash(f"Error downloading file: {str(e)}")
        return redirect(url_for('dashboard'))

@app.route('/users')
@admin_required
def user_management():
    """User management page - admin only"""
    users = load_users()
    return render_template('users.html', users=users)

@app.route('/add_user', methods=['POST'])
@admin_required
def add_user():
    """Add a new user - admin only"""
    username = request.form.get('username')
    password = request.form.get('password')
    confirm_password = request.form.get('confirm_password')
    role = request.form.get('role', 'user')  # Default to regular user
    
    # Validate role
    if role not in ['admin', 'user']:
        role = 'user'
    
    if not username or not password:
        flash("Username and password are required")
        return redirect(url_for('user_management'))
    
    if password != confirm_password:
        flash("Passwords do not match")
        return redirect(url_for('user_management'))
    
    if save_user(username, password, role):
        flash(f"User '{username}' with role '{role}' added successfully")
    else:
        flash("Failed to add user")
    
    return redirect(url_for('user_management'))

if __name__ == '__main__':
    # Ensure the script is executable
    if os.path.exists(SCRIPT_PATH):
        os.chmod(SCRIPT_PATH, 0o755)
    
    # Create the templates directory if it doesn't exist
    template_dir = os.path.join(os.path.dirname(__file__), 'templates')
    if not os.path.exists(template_dir):
        os.makedirs(template_dir)
    
    # Check if all required templates exist
    required_templates = ['base.html', 'login.html', 'setup.html', 'dashboard.html', 
                         'job_status.html', 'users.html']
    missing_templates = [t for t in required_templates if not os.path.exists(os.path.join(template_dir, t))]
    
    if missing_templates:
        print(f"WARNING: The following templates are missing: {', '.join(missing_templates)}")
        print(f"Make sure all template files are in the {template_dir} directory")
    
    # Run the Flask app
    app.run(host='0.0.0.0', port=5001, debug=True)