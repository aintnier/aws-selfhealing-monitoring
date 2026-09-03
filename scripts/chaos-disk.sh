#!/bin/bash
# ─────────────────────────────────────────────────────────
# Chaos Test 4 — Disk Full
# Riempie il disco con un file di grandi dimensioni
# Soglia allarme: Disk > 85% per 2 periodi da 300s
# ─────────────────────────────────────────────────────────

BLOAT_FILE="/tmp/chaos-disk-bloat"

echo "[CHAOS] Scenario 4: Disk Full"

# Calcola spazio necessario per superare l'85%
TOTAL_KB=$(df / | tail -1 | awk '{print $2}')
USED_KB=$(df / | tail -1 | awk '{print $3}')
TARGET_KB=$(( (TOTAL_KB * 90) / 100 ))
FILL_KB=$(( TARGET_KB - USED_KB ))

if [ "$FILL_KB" -le 0 ]; then
  echo "[CHAOS] Disk already above target. Nothing to do."
  exit 0
fi

FILL_MB=$(( FILL_KB / 1024 ))
echo "[CHAOS] Creating ${FILL_MB}MB bloat file to reach ~90% disk usage..."

dd if=/dev/zero of="$BLOAT_FILE" bs=1M count=$FILL_MB status=progress 2>&1

echo "[CHAOS] Disk filled. Current usage:"
df -h /
echo "[CHAOS] The self-healing system should detect and clean up."
echo "[CHAOS] To manually clean: rm -f $BLOAT_FILE"
