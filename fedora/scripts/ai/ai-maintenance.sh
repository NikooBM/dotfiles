#!/bin/bash
set -e
LOG="$HOME/logs/ai-maintenance-$(date +%Y%m%d).log"
mkdir -p "$HOME/logs"

echo "=== Mantenimiento IA — $(date) ===" | tee -a "$LOG"

echo "[1/5] Sistema..." | tee -a "$LOG"
sudo dnf update -y >> "$LOG" 2>&1

echo "[2/5] Ollama..." | tee -a "$LOG"
curl -fsSL https://ollama.com/install.sh | sh >> "$LOG" 2>&1
sudo systemctl restart ollama

echo "[3/5] Open WebUI..." | tee -a "$LOG"
podman pull ghcr.io/open-webui/open-webui:main >> "$LOG" 2>&1
systemctl --user restart openwebui

echo "[4/5] Herramientas MCP..." | tee -a "$LOG"
uv self update >> "$LOG" 2>&1 || true

echo "[5/5] Tailscale..." | tee -a "$LOG"
sudo tailscale update >> "$LOG" 2>&1 || true

echo "✓ Mantenimiento completado" | tee -a "$LOG"
echo "  Revisa manualmente: Goose https://github.com/block/goose/releases" | tee -a "$LOG"
