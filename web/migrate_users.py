#!/usr/bin/env python3
"""
Migration script to update existing users to the new format with roles.
This script will convert old format (username=hash) to new format (username:role=hash)
"""
import os
import sys

# Configuration
WEB_USERS_CONFIG = "/home/kburki/KTOO/Harmonic/web_users.cfg"

def main():
    # Check if the file exists
    if not os.path.exists(WEB_USERS_CONFIG):
        print(f"Error: Configuration file {WEB_USERS_CONFIG} not found.")
        return False
    
    # Read current users
    try:
        with open(WEB_USERS_CONFIG, 'r') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading file: {e}")
        return False
    
    # Make backup
    backup_file = f"{WEB_USERS_CONFIG}.bak"
    try:
        with open(backup_file, 'w') as f:
            f.writelines(lines)
        print(f"Backup created at {backup_file}")
    except Exception as e:
        print(f"Error creating backup: {e}")
        return False
    
    # Process and update users
    new_lines = []
    users_migrated = 0
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            # Keep comments and empty lines unchanged
            new_lines.append(line + '\n')
            continue
        
        # Check if already in new format
        if ':' in line.split('=')[0]:
            new_lines.append(line + '\n')
            continue
        
        # Convert to new format - make first user admin, others regular
        try:
            username, hash_value = line.split('=', 1)
            if users_migrated == 0:
                # First user becomes admin
                new_line = f"{username.strip()}:admin={hash_value.strip()}\n"
                role = "admin"
            else:
                # Others become regular users
                new_line = f"{username.strip()}:user={hash_value.strip()}\n"
                role = "user"
                
            new_lines.append(new_line)
            print(f"Migrated user '{username.strip()}' to role '{role}'")
            users_migrated += 1
        except Exception as e:
            print(f"Error processing line '{line}': {e}")
            # Keep the original line if there's an error
            new_lines.append(line + '\n')
    
    # Add header if not present
    has_format_comment = False
    for line in new_lines:
        if "Format: username:role=" in line:
            has_format_comment = True
            break
    
    if not has_format_comment:
        header_index = -1
        for i, line in enumerate(new_lines):
            if "Web users configuration" in line:
                header_index = i + 1
                break
        
        if header_index >= 0:
            new_lines.insert(header_index, "# Format: username:role=password_hash\n")
        else:
            new_lines.insert(0, "# Web users configuration for Harmonic Log Fetcher\n")
            new_lines.insert(1, "# Format: username:role=password_hash\n")
    
    # Write updated file
    try:
        with open(WEB_USERS_CONFIG, 'w') as f:
            f.writelines(new_lines)
        print(f"Successfully migrated {users_migrated} users to the new format")
        return True
    except Exception as e:
        print(f"Error writing file: {e}")
        print("Restoring from backup...")
        try:
            with open(backup_file, 'r') as f_backup:
                with open(WEB_USERS_CONFIG, 'w') as f:
                    f.write(f_backup.read())
            print("Restored from backup")
        except Exception as e2:
            print(f"Error restoring from backup: {e2}")
        return False

if __name__ == "__main__":
    print("User Migration Script")
    print("=====================")
    print("This script will update your existing users to use the new role-based format.")
    print("A backup of your current users file will be created before making changes.")
    
    proceed = input("Do you want to proceed? (y/n): ")
    if proceed.lower() in ('y', 'yes'):
        if main():
            print("Migration completed successfully")
        else:
            print("Migration failed")
    else:
        print("Migration aborted")