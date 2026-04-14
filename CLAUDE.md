# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A single Bash script (`sync-from-web.sh`) that synchronizes Pi-hole custom DNS entries from a primary server to secondary instances via HTTP. The script downloads `/custom.list` from a primary Pi-hole, compares it with the local copy, and only replaces it + restarts DNS when changes are detected.

## Running and Debugging

```bash
# Standard run on a secondary Pi-hole
bash sync-from-web.sh

# Verbose trace for debugging
bash -x sync-from-web.sh

# Install to system path
sudo cp sync-from-web.sh /usr/local/bin/sync-from-web.sh
sudo chmod +x /usr/local/bin/sync-from-web.sh

# Recommended cron entry (runs every 15 minutes)
*/15 * * * * /usr/local/bin/sync-from-web.sh >/dev/null 2>&1

# Verify sync results
ls -l /etc/pihole/custom.list

# Check logs
sudo journalctl -t "Pi-Hole Custom DNS Synchronizer"
grep "Pi-Hole Custom DNS Synchronizer" /var/log/syslog
```

## Architecture

**Data flow:** Primary Pi-hole serves `/custom.list` via HTTP (symlinked from `/etc/pihole/custom.list` to `/var/www/html/custom.list`). Secondary Pi-holes run `sync-from-web.sh` to fetch, compare, and conditionally replace their local copy.

```
Primary Pi-hole                     Secondary Pi-hole(s)
/etc/pihole/custom.list  --HTTP-->  download to /tmp/custom.list.download
(symlinked to webroot)              -> cmp vs /etc/pihole/custom.list
                                    -> mv + pihole restartdns (only if changed)
```

## Key Script Variables

Defined at the top of `sync-from-web.sh` — these are the only values that should need changing per deployment:

| Variable | Default | Purpose |
|---|---|---|
| `PRIMARY_PIHOLE_HOST` | `10.0.0.2` | IP/hostname of primary — **edit this** |
| `SOURCE_URL` | derived | `http://${PRIMARY_PIHOLE_HOST}/custom.list` |
| `DEST_FILE` | `/etc/pihole/custom.list` | Target on secondary |
| `TEMP_FILE` | `/tmp/custom.list.download` | Temporary download path |
| `LOG_TAG` | `Pi-Hole Custom DNS Synchronizer` | Syslog tag |

## Conventions to Preserve

- **Download fallback**: Always try `wget -q` first, fall back to `curl -s`. If neither exists, log to syslog and `exit 1`. Do not introduce other download methods.
- **Compare-then-replace**: Use `cmp -s` before overwriting. Never replace the file unconditionally — this avoids unnecessary DNS restarts.
- **Logging**: All messages go to syslog using `logger -t "$LOG_TAG"`. Use the same tag for any new log lines so operators can grep consistently.
- **Temp file cleanup**: Remove `$TEMP_FILE` on both success and failure paths. Never leave artifacts in `/tmp`.
- **Privilege model**: `mv` to `/etc/pihole/` and `pihole restartdns` require `sudo`. Document any changes that affect this.

## When to Seek Review

- Any change that removes the compare-before-replace behavior (i.e., always restarting DNS).
- Adding network retries or timeouts that affect availability.


## User instructions
- never add co-authored or created by Claude