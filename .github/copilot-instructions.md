## Purpose

This repository contains a single utility: a shell script (`sync-from-web.sh`) that
fetches a `custom.list` file from a primary Pi-hole server and synchronizes it to a
secondary Pi-hole instance. The guidance below helps an AI coding agent reason about
the architecture, important conventions, and concrete examples to make safe, useful
changes quickly.

## Big picture (architecture & data flow)

- Primary Pi-hole: serves `/custom.list` from the webroot (`/var/www/html/custom.list`)
  (typically exposed via a symlink to `/etc/pihole/custom.list`). See README instructions
  for the `ln -s` command.
- Secondary Pi-hole(s): run `sync-from-web.sh` to HTTP GET the file from the primary,
  compare it with the local `/etc/pihole/custom.list`, and replace + restart DNS only
  when changes are detected. This minimizes unnecessary DNS restarts.

Data flow summary: primary (HTTP file) -> download (/tmp/custom.list.download) -> cmp
vs `/etc/pihole/custom.list` -> mv -> `pihole restartdns`.

## Key files & variables to reference

- `sync-from-web.sh` — the single script implementing the sync logic. Important variables:
  - `PRIMARY_PIHOLE_HOST` — edit this to change the source host (e.g. `10.0.0.2`).
  - `SOURCE_URL` — built from `PRIMARY_PIHOLE_HOST` (`http://${PRIMARY_PIHOLE_HOST}/custom.list`).
  - `DEST_FILE` — `/etc/pihole/custom.list` (target on secondaries).
  - `TEMP_FILE` — `/tmp/custom.list.download` (temporary download path).
  - `LOG_TAG` — `Pi-Hole Custom DNS Synchronizer` (syslog tag used by `logger`).
- `README.md` — contains setup, architecture diagrams, and common commands (symlink, cron, troubleshooting).

## Project-specific conventions and patterns

- Download tools: script prefers `wget -q` then falls back to `curl -s`. If neither exists,
  it logs an error and exits with code 1. Changes should preserve this fallback behavior.
- File comparison: uses `cmp -s` (silent). Only on difference does the script `mv` the temp file
  into `/etc/pihole/custom.list` and restart DNS. Keep the "compare-then-replace" pattern to
  avoid unnecessary restarts.
- Logging: all messages are sent to syslog with the tag `Pi-Hole Custom DNS Synchronizer` via
  `logger`. Use the same tag when adding log lines so operators can grep logs consistently.
- Cleanup: temporary download files under `/tmp` are removed on both success and failure.

## Developer workflows (how to run / test / debug)

- Manual run (quick test): run `bash sync-from-web.sh` on a secondary to see behavior.
- Debugging (verbose): run `bash -x sync-from-web.sh` to trace shell execution if troubleshooting.
- Install on secondary: copy the script to `/usr/local/bin/`, `chmod +x`, then run manually or via cron.
- Cron example (recommended): `*/15 * * * * /usr/local/bin/sync-from-web.sh >/dev/null 2>&1`
- Verify results:
  - Check file modification: `ls -l /etc/pihole/custom.list` or `stat /etc/pihole/custom.list`.
  - Check logs: `sudo journalctl -t "Pi-Hole Custom DNS Synchronizer"` or `grep "Pi-Hole Custom DNS Synchronizer" /var/log/syslog`.

## Edge cases and error modes to preserve

- Missing download tools: error out and log (do not invent a new downloader).
- Empty or failed download: remove temp file and log failure; do not overwrite `DEST_FILE`.
- Permission requirements: `mv` and `pihole restartdns` require elevated privileges. The README documents
  running the script with `sudo` or via root cron. If changing behavior, explicitly handle privilege escalation.

## Safe change checklist for PRs

When modifying or extending `sync-from-web.sh`, ensure:

1. Behavior-preserving: keep the download fallback (wget -> curl) and the `cmp -s` compare-then-replace
   pattern unless you have a strong reason and update README.
2. Logging: use the same `LOG_TAG` when writing log lines so operators don't lose grepability.
3. Temp file behavior: always remove or move the temp file; avoid leaving artifacts in `/tmp`.
4. Privilege model: document any changes that alter which commands require `sudo` or root.
5. Tests: validate by running the script against a local webserver that serves a test `custom.list` and
   verify logs, file replacement, and `pihole restartdns` side effects (can be stubbed during testing).

## Examples (concrete snippets found in repo)

- Change the primary host (edit at top of file):
  PRIMARY_PIHOLE_HOST="10.0.0.2"  # change to your primary

- Download fallback in the script (preserve this pattern):
  if command -v wget &> /dev/null; then
      wget -q -O "$TEMP_FILE" "$SOURCE_URL"
  elif command -v curl &> /dev/null; then
      curl -s -o "$TEMP_FILE" "$SOURCE_URL"
  else
      logger -t "$LOG_TAG" -p user.err "Error: Neither wget nor curl is installed."
      exit 1
  fi

## When to ask for human review

- Any change that alters the restart behavior (e.g., always restart DNS instead of only-on-change).
- Adding network retries/timeouts that affect availability—these require operational review.

---

If anything here is unclear or you want more specific guidance (for example, adding unit tests or
stubbing `pihole restartdns` for CI), tell me which area and I will iterate. 
