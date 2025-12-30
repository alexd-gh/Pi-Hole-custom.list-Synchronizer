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

# --- Message Variables ---
ERR_NO_TOOL="Error: Neither wget nor curl is installed. Please install one of them."
MSG_CHANGE_DETECTED="Change detected. Updating local custom.list."
MSG_DNS_RESTARTED="DNS service restarted successfully."
MSG_NO_CHANGES="No changes detected in custom.list."
ERR_DOWNLOAD_FAILED="Failed to download custom.list from ${PRIMARY_PIHOLE_HOST}."
LOG_TAG="Pi-Hole Custom DNS Synchronizer"

# 1. Download the file from the primary server's web page.
#    Try wget first (quiet mode), fall back to curl if wget is not available.
if command -v wget &> /dev/null; then
    wget -q -O "$TEMP_FILE" "$SOURCE_URL"
elif command -v curl &> /dev/null; then
    curl -s -o "$TEMP_FILE" "$SOURCE_URL"
else
    echo "$ERR_NO_TOOL"
    logger -t "$LOG_TAG" -p user.err "$ERR_NO_TOOL"
    exit 1
fi

# 2. Check if the download was successful and if the downloaded file is not empty.
if [ $? -eq 0 ] && [ -s "$TEMP_FILE" ]; then
    # 3. Compare the new file with the existing one. The 'cmp' command is silent.
    #    Proceed only if the files are different.
    if ! cmp -s "$TEMP_FILE" "$DEST_FILE"; then
        echo "$MSG_CHANGE_DETECTED"
        logger -t "$LOG_TAG" "$MSG_CHANGE_DETECTED"
        # 4. Overwrite the old file with the new one. Sudo is needed for this.
        sudo mv "$TEMP_FILE" "$DEST_FILE"
        # 5. Restart the DNS service to apply the new list.
        sudo pihole restartdns
        echo "$MSG_DNS_RESTARTED"
        logger -t "$LOG_TAG" "$MSG_DNS_RESTARTED"
    else
        # Files are the same, no action needed. Just clean up the temp file.
        echo "$MSG_NO_CHANGES"
        logger -t "$LOG_TAG" "$MSG_NO_CHANGES"
        rm "$TEMP_FILE"
    fi
else
    echo "$ERR_DOWNLOAD_FAILED"
    logger -t "$LOG_TAG" -p user.err "$ERR_DOWNLOAD_FAILED"
    # Clean up failed download if it exists
    [ -f "$TEMP_FILE" ] && rm "$TEMP_FILE"
fi

exit 0
