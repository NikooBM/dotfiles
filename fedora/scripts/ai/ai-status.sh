#!/bin/bash
echo "═══════════════════════════════════════"
echo "  Estado del Stack de IA — $(date +%H:%M)"
echo "═══════════════════════════════════════"

echo ""
echo "🎮 GPU:"
nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total \
  --format=csv,noheader,nounits | awk -F',' '{printf "  %s | %s°C | %s%% GPU | %s/%s MB VRAM\n", $1,$2,$3,$4,$5}'

echo ""
echo "🧠 Ollama:"
if systemctl is-active --quiet ollama; then
  echo "  ✓ Activo"
  ollama list 2>/dev/null | tail -n +2 | while read line; do echo "  - $line"; done
else
  echo "  ✗ Inactivo — sudo systemctl start ollama"
fi

echo ""
echo "🖥️ Open WebUI:"
if podman ps --filter name=open-webui --format "{{.Status}}" 2>/dev/null | grep -q "Up"; then
  echo "  ✓ Activo en http://localhost:3000"
else
  echo "  ✗ Inactivo — systemctl --user start openwebui"
fi

echo ""
echo "🌐 Tailscale:"
if tailscale status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('  ✓ Conectado —', d['Self']['TailscaleIPs'][0])" 2>/dev/null; then
  :
else
  echo "  ✗ Desconectado"
fi

echo ""
echo "💾 Espacio modelos Ollama:"
du -sh ~/.ollama/models/ 2>/dev/null || echo "  No encontrado"
