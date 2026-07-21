#!/bin/bash
# ==============================================================================
#  update-system.sh — Actualización completa Fedora + Hyprland + Wayland
#  Versión: 2.0
# ==============================================================================

set -euo pipefail

# ── Colores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERR ]${RESET}  $*"; }
section() {
    echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  ❱  $*${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"
}
ask_yn() {
    local PROMPT="$1"
    read -rp "$(echo -e "${YELLOW}[?]${RESET} ${PROMPT} [S/n]: ")" ANS
    ANS="${ANS:-s}"
    [[ "${ANS,,}" == "s" ]]
}

# ── Log ────────────────────────────────────────────────────────────────────────
LOG_DIR="$HOME/.local/share/update-system"
LOG_FILE="${LOG_DIR}/update-$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1
info "Log guardado en: ${LOG_FILE}"

ERRORS=0
REBOOT_NEEDED=false

# ══════════════════════════════════════════════════════════════════════════════
# COMPROBACIONES PREVIAS
# ══════════════════════════════════════════════════════════════════════════════
section "Comprobaciones previas"

# Conectividad
if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
    error "Sin conexión a internet. Abortando."
    exit 1
fi
ok "Conexión a internet disponible"

# Espacio en disco (mínimo 3 GB libres en /)
FREE_GB=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
if [[ "$FREE_GB" -lt 3 ]]; then
    warn "Poco espacio en disco (${FREE_GB} GB libres). Considera limpiar primero."
else
    ok "Espacio en disco: ${FREE_GB} GB libres"
fi

# Batería en portátiles
if command -v upower &>/dev/null; then
    BAT_PATH=$(upower -e 2>/dev/null | grep -i battery | head -1 || true)
    if [[ -n "$BAT_PATH" ]]; then
        BAT=$(upower -i "$BAT_PATH" 2>/dev/null | awk '/percentage/{print $2}' | tr -d '%' || true)
        CHARGING=$(upower -i "$BAT_PATH" 2>/dev/null | awk '/state/{print $2}' || true)
        if [[ -n "$BAT" && "$BAT" -lt 20 && "$CHARGING" != "charging" ]]; then
            warn "Batería baja (${BAT}%). Conecta el cargador antes de continuar."
            ask_yn "¿Continuar de todas formas?" || exit 0
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# DETECCIÓN DE HARDWARE
# ══════════════════════════════════════════════════════════════════════════════
section "Detección de hardware y entorno"

HAS_NVIDIA=false
HAS_AMD=false
HAS_INTEL_GPU=false

if lspci 2>/dev/null | grep -qi "NVIDIA"; then
    HAS_NVIDIA=true
    NVIDIA_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "no detectado")
    warn "GPU NVIDIA detectada — driver actual: ${NVIDIA_VER}"
    warn "Se aplicarán comprobaciones de seguridad adicionales para Wayland/Hyprland"
fi
lspci 2>/dev/null | grep -qi "AMD"   && { HAS_AMD=true;       ok "GPU AMD detectada (amdgpu)"; }
lspci 2>/dev/null | grep -qi "Intel" && { HAS_INTEL_GPU=true; ok "GPU Intel detectada (i915)"; }

info "Kernel actual: $(uname -r)"
info "Display Wayland: ${WAYLAND_DISPLAY:-no detectado}"
info "Escritorio: ${XDG_CURRENT_DESKTOP:-Hyprland/desconocido}"

# ══════════════════════════════════════════════════════════════════════════════
# SELECCIÓN DE MÓDULOS
# ══════════════════════════════════════════════════════════════════════════════
section "¿Qué deseas actualizar?"

DO_DNF=true
DO_HYPRLAND=true
DO_FLATPAK=true
DO_FIRMWARE=true
DO_RUST_CARGO=false
DO_PIPX=false
DO_SNAP=false
DO_CLEAN=false
DO_CLEAN_CACHE=false
DO_CLEAN_ORPHANS=false
DO_CLEAN_JOURNAL=false
DO_CLEAN_THUMB=false
DO_CLEAN_TMP=false
DO_CLEAN_FLATPAK=false
DO_CLEAN_CRASH=false
DO_CLEAN_USERHOME=false

ask_yn "Actualizar paquetes DNF (sistema base)"           && DO_DNF=true         || DO_DNF=false
ask_yn "Actualizar COPR Hyprland"                         && DO_HYPRLAND=true    || DO_HYPRLAND=false
ask_yn "Actualizar Flatpak"                               && DO_FLATPAK=true     || DO_FLATPAK=false
ask_yn "Actualizar firmware (fwupd)"                      && DO_FIRMWARE=true    || DO_FIRMWARE=false
ask_yn "Actualizar herramientas Cargo/Rust (si usas)"    && DO_RUST_CARGO=true  || DO_RUST_CARGO=false
ask_yn "Actualizar paquetes pipx (si usas)"              && DO_PIPX=true        || DO_PIPX=false
ask_yn "Actualizar paquetes Snap (si usas)"              && DO_SNAP=true        || DO_SNAP=false
echo ""
if ask_yn "¿Ejecutar limpieza completa del sistema?"; then
    DO_CLEAN=true
    ask_yn "  └─ Limpiar caché DNF/Flatpak"                      && DO_CLEAN_CACHE=true
    ask_yn "  └─ Eliminar paquetes huérfanos y dependencias"      && DO_CLEAN_ORPHANS=true
    ask_yn "  └─ Limpiar journald (logs del sistema)"             && DO_CLEAN_JOURNAL=true
    ask_yn "  └─ Limpiar caché de miniaturas"                     && DO_CLEAN_THUMB=true
    ask_yn "  └─ Limpiar /tmp y /var/tmp antiguos (+7 días)"      && DO_CLEAN_TMP=true
    ask_yn "  └─ Eliminar runtimes Flatpak sin usar"              && DO_CLEAN_FLATPAK=true
    ask_yn "  └─ Limpiar reportes de crash (abrt/coredumps)"      && DO_CLEAN_CRASH=true
    ask_yn "  └─ Limpiar caché de usuario (~/.cache)"             && DO_CLEAN_USERHOME=true
fi
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# 1. DNF
# ══════════════════════════════════════════════════════════════════════════════
if $DO_DNF; then
    section "Actualizando paquetes DNF"

    info "Refrescando metadatos de repositorios..."
    sudo dnf check-update --refresh -q || true  # exit 100 = hay updates, no es error fatal

    KERNEL_BEFORE=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -1)

    # Advertencia de componentes Wayland/Hyprland
    WAYLAND_PENDING=$(dnf check-update -q 2>/dev/null | grep -iE "^(wayland|xdg-desktop|pipewire|wlroots|xwayland)" || true)
    if [[ -n "$WAYLAND_PENDING" ]]; then
        warn "Actualizaciones de componentes Wayland pendientes:"
        echo "$WAYLAND_PENDING"
        warn "Si tienes problemas tras actualizar, revisa los changelogs."
    fi

    # NVIDIA: aviso si hay nuevo kernel
    if $HAS_NVIDIA; then
        KERNEL_PENDING=$(dnf check-update -q 2>/dev/null | grep "^kernel " || true)
        if [[ -n "$KERNEL_PENDING" ]]; then
            warn "Nuevo kernel disponible con GPU NVIDIA."
            warn "akmod-nvidia recompilará el módulo automáticamente."
            warn "NO reinicies hasta confirmar que akmods terminó."
            REBOOT_NEEDED=true
        fi
    fi

    if sudo dnf upgrade --refresh -y; then
        KERNEL_AFTER=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -1)
        if [[ "$KERNEL_BEFORE" != "$KERNEL_AFTER" ]]; then
            info "Nuevo kernel instalado: ${KERNEL_AFTER} (anterior: ${KERNEL_BEFORE})"
            REBOOT_NEEDED=true
        fi
        ok "DNF actualizado correctamente"
    else
        error "Fallo en dnf upgrade. Revisa el log."
        ERRORS=$((ERRORS + 1))
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 2. FIRMWARE
# ══════════════════════════════════════════════════════════════════════════════
if $DO_FIRMWARE; then
    section "Actualizando firmware (fwupd)"
    if command -v fwupdmgr &>/dev/null; then
        fwupdmgr refresh --force 2>/dev/null || true
        if fwupdmgr get-updates 2>/dev/null | grep -q "No se encontraron\|No updates"; then
            ok "Firmware ya está al día"
        else
            fwupdmgr get-updates 2>/dev/null || true
            if ask_yn "¿Aplicar actualizaciones de firmware?"; then
                fwupdmgr update -y 2>/dev/null || warn "Algunas actualizaciones de firmware requieren reinicio"
                REBOOT_NEEDED=true
            fi
        fi
    else
        warn "fwupdmgr no encontrado. Instálalo: sudo dnf install fwupd"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 3. FLATPAK
# ══════════════════════════════════════════════════════════════════════════════
if $DO_FLATPAK; then
    section "Actualizando Flatpak"
    if command -v flatpak &>/dev/null; then
        sudo flatpak update -y && ok "Flatpak (sistema) actualizado" || { error "Fallo Flatpak sistema"; ERRORS=$((ERRORS+1)); }
        flatpak update --user -y && ok "Flatpak (usuario) actualizado" || warn "Sin apps Flatpak de usuario o fallo menor"
    else
        warn "Flatpak no instalado, omitiendo."
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 4. COPR HYPRLAND
# ══════════════════════════════════════════════════════════════════════════════
if $DO_HYPRLAND; then
    section "Actualizando COPR Hyprland"

    # Detectar el ID real del repo dinámicamente (el dominio cambia según versión de Fedora)
    HYPR_REPO=$(sudo dnf repolist --all 2>/dev/null \
        | awk '{print $1}' \
        | grep -i "solopasha.*hyprland\|hyprland.*solopasha" \
        | head -1 || true)

    if [[ -z "$HYPR_REPO" ]]; then
        warn "Repositorio COPR solopasha/hyprland no encontrado."
        warn "Añádelo con: sudo dnf copr enable solopasha/hyprland"
        warn "Y vuelve a ejecutar el script."
    else
        info "Repositorio detectado: ${HYPR_REPO}"

        # Habilitarlo si estuviera deshabilitado
        if ! sudo dnf repolist --enabled 2>/dev/null | grep -q "$HYPR_REPO"; then
            warn "El repo está deshabilitado. Habilitándolo temporalmente..."
            sudo dnf config-manager --set-enabled "$HYPR_REPO" 2>/dev/null || true
        fi

        # Advertencia si hay nueva versión de Hyprland (puede romper plugins)
        HYPR_PENDING=$(sudo dnf check-update --repo="$HYPR_REPO" -q 2>/dev/null \
            | grep -i "hyprland" || true)
        if [[ -n "$HYPR_PENDING" ]]; then
            warn "Nueva versión de Hyprland disponible:"
            echo "$HYPR_PENDING"
            warn "Si usas plugins (hyprpm), pueden dejar de funcionar hasta recompilarlos."
        fi

        if sudo dnf upgrade --repo="$HYPR_REPO" -y; then
            ok "COPR Hyprland actualizado"
        else
            error "Fallo al actualizar COPR Hyprland"
            ERRORS=$((ERRORS+1))
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 5. NVIDIA — comprobaciones post-update
# ══════════════════════════════════════════════════════════════════════════════
if $HAS_NVIDIA && $REBOOT_NEEDED; then
    section "Verificación NVIDIA post-update"
    KERNEL_NEW=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -1)
    NVIDIA_MOD=$(find /lib/modules -name "nvidia.ko*" 2>/dev/null | grep "$KERNEL_NEW" || true)

    if [[ -z "$NVIDIA_MOD" ]]; then
        warn "Módulo NVIDIA para kernel ${KERNEL_NEW} aún NO compilado."
        warn "Ejecuta antes de reiniciar:"
        warn "  sudo akmods --force"
        warn "  sudo dracut --force"
        warn "  journalctl -f -u akmods   ← para monitorizar"
    else
        ok "Módulo NVIDIA detectado para el nuevo kernel"
    fi

    # Verificar modeset para Wayland
    if ! grep -rq "nvidia-drm.modeset=1" /etc/kernel/cmdline /etc/default/grub /proc/cmdline 2>/dev/null; then
        warn "nvidia-drm.modeset=1 NO detectado en parámetros del kernel."
        warn "Es obligatorio para NVIDIA con Wayland/Hyprland."
        warn "Corrígelo con:"
        warn "  sudo grubby --update-kernel=ALL --args='nvidia-drm.modeset=1'"
        warn "  sudo grub2-mkconfig -o /boot/grub2/grub.cfg"
    else
        ok "nvidia-drm.modeset=1 configurado correctamente"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 6. CARGO / RUST
# ══════════════════════════════════════════════════════════════════════════════
if $DO_RUST_CARGO; then
    section "Actualizando Rust/Cargo"
    command -v rustup &>/dev/null && rustup update && ok "Rust actualizado" || warn "rustup no encontrado"
    if command -v cargo-install-update &>/dev/null; then
        cargo install-update -a && ok "Paquetes Cargo actualizados"
    else
        warn "cargo-update no instalado: cargo install cargo-update"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 7. PIPX
# ══════════════════════════════════════════════════════════════════════════════
if $DO_PIPX; then
    section "Actualizando paquetes pipx"
    command -v pipx &>/dev/null && pipx upgrade-all && ok "pipx actualizado" || warn "pipx no instalado"
fi

# ══════════════════════════════════════════════════════════════════════════════
# 8. SNAP
# ══════════════════════════════════════════════════════════════════════════════
if $DO_SNAP; then
    section "Actualizando Snap"
    command -v snap &>/dev/null && sudo snap refresh && ok "Snaps actualizados" || warn "snap no instalado"
fi

# ══════════════════════════════════════════════════════════════════════════════
# 9. LIMPIEZA
# ══════════════════════════════════════════════════════════════════════════════
if $DO_CLEAN; then
    section "Limpieza del sistema"

    if $DO_CLEAN_CACHE; then
        info "Limpiando caché de DNF..."
        sudo dnf clean all && ok "Caché DNF limpiada"
    fi

    if $DO_CLEAN_ORPHANS; then
        info "Buscando paquetes huérfanos..."
        ORPHANS=$(sudo dnf repoquery --extras --installed -q 2>/dev/null || true)
        if [[ -n "$ORPHANS" ]]; then
            warn "Paquetes huérfanos encontrados:"
            echo "$ORPHANS"
            ask_yn "¿Eliminarlos?" && sudo dnf remove $ORPHANS -y || true
        else
            ok "No hay paquetes huérfanos"
        fi

        info "Eliminando dependencias innecesarias (autoremove)..."
        sudo dnf autoremove -y && ok "Autoremove completado"
    fi

    if $DO_CLEAN_FLATPAK && command -v flatpak &>/dev/null; then
        info "Eliminando runtimes Flatpak sin usar..."
        flatpak uninstall --unused -y
        sudo flatpak uninstall --unused -y
        ok "Runtimes Flatpak sin usar eliminados"
    fi

    if $DO_CLEAN_JOURNAL; then
        info "Limpiando journald..."
        sudo journalctl --vacuum-time=2weeks
        sudo journalctl --vacuum-size=500M
        ok "Logs reducidos a máx 500 MB / 2 semanas"
    fi

    if $DO_CLEAN_THUMB; then
        THUMB_SIZE=$(du -sh "$HOME/.cache/thumbnails" 2>/dev/null | cut -f1 || echo "0")
        info "Limpiando miniaturas (${THUMB_SIZE})..."
        rm -rf "${HOME}/.cache/thumbnails/"*
        ok "Miniaturas limpiadas"
    fi

    if $DO_CLEAN_TMP; then
        info "Limpiando archivos temporales antiguos (+7 días)..."
        sudo find /tmp /var/tmp -type f -atime +7 -delete 2>/dev/null || true
        ok "Temporales antiguos eliminados"
    fi

    if $DO_CLEAN_CRASH; then
        info "Limpiando reportes de crash..."
        sudo rm -rf /var/spool/abrt/* 2>/dev/null || true
        sudo rm -rf /var/crash/* 2>/dev/null || true
        ok "Reportes de crash eliminados"
    fi

    if $DO_CLEAN_USERHOME; then
        USER_CACHE_SIZE=$(du -sh "$HOME/.cache" 2>/dev/null | cut -f1 || echo "0")
        warn "Caché de usuario: ${USER_CACHE_SIZE} — se preservarán cachés de navegadores."
        find "$HOME/.cache" -mindepth 1 -maxdepth 1 \
            ! -name "mozilla" \
            ! -name "chromium" \
            ! -name "BraveSoftware" \
            ! -name "google-chrome" \
            ! -name "vivaldi" \
            -exec rm -rf {} + 2>/dev/null || true
        ok "Caché de usuario limpiada (navegadores preservados)"
    fi

    # Kernels antiguos
    info "Comprobando kernels instalados..."
    KERNEL_COUNT=$(rpm -q kernel | wc -l)
    if [[ "$KERNEL_COUNT" -gt 2 ]]; then
        warn "Tienes ${KERNEL_COUNT} kernels instalados."
        ask_yn "¿Eliminar kernels antiguos? (se conservan los 2 más recientes)" && \
            sudo dnf remove --oldinstallonly --setopt installonly_limit=2 kernel -y && ok "Kernels antiguos eliminados" || true
    else
        ok "Kernels instalados: ${KERNEL_COUNT} (correcto)"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ══════════════════════════════════════════════════════════════════════════════
section "Resumen final"
echo -e "  ${BOLD}Fecha:${RESET}  $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  ${BOLD}Kernel:${RESET} $(uname -r)"
echo -e "  ${BOLD}Log:${RESET}    ${LOG_FILE}"
echo ""

if [[ "$ERRORS" -eq 0 ]]; then
    ok "Actualización completada sin errores."
else
    error "Finalizado con ${ERRORS} error(es). Revisa el log: ${LOG_FILE}"
fi

if $REBOOT_NEEDED; then
    echo ""
    warn "┌─────────────────────────────────────────────────────┐"
    warn "│  Se recomienda REINICIAR el sistema                 │"
    $HAS_NVIDIA && warn "│  ⚠ NVIDIA: asegúrate de que akmods terminó antes   │"
    $HAS_NVIDIA && warn "│    sudo akmods --force && sudo dracut --force       │"
    warn "└─────────────────────────────────────────────────────┘"
    echo ""
    if ask_yn "¿Reiniciar ahora?"; then
        if $HAS_NVIDIA; then
            info "Compilando módulos NVIDIA para el nuevo kernel..."
            sudo akmods --force
            sudo dracut --force
        fi
        sudo systemctl reboot
    fi
fi

echo -e "\n${GREEN}${BOLD}=== Listo ===${RESET}\n"
