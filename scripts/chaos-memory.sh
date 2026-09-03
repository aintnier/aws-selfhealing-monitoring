#!/bin/bash
# ─────────────────────────────────────────────────────────
# Chaos Test 3 — Memory Leak
# Alloca memoria massivamente per simulare un memory leak
# Soglia allarme: Memory > 85% per 3 periodi da 60s
# ─────────────────────────────────────────────────────────

DURATION=${1:-300}

echo "[CHAOS] Scenario 3: Memory Leak"
echo "[CHAOS] Allocating 90% of RAM for ${DURATION}s..."

stress-ng --vm 1 --vm-bytes 90% --vm-keep --timeout ${DURATION}s

echo "[CHAOS] Memory stress test completed."
