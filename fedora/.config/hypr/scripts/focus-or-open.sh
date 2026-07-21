#!/bin/bash
# Uso: focus-or-open.sh <class> <comando>
# Enfoca la ventana si existe, la lanza si no.
CLASS="$1"
CMD="$2"

# hyprctl clients devuelve JSON — buscamos la clase exacta
if hyprctl clients -j | grep -q "\"class\": \"${CLASS}\""; then
    hyprctl dispatch focuswindow "class:${CLASS}"
else
    eval "$CMD" &
fi
