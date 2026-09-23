#!/bin/bash
# PixelOS 17 (custom_TB375FC) build monitor -- READ ONLY.
# Usage: bash mon_build.sh [SAMPLES] [INTERVAL_SECONDS] [LOG_PATH]
#   LOG_PATH defaults to /home/Villode/pixelos17-build.log
#   (use /home/Villode/pixelos17-ota.log when watching `m otapackage`)
#
# NOTE: run_build17.sh appends "BUILD_DONE" to the log UNCONDITIONALLY after `m`
# exits, so BUILD_DONE alone does NOT mean success.  Success is only reported
# here when the marker is present AND no failure signature is found.
LOG=${3:-/home/Villode/pixelos17-build.log}
SAMPLES=${1:-1}
INTERVAL=${2:-100}

snap() {
  echo "----- $(date '+%H:%M:%S') -----"

  PHASE=""
  pgrep -x soong_build >/dev/null && PHASE="$PHASE Soong-analysis"
  pgrep -x ckati       >/dev/null && PHASE="$PHASE Kati/Make"
  pgrep -x siso        >/dev/null && PHASE="$PHASE ninja-compile(siso)"
  pgrep -x ninja       >/dev/null && PHASE="$PHASE ninja"
  pgrep -x soong_ui    >/dev/null || PHASE="$PHASE [soong_ui-exited]"
  echo "PHASE:${PHASE:- unknown}"

  for p in soong_build ckati siso ninja; do
    PID=$(pgrep -x "$p" | head -1)
    [ -z "$PID" ] && continue
    CPU=$(ps -o time= -p "$PID" 2>/dev/null | tr -d ' ')
    RSS=$(awk '/^VmRSS/{print $2}' /proc/"$PID"/status 2>/dev/null)
    SWP=$(awk '/^VmSwap/{print $2}' /proc/"$PID"/status 2>/dev/null)
    echo "  $p pid=$PID cpu=$CPU rss=$(( ${RSS:-0} /1024 ))M swap=$(( ${SWP:-0} /1024 ))M"
  done

  echo "  log: size=$(stat -c %s "$LOG" 2>/dev/null) mtime=$(stat -c %y "$LOG" 2>/dev/null | cut -c12-19)"
  echo "  last_progress: $(grep -oE '^\[ *[0-9]+% [0-9]+/[0-9]+\]' "$LOG" 2>/dev/null | tail -1)"
  echo "  tail: $(tail -1 "$LOG" 2>/dev/null | cut -c1-110)"

  FAILED=$(grep -cE '^FAILED: ' "$LOG" 2>/dev/null)
  STOPPED=$(grep -cE '^ninja: build stopped|failed to build some targets' "$LOG" 2>/dev/null)
  DONE=$(grep -c 'BUILD_DONE' "$LOG" 2>/dev/null)
  EXITFAIL=$(grep -c 'BUILD_FAILED' "$LOG" 2>/dev/null)
  echo "  markers: FAILED=$FAILED STOPPED=$STOPPED BUILD_DONE=$DONE BUILD_FAILED=$EXITFAIL"
  if [ "${EXITFAIL:-0}" -gt 0 ]; then
    echo "  *** m EXITED NON-ZERO -> BUILD FAILED ***"
    grep -E '^BUILD_FAILED' "$LOG" 2>/dev/null | head -1 | sed 's/^/  /'
    grep -E '^FAILED: ' "$LOG" 2>/dev/null | grep -v 'ninja: ' | head -3 | sed 's/^/  FAILED> /'
  elif [ "${DONE:-0}" -gt 0 ]; then
    if [ "${FAILED:-0}" -eq 0 ] && [ "${STOPPED:-0}" -eq 0 ]; then
      echo "  *** BUILD SUCCEEDED (m rc=0) ***"
    else
      echo "  *** m exited 0 but failure text present - inspect ***"
      grep -E '^FAILED: ' "$LOG" 2>/dev/null | grep -v 'ninja: ' | head -3 | sed 's/^/  FAILED> /'
    fi
  fi
  grep -E '^ninja: build stopped' "$LOG" 2>/dev/null | head -1 | sed 's/^/  STOPPED> /'

  echo "  mem: $(free -m | awk '/^Mem:/{print $3"MB used / "$7"MB avail"}')  swap_used=$(free -m | awk '/^Swap:/{print $3}')MB"
  echo "  load: $(cut -d' ' -f1-3 /proc/loadavg)"
}

for i in $(seq 1 "$SAMPLES"); do
  snap
  if [ "$i" -lt "$SAMPLES" ]; then sleep "$INTERVAL"; fi
done
