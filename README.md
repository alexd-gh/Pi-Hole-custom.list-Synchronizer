# Pi-Hole custom.list Synchronizer

Small shell script to fetch and synchronize custom DNS lists for Pi-hole.

## Repository

This repository contains a single script:

- `sync-from-web.sh` — fetches remote custom.list and updates local Pi-hole custom.list file.

## Requirements

- Bash (Linux/macOS/WSL)
- `wget` or `curl` (the script will use whichever is available)

## How It Works

The `sync-from-web.sh` script synchronizes custom DNS entries from a primary Pi-hole server to secondary Pi-hole instances. It:

1. **Downloads** the custom.list file from the primary server via HTTP
2. **Compares** the downloaded file with the local copy to detect changes
3. **Updates** the local custom list only if differences are detected
4. **Restarts** the DNS service to apply new rules

### Script Flow

- **Downloads** `custom.list` from the primary Pi-hole via HTTP:
  - Attempts `wget -q` (quiet mode) first if available
  - Falls back to `curl -s` (silent mode) if wget is not installed
  - Exits with error if neither tool is available
- **Validates** the download was successful and the file is non-empty
- **Compares** the new file with the existing local copy using `cmp` (silent mode)
- If **changes are detected**:
  - Replaces the old custom list with the downloaded file
  - Restarts Pi-hole DNS service (`sudo pihole restartdns`)
- If **no changes detected** or **download fails**:
  - Cleans up temporary files automatically

## Setup Instructions

### 1. Symlink custom.list (on primary server)

Run this command on your **primary Pi-hole server** to expose the custom list via HTTP:

```bash
ln -s /etc/pihole/custom.list /var/www/html/custom.list
```

**Note:** Pi-hole uses **lighttpd** as its web server. The symlink places the custom list file in the lighttpd web root directory (`/var/www/html/`), making it accessible via HTTP on the primary server.

### 2. Install script into secondary server(s)

SSH into the secondary Pi-hole server and create the file:

```bash
ssh pi@<secondary-pihole>
sudo nano /usr/local/bin/sync-from-web.sh
```

Then paste the script content, save with `Ctrl+O`, press Enter, and exit with `Ctrl+X`. Finally, make it executable:

```bash
sudo chmod +x /usr/local/bin/sync-from-web.sh
```

### 3. Configure the primary server IP

Edit the script and update this line with your primary Pi-hole IP or hostname:

```bash
PRIMARY_PIHOLE_HOST="10.0.0.2"  # Change this to your primary Pi-hole
```

### 4. Create a cron job (optional but recommended)

Run the script automatically every 15 minutes:

```bash
# Create the crontab file if it doesn't exist
sudo touch /var/spool/cron/crontabs/root
sudo chmod 600 /var/spool/cron/crontabs/root

# Add the following line to the crontab:
*/15 * * * * /usr/local/bin/sync-from-web.sh >/dev/null 2>&1
```

Or use `crontab -e` and add:

```
*/15 * * * * /usr/local/bin/sync-from-web.sh >/dev/null 2>&1
```

## Usage

### Manual Execution

Run the script manually on any secondary Pi-hole server:

```bash
bash sync-from-web.sh
```

### Automated Execution

Once the cron job is set up, the script will run automatically every 15 minutes. To verify synchronization, check the timestamp of the custom.list file:

```bash
# Check when custom.list was last modified
stat /etc/pihole/custom.list

# Or check the file's modification time
ls -l /etc/pihole/custom.list
```

To troubleshoot, run the script manually with output to see if it executes correctly:

```bash
sudo /usr/local/bin/sync-from-web.sh
```

### Checking Syslog Messages

The script logs all activity to syslog. To view the messages:

```bash
# View recent syslog messages from the script
sudo grep "Pi-Hole Custom DNS Synchronizer" /var/log/syslog

# Or use journalctl for systemd-based systems
sudo journalctl -t "Pi-Hole Custom DNS Synchronizer"

# Follow logs in real-time
sudo tail -f /var/log/syslog | grep "Pi-Hole Custom DNS Synchronizer"
```

## Requirements

- **Primary Server**: Bash and web server access to `/var/www/html/`
- **Secondary Server(s)**: 
  - Bash shell
  - `wget` or `curl` for downloads
  - `sudo` privileges for DNS restart
  - Network access to primary Pi-hole server

## Notes

- The script uses `wget -q` (quiet mode) for downloads by default
- Falls back to `curl -s` (silent mode) if wget is not available
- Temporary files are cleaned up automatically on success or failure
- DNS service is only restarted if changes are detected (more efficient)
- Suitable for Pi-hole multi-device setups with a primary and secondary instances
- Ensure firewall rules allow HTTP access to the primary server on port 80
- **All script activity is logged to syslog** with the tag "Pi-Hole Custom DNS Synchronizer" for monitoring and troubleshooting

## License

This project is available under the terms of the LICENSE file in this repository.
