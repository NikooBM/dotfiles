# dotfiles

Configuración personal para **Fedora (Hyprland/Wayland)** y **macOS (AeroSpace)**, con foco en un entorno de terminal productivo, WM en tiling y un stack de IA local sobre Ollama.

## 📁 Estructura

```
dotfiles/
├── fedora/                  # Setup Linux (Fedora + Hyprland/Wayland, NVIDIA)
│   ├── .config/
│   │   ├── hypr/             # Hyprland: compositor, idle, lockscreen, wallpaper
│   │   │   └── scripts/       # Selector de apps (app-switcher.py), utilidades
│   │   ├── waybar/            # Barra de estado + scripts (GPU, portapapeles)
│   │   ├── mako/               # Notificaciones
│   │   ├── wofi/                # Launcher
│   │   ├── kitty/                 # Terminal
│   │   ├── lazygit/                # TUI de git
│   │   └── nvim/                    # AstroNvim (config compartida con macOS)
│   ├── scripts/
│   │   ├── ai/                # Gestión del stack de IA local (Ollama, VRAM, estado)
│   │   └── system/             # Backup, restore y actualización del sistema
│   ├── Modelfile-coder-pro    # Modelo Ollama personalizado (qwen2.5-coder:14b)
│   ├── .zshrc / .p10k.zsh      # Shell (Oh My Zsh + Powerlevel10k)
│   └── wallpaper.jpg
└── macos/                    # Setup macOS (AeroSpace + WezTerm)
    ├── .aerospace.toml        # Tiling window manager
    ├── .config/
    │   ├── borders/            # JankyBorders (bordes de ventana activa)
    │   ├── wezterm/             # Terminal + keymaps
    │   └── nvim/                # AstroNvim (idéntica a la de fedora)
    ├── .zshrc / .zprofile
```

## 🐧 Fedora — Hyprland

- **WM:** Hyprland sobre Wayland, con soporte NVIDIA (variables de entorno propietarias, `no_hardware_cursors`, monitores multi-pantalla configurados).
- **Barra y UI:** Waybar + Mako (notificaciones) + Wofi (launcher), con estilos propios y scripts para uso de GPU y menú de portapapeles.
- **Selector de apps:** script en Python (`app-switcher.py`) con iconos por aplicación (navegadores, editor, Steam, Discord, etc.).
- **Terminal:** Kitty + Zsh (Oh My Zsh, tema Powerlevel10k).
- **IA local (Ollama):**
  - `ai-status.sh` — resumen del estado: GPU, Ollama, Open WebUI, Tailscale.
  - `ai-model.sh` — gestión de modelos cargados en VRAM.
  - `vram-clear.sh` — descarga forzada de todos los modelos de VRAM.
  - `ai-maintenance.sh` — actualiza sistema, Ollama, Open WebUI y herramientas MCP.
  - `Modelfile-coder-pro` — modelo `qwen2.5-coder:14b` afinado como asistente de código en español (32k de contexto).
- **Mantenimiento del sistema:**
  - `update-system.sh` — actualización completa (DNF + paquetes Wayland/Hyprland).
  - `backup.sh` / `restore.sh` — backup completo del stack (paquetes, configs, contenedores) con restauración selectiva por componente.

## 🍎 macOS — AeroSpace

- **WM:** AeroSpace (tiling) + JankyBorders para resaltar la ventana activa + SketchyBar.
- **Terminal:** WezTerm con keymaps propios (`modules/mappings.lua`), tema Poimandres.
- **Shell:** Zsh con Oh My Zsh (tema `robbyrussell`), plugins `zoxide`, `fzf`, `zsh-autosuggestions` y `zsh-syntax-highlighting`, más funciones propias (`ffind`, `ffindh`, `fhist`, etc.).

## 🧠 Neovim (compartido)

Ambos sistemas usan la misma configuración basada en **[AstroNvim](https://github.com/AstroNvim/AstroNvim) v5+**, con plugins propios en `lua/plugins/` (AstroCore, AstroLSP, AstroUI, Mason, none-ls, Treesitter).

## ⚙️ Instalación

Estos archivos están pensados para enlazarse (symlink) a sus rutas correspondientes en `$HOME`. Por ejemplo, con [GNU Stow](https://www.gnu.org/software/stow/) desde la carpeta del sistema que corresponda:

```bash
git clone https://github.com/NikooBM/dotfiles.git
cd dotfiles/fedora   # o cd dotfiles/macos
stow . -t ~
```

> ⚠️ Revisa antes los scripts en `scripts/` (rutas, usuario, hardware) y haz backup de tu configuración actual — algunas partes (NVIDIA, monitores, Modelfile) están ajustadas a mi hardware concreto.

## 📋 Requisitos

**Fedora:** Hyprland, Waybar, Mako, Wofi, Kitty, lazygit, Zsh + Oh My Zsh + Powerlevel10k, Ollama, Podman (Open WebUI), Tailscale, `nvidia-smi`.

**macOS:** AeroSpace, WezTerm, JankyBorders, SketchyBar, Zsh + Oh My Zsh, Homebrew (`fzf`, `zoxide`).

**Ambos:** Neovim ≥ 0.10 (AstroNvim v5+).
