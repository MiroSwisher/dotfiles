#!/bin/sh
set -eu

# User-local dotfiles installer, intended for shared SSH machines too.
# Usage after publishing:
#   DOTFILES_REPO=https://github.com/YOU/dotfiles.git sh -c "$(curl -fsSL https://raw.githubusercontent.com/YOU/dotfiles/main/install.sh)"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/YOUR_USERNAME/dotfiles.git}"
NVIM_VERSION="${NVIM_VERSION:-stable}"

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
    [ "$DOTFILES_REPO" != "https://github.com/YOUR_USERNAME/dotfiles.git" ] || err "Set DOTFILES_REPO to your GitHub repo URL before curl-piping this installer"
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
link_nvim
sync_nvim_plugins

log "Done. If nvim is not found, restart your shell or run: export PATH=\"$HOME/.local/bin:$PATH\""
