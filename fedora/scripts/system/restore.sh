#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# RESTAURAR DESDE BACKUP
# Uso: ./restore.sh ~/backup/stack-FECHA.tar.gz [componente]
#
# Componentes disponibles:
#   all          → todo (por defecto)
#   config       → solo ~/.config y dotfiles
#   ai           → solo stack de IA (goose, continue, scripts)
#   containers   → solo datos de contenedores
#   info         → mostrar contenido del backup sin restaurar
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

BACKUP_FILE="${1:-}"
COMPONENTE="${2:-all}"

# ── Validaciones ────────────────────────────────────────────────
if [ -z "$BACKUP_FILE" ]; then
  echo "Uso: $0 <archivo-backup.tar.gz> [componente]"
  echo ""
  echo "Backups disponibles:"
  ls -lht ~/backup/stack-*.tar.gz 2>/dev/null || echo "  (ninguno encontrado en ~/backup/)"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Archivo no encontrado: $BACKUP_FILE"
  exit 1
fi

# ── Mostrar contenido ───────────────────────────────────────────
if [ "$COMPONENTE" = "info" ]; then
  echo "📦 Contenido de: $BACKUP_FILE"
  echo ""
  tar -tzf "$BACKUP_FILE" | head -50
  echo ""
  echo "Tamaño total: $(du -sh "$BACKUP_FILE" | cut -f1)"
  exit 0
fi

# ── Extraer backup ──────────────────────────────────────────────
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "📂 Extrayendo backup..."
tar -xzf "$BACKUP_FILE" -C "$TMPDIR"
BACKUP_ROOT=$(ls "$TMPDIR")
BACKUP_PATH="$TMPDIR/$BACKUP_ROOT"

echo "✓ Extraído en: $BACKUP_PATH"
echo ""

# ── Mostrar índice ──────────────────────────────────────────────
if [ -f "$BACKUP_PATH/BACKUP-INDEX.txt" ]; then
  cat "$BACKUP_PATH/BACKUP-INDEX.txt"
  echo ""
fi

# ── Confirmar ───────────────────────────────────────────────────
echo "⚠️  Vas a restaurar: $COMPONENTE"
echo "   Esto sobreescribirá archivos existentes."
read -rp "¿Continuar? (s/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
  echo "Cancelado."
  exit 0
fi

# ── Restaurar ───────────────────────────────────────────────────
restaurar_config() {
  if [ -f "$BACKUP_PATH/config-dotfiles.tar.gz" ]; then
    echo "→ Restaurando ~/.config y dotfiles..."
    tar -xzf "$BACKUP_PATH/config-dotfiles.tar.gz" -C /
    echo "  ✓ Configuración restaurada"
  fi
}

restaurar_ai() {
  if [ -f "$BACKUP_PATH/ai-stack.tar.gz" ]; then
    echo "→ Restaurando stack de IA..."
    tar -xzf "$BACKUP_PATH/ai-stack.tar.gz" -C /
    echo "  ✓ Stack de IA restaurado"
  fi
}

restaurar_containers() {
  if [ -f "$BACKUP_PATH/openwebui-data.tar.gz" ]; then
    echo "→ Restaurando Open WebUI..."
    systemctl --user stop openwebui 2>/dev/null || true
    tar -xzf "$BACKUP_PATH/openwebui-data.tar.gz" -C /
    systemctl --user start openwebui 2>/dev/null || true
    echo "  ✓ Open WebUI restaurado"
  fi

  if [ -f "$BACKUP_PATH/n8n-volume.tar" ]; then
    echo "→ Restaurando n8n (volumen)..."
    systemctl --user stop n8n 2>/dev/null || true
    podman volume create n8n-data 2>/dev/null || true
    podman volume import n8n-data "$BACKUP_PATH/n8n-volume.tar"
    systemctl --user start n8n 2>/dev/null || true
    echo "  ✓ n8n restaurado"
  elif [ -f "$BACKUP_PATH/n8n-data.tar.gz" ]; then
    echo "→ Restaurando n8n (carpeta)..."
    systemctl --user stop n8n 2>/dev/null || true
    tar -xzf "$BACKUP_PATH/n8n-data.tar.gz" -C /
    systemctl --user start n8n 2>/dev/null || true
    echo "  ✓ n8n restaurado"
  fi
}

mostrar_info_sistema() {
  echo ""
  echo "📋 Info del sistema en el momento del backup:"
  echo ""
  if [ -f "$BACKUP_PATH/system-info/versions.txt" ]; then
    cat "$BACKUP_PATH/system-info/versions.txt"
  fi
  echo ""
  echo "📦 Modelos Ollama que había:"
  cat "$BACKUP_PATH/system-info/ollama-models.txt" 2>/dev/null || true
  echo ""
  echo "💻 Extensiones VS Code:"
  cat "$BACKUP_PATH/system-info/vscode-extensions.txt" 2>/dev/null || true
}

case "$COMPONENTE" in
  all)
    restaurar_config
    restaurar_ai
    restaurar_containers
    mostrar_info_sistema
    ;;
  config)
    restaurar_config
    ;;
  ai)
    restaurar_ai
    ;;
  containers)
    restaurar_containers
    ;;
  info-sistema)
    mostrar_info_sistema
    ;;
  *)
    echo "❌ Componente desconocido: $COMPONENTE"
    echo "Opciones: all, config, ai, containers, info, info-sistema"
    exit 1
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Restauración completada"
echo "   Reinicia la sesión para aplicar cambios de configuración"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
