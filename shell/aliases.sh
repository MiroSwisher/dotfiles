# Shared aliases/functions for bash and zsh.
# Keep this POSIX-ish so it can be sourced from multiple shells.

# General
alias c='clear'
alias h='history'
alias v='nvim'

# Safer file operations
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias desk='cd ~/Desktop'
alias dl='cd ~/Downloads'
alias docs='cd ~/Documents'

# File listing
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --color=auto'
  alias ll='eza -lah'
  alias la='eza -a'
  alias lt='eza --tree'
else
  alias ls='ls --color=auto'
  alias ll='ls -lah'
  alias la='ls -A'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
fi

# Git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add .'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate --all'

# tmux
alias t='tmux'
alias tls='tmux ls'
alias tn='tmux new -s'
alias ta='tmux attach -t'

# Docker
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias di='docker images'

# System / networking
alias myip='curl ifconfig.me; echo'
alias ports='ss -tlnp'
alias psa='ps aux | grep -v grep'
alias dfh='df -h'

if du -d 0 . >/dev/null 2>&1; then
  alias duh='du -h -d 1 | sort -h'
else
  alias duh='du -h --max-depth=1 | sort -h'
fi

if command -v htop >/dev/null 2>&1; then
  alias top='htop'
fi

# Reload current interactive shell config.
reload_shell() {
  if [ -n "${ZSH_VERSION:-}" ] && [ -f "$HOME/.zshrc" ]; then
    . "$HOME/.zshrc"
  elif [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
  else
    echo "Don't know which shell rc file to reload"
    return 1
  fi
}
alias reload='reload_shell'

# Functions
mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

venv() {
  python3 -m venv .venv && . .venv/bin/activate
}

extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz)  tar xzf "$1" ;;
      *.bz2)     bunzip2 "$1" ;;
      *.rar)     unrar x "$1" ;;
      *.gz)      gunzip "$1" ;;
      *.tar)     tar xf "$1" ;;
      *.tbz2)    tar xjf "$1" ;;
      *.tgz)     tar xzf "$1" ;;
      *.zip)     unzip "$1" ;;
      *.Z)       uncompress "$1" ;;
      *.7z)      7z x "$1" ;;
      *) echo "don't know how to extract '$1'" ;;
    esac
  else
    echo "'$1' is not a valid file"
    return 1
  fi
}
