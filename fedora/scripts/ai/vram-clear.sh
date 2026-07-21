#!/bin/bash
echo "Modelos cargados en VRAM:"
curl -s http://localhost:11434/api/ps | python3 -c "
import sys, json
data = json.load(sys.stdin)
models = data.get('models', [])
if not models:
    print('  Ninguno — VRAM ya libre')
    exit()
for m in models:
    print(f'  → {m[\"name\"]}')
"

# Descargar cada modelo cargado
curl -s http://localhost:11434/api/ps | python3 -c "
import sys, json, urllib.request, urllib.parse
data = json.load(sys.stdin)
for m in data.get('models', []):
    name = m['name']
    req = urllib.request.Request(
        'http://localhost:11434/api/generate',
        data=json.dumps({'model': name, 'keep_alive': 0}).encode(),
        headers={'Content-Type': 'application/json'}
    )
    urllib.request.urlopen(req)
    print(f'  ✓ {name} descargado de VRAM')
"

echo ""
echo "VRAM después:"
nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader
