#!/bin/bash
# ─────────────────────────────────────────────────────────
# Chaos Test 1 — Container Crash (Nginx Down)
# Simula il crash del servizio web arrestando il container
# ─────────────────────────────────────────────────────────

echo "[CHAOS] Scenario 1: Application Crash"
echo "[CHAOS] Stopping Nginx container..."

docker stop nginx

echo "[CHAOS] Nginx container stopped."
echo "[CHAOS] The self-healing system should detect and restart it."
