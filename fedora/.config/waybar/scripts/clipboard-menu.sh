#!/bin/bash
# Abre historial de portapapeles con wofi
selected=$(cliphist list | wofi --dmenu --prompt "Portapapeles" --insensitive)
if [ -n "$selected" ]; then
    echo "$selected" | cliphist decode | wl-copy
fi
