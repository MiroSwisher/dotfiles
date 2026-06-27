#!/bin/sh
set -eu

# User-local dotfiles installer, intended for shared SSH machines too.
# Usage:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/MiroSwisher/dotfiles/main/install.sh)"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:MiroSwisher/dotfiles.git}"
NVIM_VERSION="${NVIM_VERSION:-stable}"
RG_VERSION="${RG_VERSION:-14.1.1}"
FD_VERSION="${FD_VERSION:-10.2.0}"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
err() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || err "Missing required command: $1"; }

mkdir -p "$HOME/.local/bin" "$HOME/.local/opt" "$HOME/.config"

ensure_path() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *)
      warn "$HOME/.local/bin is not currently in PATH"
      if [ -f "$HOME/.bashrc" ] && ! grep -q 'HOME/.local/bin' "$HOME/.bashrc"; then
        log "Adding ~/.local/bin to ~/.bashrc"
        printf '\n# Added by dotfiles installer\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
      fi
      export PATH="$HOME/.local/bin:$PATH"
      ;;
  esac
}

install_nvim() {
  if command -v nvim >/dev/null 2>&1; then
    log "Found nvim: $(command -v nvim)"
    return 0
  fi

  need curl
  need tar

  arch="$(uname -m)"
  os="$(uname -s)"
  [ "$os" = "Linux" ] || err "Automatic Neovim install currently supports Linux only; found $os"

  case "$arch" in
    x86_64|amd64) asset="nvim-linux-x86_64.tar.gz"; dirname="nvim-linux-x86_64" ;;
    aarch64|arm64) asset="nvim-linux-arm64.tar.gz"; dirname="nvim-linux-arm64" ;;
    *) err "Unsupported architecture for automatic Neovim install: $arch" ;;
  esac

  url="https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$asset"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT HUP INT TERM

  log "Installing Neovim $NVIM_VERSION locally"
  curl -fL "$url" -o "$tmp/nvim.tar.gz"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
  rm -rf "$HOME/.local/opt/nvim"
  mv "$tmp/$dirname" "$HOME/.local/opt/nvim"
  ln -sf "$HOME/.local/opt/nvim/bin/nvim" "$HOME/.local/bin/nvim"
  log "Installed nvim to ~/.local/bin/nvim"
}

install_lazyvim_tools() {
  need curl
  need tar

  os="$(uname -s)"
  arch="$(uname -m)"
  [ "$os" = "Linux" ] || {
    warn "Skipping user-local LazyVim tool install on $os"
    return 0
  }

  case "$arch" in
    x86_64|amd64) ;;
    *)
      warn "Skipping LazyVim tool auto-install on unsupported arch: $arch"
      return 0
      ;;
  esac

  tmp="$(mktemp -d)"

  if ! command -v rg >/dev/null 2>&1; then
    log "Installing ripgrep locally"
    curl -fL "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl.tar.gz" -o "$tmp/ripgrep.tar.gz"
    tar -xzf "$tmp/ripgrep.tar.gz" -C "$tmp"
    cp "$tmp/ripgrep-${RG_VERSION}-x86_64-unknown-linux-musl/rg" "$HOME/.local/bin/rg"
    chmod +x "$HOME/.local/bin/rg"
  else
    log "Found rg: $(command -v rg)"
  fi

  if command -v fd >/dev/null 2>&1; then
    log "Found fd: $(command -v fd)"
  elif command -v fdfind >/dev/null 2>&1; then
    log "Found fdfind; linking fd -> fdfind"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  else
    log "Installing fd locally"
    curl -fL "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-x86_64-unknown-linux-gnu.tar.gz" -o "$tmp/fd.tar.gz"
    tar -xzf "$tmp/fd.tar.gz" -C "$tmp"
    cp "$tmp/fd-v${FD_VERSION}-x86_64-unknown-linux-gnu/fd" "$HOME/.local/bin/fd"
    chmod +x "$HOME/.local/bin/fd"
  fi

  if ! command -v lazygit >/dev/null 2>&1; then
    log "Installing lazygit locally"
    lazygit_version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -o '"tag_name": "v[^"]*' | sed 's/"tag_name": "v//' || true)"
    [ -n "$lazygit_version" ] || lazygit_version="0.48.0"
    curl -fL "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${lazygit_version}_Linux_x86_64.tar.gz" -o "$tmp/lazygit.tar.gz"
    tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit
    cp "$tmp/lazygit" "$HOME/.local/bin/lazygit"
    chmod +x "$HOME/.local/bin/lazygit"
  else
    log "Found lazygit: $(command -v lazygit)"
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    need git
    log "Installing fzf locally"
    if [ ! -d "$HOME/.fzf/.git" ]; then
      rm -rf "$HOME/.fzf"
      git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    fi
    "$HOME/.fzf/install" --bin
    ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
  else
    log "Found fzf: $(command -v fzf)"
  fi

  rm -rf "$tmp"

  if ! command -v luarocks >/dev/null 2>&1; then
    warn "luarocks not found. Usually okay for LazyVim; install manually if a plugin asks for it."
  else
    log "Found luarocks: $(command -v luarocks)"
  fi
}

clone_or_update_dotfiles() {
  # If this script lives inside a dotfiles checkout, use that checkout.
  script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || true)"
  if [ -n "$script_dir" ] && [ -d "$script_dir/nvim" ]; then
    DOTFILES_DIR="$script_dir"
    log "Using existing dotfiles checkout: $DOTFILES_DIR"
    return 0
  fi

  need git

  if [ -d "$DOTFILES_DIR/.git" ]; then
    log "Updating $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only
  else
    log "Cloning $DOTFILES_REPO to $DOTFILES_DIR"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
}

link_nvim() {
  src="$DOTFILES_DIR/nvim"
  dest="$HOME/.config/nvim"
  [ -d "$src" ] || err "Missing nvim config at $src"

  if [ -L "$dest" ]; then
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      log "Neovim config already linked"
      return 0
    fi
  fi

  if [ -e "$dest" ]; then
    backup="$HOME/.config/nvim.bak.$(date +%Y%m%d-%H%M%S)"
    log "Backing up existing nvim config to $backup"
    mv "$dest" "$backup"
  fi

  log "Linking $dest -> $src"
  ln -s "$src" "$dest"
}

install_shell_config() {
  [ -f "$DOTFILES_DIR/shell/env.sh" ] || return 0
  [ -f "$DOTFILES_DIR/shell/aliases.sh" ] || return 0

  block='\n# Dotfiles shell config\nif [ -f "$HOME/.dotfiles/shell/env.sh" ]; then . "$HOME/.dotfiles/shell/env.sh"; fi\nif [ -f "$HOME/.dotfiles/shell/aliases.sh" ]; then . "$HOME/.dotfiles/shell/aliases.sh"; fi\n'

  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    # Always configure bash. Configure zsh if the file already exists or zsh is the current shell.
    case "$rc" in
      */.zshrc)
        [ -f "$rc" ] || [ "${SHELL:-}" = "$(command -v zsh 2>/dev/null || true)" ] || continue
        ;;
    esac

    if [ ! -f "$rc" ]; then
      log "Creating ${rc#$HOME/}"
      : > "$rc"
    fi

    if ! grep -q 'Dotfiles shell config' "$rc"; then
      log "Adding dotfiles shell config to ${rc#$HOME/}"
      printf "%b" "$block" >> "$rc"
    fi
  done
}

link_file() {
  # link_file <src-relative-to-dotfiles> <dest-absolute>
  src="$DOTFILES_DIR/$1"
  dest="$2"
  [ -e "$src" ] || { warn "Missing dotfiles source: $src"; return 1; }

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    log "Already linked: $dest"
    return 0
  fi

  if [ -e "$dest" ]; then
    backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
    log "Backing up $dest -> $backup"
    mv "$dest" "$backup"
  fi

  mkdir -p "$(dirname "$dest")"
  log "Linking $dest -> $src"
  ln -s "$src" "$dest"
}

link_ghostty()   { link_file "ghostty/config"        "$HOME/.config/ghostty/config"; }
link_gitconfig() { link_file "git/gitconfig"          "$HOME/.gitconfig"; }
link_zsh()       { link_file "zsh/zshrc"              "$HOME/.zshrc"; }
link_fastfetch() { link_file "fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"; }

sync_nvim_plugins() {
  if command -v nvim >/dev/null 2>&1; then
    log "Installing/syncing Neovim plugins"
    nvim --headless "+Lazy! sync" +qa || warn "Plugin sync failed; open nvim and run :Lazy sync"
  else
    warn "nvim not found after install; skipping plugin sync"
  fi
}

ensure_path
install_nvim
clone_or_update_dotfiles
install_lazyvim_tools
link_nvim
link_ghostty
link_gitconfig
link_zsh
link_fastfetch
install_shell_config
sync_nvim_plugins

log "Done. If nvim is not found, restart your shell or run: export PATH=\"$HOME/.local/bin:$PATH\""
