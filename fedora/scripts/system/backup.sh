#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# BACKUP COMPLETO DEL STACK
# Fedora + Hyprland + IA local — Niko
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

FECHA=$(date +%Y%m%d_%H%M)
BACKUP_DIR="$HOME/backup"
DESTINO="$BACKUP_DIR/stack-$FECHA"
LOG="$HOME/logs/backup.log"

mkdir -p "$BACKUP_DIR" "$HOME/logs"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG"
echo "🔒 Backup iniciado: $(date)" | tee -a "$LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG"

# ── 1. Listas del sistema ────────────────────────────────────────
echo "[1/6] Generando listas del sistema..." | tee -a "$LOG"

mkdir -p "$DESTINO/system-info"

# Paquetes DNF instalados
rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort \
  > "$DESTINO/system-info/dnf-packages.txt"

rpm -qa --queryformat '%{NAME}\n' | sort \
  > "$DESTINO/system-info/dnf-packages-names.txt"

# Paquetes Flatpak
flatpak list --app --columns=application 2>/dev/null \
  > "$DESTINO/system-info/flatpak-apps.txt" || echo "(sin flatpaks)" \
  > "$DESTINO/system-info/flatpak-apps.txt"

# Extensiones de VS Code
code --list-extensions 2>/dev/null \
  > "$DESTINO/system-info/vscode-extensions.txt" || echo "(VS Code no encontrado)" \
  > "$DESTINO/system-info/vscode-extensions.txt"

# Modelos de Ollama
ollama list 2>/dev/null \
  > "$DESTINO/system-info/ollama-models.txt" || echo "(Ollama no responde)" \
  > "$DESTINO/system-info/ollama-models.txt"

# Servicios systemd de usuario activos
systemctl --user list-units --state=active --no-pager 2>/dev/null \
  > "$DESTINO/system-info/systemd-user-services.txt"

# Servicios systemd del sistema activos
systemctl list-units --state=active --no-pager 2>/dev/null \
  > "$DESTINO/system-info/systemd-system-services.txt"

# Contenedores Podman
podman ps -a 2>/dev/null \
  > "$DESTINO/system-info/podman-containers.txt"

# Volúmenes Podman
podman volume ls 2>/dev/null \
  > "$DESTINO/system-info/podman-volumes.txt"

# Imágenes Podman
podman images 2>/dev/null \
  > "$DESTINO/system-info/podman-images.txt"

# Paquetes pip globales
pip list 2>/dev/null \
  > "$DESTINO/system-info/pip-packages.txt" || true

# Paquetes npm globales
npm list -g --depth=0 2>/dev/null \
  > "$DESTINO/system-info/npm-global.txt" || true

# Versiones de herramientas clave
{
  echo "=== Versiones del sistema ==="
  echo "Fecha: $(date)"
  echo "Kernel: $(uname -r)"
  echo "Fedora: $(cat /etc/fedora-release 2>/dev/null)"
  echo ""
  echo "=== IA Stack ==="
  echo "Ollama: $(ollama --version 2>/dev/null || echo 'no instalado')"
  echo "Goose: $(goose --version 2>/dev/null || echo 'no instalado')"
  echo "uv: $(uv --version 2>/dev/null || echo 'no instalado')"
  echo ""
  echo "=== Sistema ==="
  echo "Python: $(python3 --version 2>/dev/null)"
  echo "Node: $(node --version 2>/dev/null || echo 'no instalado')"
  echo "Git: $(git --version 2>/dev/null)"
  echo "Docker/Podman: $(podman --version 2>/dev/null)"
  echo ""
  echo "=== GPU ==="
  nvidia-smi --query-gpu=name,driver_version,memory.total \
    --format=csv,noheader 2>/dev/null || echo "nvidia-smi no disponible"
  echo ""
  echo "=== Red ==="
  echo "Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'no conectado')"
  ip -4 addr show | grep inet | awk '{print $2, $NF}'
} > "$DESTINO/system-info/versions.txt"

# Crontab actual
crontab -l 2>/dev/null \
  > "$DESTINO/system-info/crontab.txt" || echo "(sin crontab)" \
  > "$DESTINO/system-info/crontab.txt"

# Variables de entorno relevantes (sin valores sensibles)
env | grep -iE "ollama|goose|path|xdg|wayland|hyprland|goose" \
  | grep -v -iE "token|key|password|secret" \
  > "$DESTINO/system-info/env-vars.txt" || true

echo "    ✓ Listas del sistema generadas" | tee -a "$LOG"

# ── 2. Configuración del sistema ────────────────────────────────
echo "[2/6] Respaldando configuración del sistema..." | tee -a "$LOG"

mkdir -p "$DESTINO/system-config"

# Override de Ollama systemd
cp /etc/systemd/system/ollama.service.d/override.conf \
  "$DESTINO/system-config/ollama-override.conf" 2>/dev/null || true

# Configuración del firewall
sudo firewall-cmd --list-all-zones > \
  "$DESTINO/system-config/firewall-zones.txt" 2>/dev/null || true

# Configuración de SELinux
sestatus > "$DESTINO/system-config/selinux-status.txt" 2>/dev/null || true

echo "    ✓ Configuración del sistema respaldada" | tee -a "$LOG"

# ── 3. Configuración del usuario (~/.config) ────────────────────
echo "[3/6] Respaldando ~/.config..." | tee -a "$LOG"

tar -czf "$DESTINO/config-dotfiles.tar.gz" \
  --exclude="$HOME/.config/chromium" \
  --exclude="$HOME/.config/google-chrome" \
  --exclude="$HOME/.config/BraveSoftware" \
  --exclude="$HOME/.config/Code/Cache" \
  --exclude="$HOME/.config/Code/CachedData" \
  --exclude="$HOME/.config/Code/logs" \
  --exclude="$HOME/.config/pulse" \
  "$HOME/.config" \
  "$HOME/.bashrc" \
  "$HOME/.bash_profile" \
  "$HOME/.zshrc" \
  "$HOME/.zprofile" \
  "$HOME/.profile" \
  "$HOME/.gitconfig" \
  "$HOME/.ssh/config" \
  2>/dev/null || true

echo "    ✓ ~/.config respaldado" | tee -a "$LOG"

# ── 4. Stack de IA ───────────────────────────────────────────────
echo "[4/6] Respaldando stack de IA..." | tee -a "$LOG"

tar -czf "$DESTINO/ai-stack.tar.gz" \
  "$HOME/scripts" \
  "$HOME/.local/share/goose-memory" \
  "$HOME/.config/goose" \
  "$HOME/.continue" \
  "$HOME/.config/containers/systemd" \
  2>/dev/null || true

echo "    ✓ Stack de IA respaldado" | tee -a "$LOG"

# ── 5. Datos de contenedores ────────────────────────────────────
echo "[5/6] Respaldando datos de contenedores..." | tee -a "$LOG"

# Open WebUI (chats, documentos RAG, configuración)
if [ -d "$HOME/containers/openwebui" ]; then
  tar -czf "$DESTINO/openwebui-data.tar.gz" \
    --exclude="$HOME/containers/openwebui/cache" \
    "$HOME/containers/openwebui" 2>/dev/null
  echo "    ✓ Open WebUI respaldado" | tee -a "$LOG"
fi

# n8n (workflows, credenciales)
if podman volume exists n8n-data 2>/dev/null; then
  podman volume export n8n-data > "$DESTINO/n8n-volume.tar" 2>/dev/null
  echo "    ✓ n8n respaldado" | tee -a "$LOG"
elif [ -d "$HOME/containers/n8n" ]; then
  tar -czf "$DESTINO/n8n-data.tar.gz" \
    "$HOME/containers/n8n" 2>/dev/null
  echo "    ✓ n8n (carpeta) respaldado" | tee -a "$LOG"
fi

# ── 6. Empaquetar todo ──────────────────────────────────────────
echo "[6/6] Empaquetando backup completo..." | tee -a "$LOG"

# Crear índice del backup
{
  echo "BACKUP INDEX — $(date)"
  echo "═══════════════════════════════"
  echo ""
  echo "Contenido:"
  ls -lh "$DESTINO/" 2>/dev/null
  echo ""
  echo "Espacio total:"
  du -sh "$DESTINO/"
} > "$DESTINO/BACKUP-INDEX.txt"

# Comprimir todo en un solo archivo
tar -czf "$DESTINO.tar.gz" -C "$BACKUP_DIR" "stack-$FECHA"
rm -rf "$DESTINO"

TAMANO=$(du -sh "$DESTINO.tar.gz" | cut -f1)

# Mantener solo los últimos 5 backups completos
ls -t "$BACKUP_DIR"/stack-*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f

TOTAL=$(ls "$BACKUP_DIR"/stack-*.tar.gz 2>/dev/null | wc -l)

echo "" | tee -a "$LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG"
echo "✅ Backup completado: $(date)" | tee -a "$LOG"
echo "📦 Archivo: $DESTINO.tar.gz ($TAMANO)" | tee -a "$LOG"
echo "📁 Backups guardados: $TOTAL/5" | tee -a "$LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG"
