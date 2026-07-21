# Ruta de Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"

# Tema
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
  git
  zoxide
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Activar Oh My Zsh
source $ZSH/oh-my-zsh.sh

# ----------------------------
# Complementos útiles
# ----------------------------

# zoxide (navegación rápida)
eval "$(zoxide init zsh)"

# fzf (buscador interactivo)
[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ] && source /opt/homebrew/opt/fzf/shell/key-bindings.zsh

# Autocompletado y resaltado
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ----------------------------
# Funciones personalizadas
# ----------------------------

# Buscar archivos y abrirlos (si se selecciona)
# ffind: Buscar archivos por nombre
ffind() {
  find . -type f -iname "*$1*"
}

# ffindh: Buscar en historial de comandos
ffindh() {
  history | grep "$1"
}

# fhist: Buscar en historial con FZF y copiar
fhist() {
  history | fzf | awk '{print $2}'
}

# cheat: Consultas rápidas (chuletas) de comandos
cheat() {
  curl -s "https://cheat.sh/$1"
}

# extract: Extraer cualquier tipo de archivo
extract () {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1" ;;
      *.tar.gz)    tar xzf "$1" ;;
      *.bz2)       bunzip2 "$1" ;;
      *.rar)       unrar x "$1" ;;
      *.gz)        gunzip "$1" ;;
      *.tar)       tar xf "$1" ;;
      *.tbz2)      tar xjf "$1" ;;
      *.tgz)       tar xzf "$1" ;;
      *.zip)       unzip "$1" ;;
      *.Z)         uncompress "$1" ;;
      *.7z)        7z x "$1" ;;
      *)           echo "'$1' no se puede extraer automáticamente" ;;
    esac
  else
    echo "'$1' no es un archivo válido"
  fi
}

# mkcd: Crear carpeta y entrar
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# ipinfo: Ver IP pública y geolocalización
ipinfo() {
  curl -s ipinfo.io
}

# portscan: Escaneo rápido de puertos abiertos
portscan() {
  nc -zv $1 1-1024 2>&1 | grep succeeded
}

# serve: Servidor web local
serve() {
  python3 -m http.server "${1:-8000}"
}

# ----------------------------
# Alias útiles
# ----------------------------

alias ll='ls -lah'
alias ..='cd ..'
alias ...='cd ../..'
alias yd='yt-dlp -x --audio-format mp3 --output "~/Music/%(title)s.%(ext)s"'
# ----------------------------
# Configuración general
# ----------------------------

export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"


# PATH extendido
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/local/sbin:$PATH"

export PATH="/opt/homebrew/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"

export PATH="/opt/homebrew/Cellar/node/25.1.0_1/bin:$PATH"
export PATH="/opt/homebrew/opt/python@3.14/bin:$PATH"
export PATH="/opt/homebrew/opt/tree-sitter/bin:$PATH"

# ── Fedora remote ──────────────────────────────────
alias fedora='ssh niko@100.91.28.59'
alias goose-pc='ssh -t niko@100.91.28.59 goose session'
alias ai-status='ssh niko@100.91.28.59 ~/scripts/ai-status.sh'
alias vram-pc='ssh niko@100.91.28.59 "nvidia-smi --query-gpu=memory.used,memory.free,temperature.gpu --format=csv,noheader"'
alias n8n-restart='ssh niko@100.91.28.59 "systemctl --user restart n8n"'
alias ollama-list='ssh niko@100.91.28.59 "ollama list"'
alias sshfs='DYLD_LIBRARY_PATH=/usr/local/lib sshfs'
alias n8n-mac='open http://localhost:5679'
alias n8n-start='docker start n8n'
alias n8n-stop='docker stop n8n'
alias n8n-logs='docker logs n8n -f'        # ver qué está pasando si algo falla
alias n8n-update='docker stop n8n && docker rm n8n && docker pull docker.n8n.io/n8nio/n8n:latest && docker run -d --name n8n --restart unless-stopped -p 5679:5678 -v ~/containers/n8n:/home/node/.n8n -e GENERIC_TIMEZONE=Europe/Madrid -e TZ=Europe/Madrid -e N8N_SECURE_COOKIE=false -e N8N_BASIC_AUTH_ACTIVE=true -e N8N_BASIC_AUTH_USER=niko -e N8N_BASIC_AUTH_PASSWORD=TU_PASSWORD -e WEBHOOK_URL=http://localhost:5679/ docker.n8n.io/n8nio/n8n:latest'


# Added by Antigravity CLI installer
export PATH="/Users/nikobibileishvili/.local/bin:$PATH"
