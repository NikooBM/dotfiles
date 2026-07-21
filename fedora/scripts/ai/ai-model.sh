#!/bin/bash
# Gestión de modelos en VRAM — carga, descarga y estado

OLLAMA_URL="http://localhost:11434"

# ── Colores ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# ── Funciones ────────────────────────────────────────────
vram_status() {
    echo -e "${CYAN}═══ VRAM ═══${NC}"
    nvidia-smi --query-gpu=memory.used,memory.free,memory.total,utilization.gpu \
        --format=csv,noheader,nounits | \
        awk -F',' '{printf "  Usada: %s MB | Libre: %s MB | Total: %s MB | GPU: %s%%\n",$1,$2,$3,$4}'

    echo -e "${CYAN}═══ Modelos en VRAM ═══${NC}"
    LOADED=$(curl -s "$OLLAMA_URL/api/ps" 2>/dev/null)
    COUNT=$(echo "$LOADED" | python3 -c "
import sys,json
d=json.load(sys.stdin)
models=d.get('models',[])
if not models:
    print('  Ninguno — VRAM libre')
else:
    for m in models:
        size=m.get('size_vram',0)//1024//1024
        print(f'  ● {m[\"name\"]} ({size} MB VRAM)')
" 2>/dev/null)
    echo "$COUNT"
}

unload_all() {
    echo -e "${YELLOW}Descargando todos los modelos de VRAM...${NC}"
    MODELS=$(curl -s "$OLLAMA_URL/api/ps" | python3 -c "
import sys,json
for m in json.load(sys.stdin).get('models',[]):
    print(m['name'])
" 2>/dev/null)

    if [ -z "$MODELS" ]; then
        echo -e "${GREEN}  VRAM ya estaba libre${NC}"
        return
    fi

    echo "$MODELS" | while read model; do
        curl -s "$OLLAMA_URL/api/generate" \
            -d "{\"model\":\"$model\",\"keep_alive\":0}" > /dev/null
        echo -e "${GREEN}  ✓ $model descargado${NC}"
    done

    sleep 1
    echo -e "${CYAN}VRAM después:${NC}"
    nvidia-smi --query-gpu=memory.used,memory.free \
        --format=csv,noheader,nounits | \
        awk -F',' '{printf "  Usada: %s MB | Libre: %s MB\n",$1,$2}'
}

load_model() {
    local MODEL=$1
    if [ -z "$MODEL" ]; then
        echo -e "${RED}Error: especifica un modelo. Ej: ai-model load qwen2.5-coder:14b${NC}"
        exit 1
    fi

    # Verificar si ya está cargado
    ALREADY=$(curl -s "$OLLAMA_URL/api/ps" | python3 -c "
import sys,json
models=[m['name'] for m in json.load(sys.stdin).get('models',[])]
print('yes' if '$MODEL' in models else 'no')
" 2>/dev/null)

    if [ "$ALREADY" = "yes" ]; then
        echo -e "${GREEN}  ● $MODEL ya está en VRAM${NC}"
        return
    fi

    # Verificar VRAM disponible antes de cargar
    FREE_VRAM=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | tr -d ' ')
    echo -e "${BLUE}  VRAM libre antes de cargar: ${FREE_VRAM} MB${NC}"

    if [ "$FREE_VRAM" -lt 5000 ]; then
        echo -e "${YELLOW}  ⚠ Poca VRAM libre (${FREE_VRAM} MB). Descargando modelos previos...${NC}"
        unload_all
    fi

    echo -e "${BLUE}Cargando $MODEL en VRAM...${NC}"
    # Hacer una petición mínima para forzar la carga
    curl -s "$OLLAMA_URL/api/generate" \
        -d "{\"model\":\"$MODEL\",\"prompt\":\"hi\",\"stream\":false,\"keep_alive\":\"60m\"}" \
        > /dev/null

    echo -e "${GREEN}  ✓ $MODEL cargado${NC}"
    sleep 1
    nvidia-smi --query-gpu=memory.used,memory.free \
        --format=csv,noheader,nounits | \
        awk -F',' '{printf "  VRAM usada: %s MB | Libre: %s MB\n",$1,$2}'
}

# ── Main ─────────────────────────────────────────────────
case "$1" in
    status|"")   vram_status ;;
    load)        load_model "$2" ;;
    unload|free) unload_all ;;
    list)
        echo -e "${CYAN}Modelos disponibles:${NC}"
        ollama list ;;
    *)
        echo "Uso: ai-model [status|load <modelo>|unload|list]"
        echo "  ai-model status              → VRAM y modelos cargados"
        echo "  ai-model load qwen3:14b      → carga modelo (descarga otros si no hay espacio)"
        echo "  ai-model unload              → libera toda la VRAM"
        echo "  ai-model list                → modelos descargados en disco"
        ;;
esac
