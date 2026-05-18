# Shared shell environment for bash and zsh.
# Keep this POSIX-ish so it can be sourced from multiple shells.

# User-local binaries, including local Neovim installs.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# Some shared machines do not know Ghostty's terminfo entry.
if [ "${TERM:-}" = "xterm-ghostty" ]; then
  TERM="xterm-256color"
  export TERM
fi

# Prefer nvim when available.
if command -v nvim >/dev/null 2>&1; then
  EDITOR="nvim"
else
  EDITOR="vi"
fi
export EDITOR
