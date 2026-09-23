#!/bin/bash
#
# Retry the OrangeFox sync until it succeeds.
# repo sync is resumable, so a re-run only fetches what is still missing.
# The 429s come from the USTC AOSP mirror when concurrency is too high.
#
LOG=/home/Villode/fox_sync_retry.log
SYNC_DIR=/home/Villode/OrangeFox_sync/sync

# NOTE: orangefox_sync.sh resolves its patches/ directory relative to $0,
# so it MUST be launched from inside its own directory.

echo "==========================================================" | tee -a "$LOG"
echo " Retry-sync started $(date)" | tee -a "$LOG"
echo "==========================================================" | tee -a "$LOG"

for i in 1 2 3 4 5 6 7 8 9 10; do
    echo "" | tee -a "$LOG"
    echo "########## attempt $i - $(date) ##########" | tee -a "$LOG"

    cd "$SYNC_DIR" || exit 1
    ./orangefox_sync.sh --branch 14.1 --path /home/Villode/fox_14.1 >> "$LOG" 2>&1
    rc=$?

    echo "########## attempt $i finished, exit=$rc, $(date) ##########" | tee -a "$LOG"

    if [ "$rc" -eq 0 ]; then
        echo "SYNC-OK" | tee -a "$LOG"
        break
    fi

    echo "-- sleeping 120s before retrying ..." | tee -a "$LOG"
    sleep 120
done

echo "" | tee -a "$LOG"
echo "-- retry-sync finished at $(date)" | tee -a "$LOG"
grep -c "SYNC-OK" "$LOG"
