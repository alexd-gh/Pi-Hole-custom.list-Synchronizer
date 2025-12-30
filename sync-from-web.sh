#!/bin/bash
# sync-from-web.sh
# This script syncs the custom.list file from a primary Pi-hole server's web interface
# to a secondary Pi-hole server. It downloads the file, checks for changes, and updates
# the local copy if necessary, followed by a DNS service restart.

#Config
PRIMARY_PIHOLE_HOST="10.0.0.2" # IMPORTANT: Change to the IP or hostname of your PRIMARY pihole

# --- Script Variables ---
SOURCE_URL="http://${PRIMARY_PIHOLE_HOST}/custom.list"
DEST_FILE="/etc/pihole/custom.list"
TEMP_FILE="/tmp/custom.list.download"

# 1. Download the file from the primary server's web page.
#    Try wget first (quiet mode), fall back to curl if wget is not available.
if command -v wget &> /dev/null; then
    wget -q -O "$TEMP_FILE" "$SOURCE_URL"
elif command -v curl &> /dev/null; then
    curl -s -o "$TEMP_FILE" "$SOURCE_URL"
else
    echo "Error: Neither wget nor curl is installed. Please install one of them."
    exit 1
fi

# 2. Check if the download was successful and if the downloaded file is not empty.
if [ $? -eq 0 ] && [ -s "$TEMP_FILE" ]; then
    # 3. Compare the new file with the existing one. The 'cmp' command is silent.
    #    Proceed only if the files are different.
    if ! cmp -s "$TEMP_FILE" "$DEST_FILE"; then
        echo "Change detected on $(date). Updating local custom.list."
        # 4. Overwrite the old file with the new one. Sudo is needed for this.
        sudo mv "$TEMP_FILE" "$DEST_FILE"
        # 5. Restart the DNS service to apply the new list.
        sudo pihole restartdns
    else
        # Files are the same, no action needed. Just clean up the temp file.
        rm "$TEMP_FILE"
    fi
else
    echo "Failed to download custom.list from ${PRIMARY_PIHOLE_HOST} on $(date)."
    # Clean up failed download if it exists
    [ -f "$TEMP_FILE" ] && rm "$TEMP_FILE"
fi

exit 0
