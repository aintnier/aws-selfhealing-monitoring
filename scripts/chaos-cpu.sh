#!/bin/bash
# ─────────────────────────────────────────────────────────
# Chaos Test 2 — CPU Overload
# Genera carico CPU artificiale con stress-ng per 5 minuti
# Soglia allarme: CPU > 80% per 2 periodi da 60s
# ─────────────────────────────────────────────────────────

DURATION=${1:-300}

echo "[CHAOS] Scenario 2: CPU Overload"
echo "[CHAOS] Saturating CPU for ${DURATION}s with stress-ng..."

stress-ng --cpu 0 --timeout ${DURATION}s

echo "[CHAOS] CPU stress test completed."
