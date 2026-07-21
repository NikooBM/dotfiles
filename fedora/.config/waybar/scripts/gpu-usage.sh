#!/bin/bash
# Módulo waybar para GPU NVIDIA
# Requiere: nvidia-smi
if ! command -v nvidia-smi &>/dev/null; then
    echo '{"text": "no gpu", "class": "unavailable"}'
    exit 0
fi

GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
GPU_MEM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
GPU_MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | sed 's/NVIDIA //' | sed 's/GeForce //')

# Clase CSS según uso
if   [ "$GPU_UTIL" -ge 90 ] 2>/dev/null; then CLASS="critical"
elif [ "$GPU_UTIL" -ge 70 ] 2>/dev/null; then CLASS="warning"
else CLASS="normal"
fi

TOOLTIP="${GPU_NAME}\\nUso: ${GPU_UTIL}%\\nTemp: ${GPU_TEMP}°C\\nVRAM: ${GPU_MEM_USED} / ${GPU_MEM_TOTAL} MiB"

echo "{\"text\": \"󰍹 ${GPU_UTIL}%\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
