#!/usr/bin/env bash
set -u

# Load environment variables if .env exists locally
[ -f .env ] && export $(grep -v '^#' .env | xargs)

DASHCAM_IP="${DASHCAM_IP:-192.168.1.150}"
DASHCAM_FTP_USER="${DASHCAM_FTP_USER:-root}"
DASHCAM_FTP_PASS="${DASHCAM_FTP_PASS:-}"
REMOTE_PATH="${REMOTE_PATH:-/mnt/sdcard/DCIM}"
LOCAL_BACKUP_DIR="${LOCAL_BACKUP_DIR:-./backups}"
POLL_INTERVAL="${POLL_INTERVAL_SECONDS:-30}"
COOLDOWN="${COOLDOWN_AFTER_SYNC_SECONDS:-1800}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

mkdir -p "$LOCAL_BACKUP_DIR"

echo "[INFO] Starting 70mai Auto-Sync watcher for IP: $DASHCAM_IP..."

while true; do
    # 1. Check if the dashcam is reachable on the home Wi-Fi
    if ping -c 1 -W 2 "$DASHCAM_IP" > /dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dashcam detected online at $DASHCAM_IP! Starting FTP sync..."
        ./src/notify.sh "Dashcam connected to home Wi-Fi. Starting video backup..."

        START_TIME=$(date +%s)

        # 2. Mirror only newer files using lftp (2 parallel streams to avoid overwhelming camera CPU)
        lftp -u "$DASHCAM_FTP_USER","$DASHCAM_FTP_PASS" "ftp://$DASHCAM_IP" <<EOF
set net:timeout 10
set net:max-retries 3
set net:reconnect-interval-base 5
set ftp:passive-mode on
mirror --continue --only-newer --parallel=2 --verbose "$REMOTE_PATH" "$LOCAL_BACKUP_DIR"
bye
EOF

        SYNC_STATUS=$?
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))

        if [ $SYNC_STATUS -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sync completed successfully in ${DURATION}s."
            ./src/notify.sh "Backup completed in ${DURATION}s."
        else
            echo "[WARN] Sync interrupted or exited with code $SYNC_STATUS (dashcam may have powered off)."
            ./src/notify.sh "Backup paused/interrupted after ${DURATION}s (dashcam likely powered down)."
        fi

        # 3. Prune local backups older than RETENTION_DAYS (if enabled)
        if [ "$RETENTION_DAYS" -gt 0 ]; then
            echo "[INFO] Pruning local videos older than $RETENTION_DAYS days..."
            find "$LOCAL_BACKUP_DIR" -type f \( -name "*.mp4" -o -name "*.MP4" \) -mtime +"$RETENTION_DAYS" -delete
        fi

        # 4. Cooldown so we don't repeatedly hammer the dashcam while parked
        echo "[INFO] Entering cooldown for ${COOLDOWN}s..."
        sleep "$COOLDOWN"
    else
        sleep "$POLL_INTERVAL"
    fi
done
