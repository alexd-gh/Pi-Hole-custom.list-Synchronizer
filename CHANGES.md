# Changes Made to sync-from-web.sh

## Summary

This document outlines the changes made to the `sync-from-web.sh` script to improve its robustness and error handling while maintaining all existing functionality.

## Changes

### 1. Fixed Race Condition in File Comparison

**Issue**: The script didn't properly handle cases where the destination file didn't exist. When `cmp -s` was used to compare a non-existent destination file with the downloaded file, it would fail.

**Fix**: Added a check to determine if the destination file exists before comparison:
```bash
if [ ! -f "$DEST_FILE" ] || ! cmp -s "$TEMP_FILE" "$DEST_FILE"; then
```

This ensures that if the destination file doesn't exist, the script treats it as a change and proceeds with the update.

### 2. Enhanced Error Handling for Sudo Operations

**Issue**: The script didn't validate that `sudo mv` and `sudo pihole restartdns` operations succeeded.

**Fix**: Added validation for both operations:
```bash
# Validate move operation
if ! sudo mv "$TEMP_FILE" "$DEST_FILE"; then
    echo "$ERR_MOVE_FAILED"
    logger -t "$LOG_TAG" -p user.err "$ERR_MOVE_FAILED"
    rm "$TEMP_FILE"
    exit 1
fi

# Validate restart operation  
if ! sudo pihole restartdns; then
    echo "$ERR_RESTART_FAILED"
    logger -t "$LOG_TAG" -p user.err "$ERR_RESTART_FAILED"
    exit 1
fi
```

### 3. Added New Error Messages

Added two new error messages for better diagnostics:
- `ERR_MOVE_FAILED`: "Failed to move downloaded file to destination."
- `ERR_RESTART_FAILED`: "Failed to restart DNS service."

## Preservation of Existing Functionality

All changes maintain the script's core behavior:
- Download fallback: tries `wget` first, falls back to `curl`
- Compare-then-replace: only updates when changes are detected
- Logging: all messages go to syslog with consistent tag
- Temp file cleanup: removes temporary files on success and failure
- Privilege model: uses `sudo` for operations requiring elevated permissions

## Compliance with Project Guidelines

The changes ensure compliance with the project's conventions:
- Maintains the download fallback pattern
- Preserves compare-then-replace behavior
- Keeps syslog logging consistent
- Ensures temp file cleanup on all paths
- Maintains the privilege model with sudo usage