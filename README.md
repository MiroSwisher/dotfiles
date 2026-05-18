# dotfiles

Small, user-local dotfiles repo focused on Neovim/LazyVim.

## Install on a new machine

After replacing the repo URL in `install.sh` / publishing this repo:

```sh
DOTFILES_REPO=git@github.com:MiroSwisher/dotfiles.git sh -c "$(curl -fsSL https://raw.githubusercontent.com/MiroSwisher/dotfiles/main/install.sh)"
```

Safer/manual option:

```sh
git clone git@github.com:MiroSwisher/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

The installer:

- installs Neovim under `~/.local` if `nvim` is missing
- installs/checks LazyVim CLI tools user-locally on Linux: `rg`, `fd`, `lazygit`, `fzf`
- warns if `luarocks` is missing; most setups work fine without it
- backs up any existing `~/.config/nvim`
- symlinks `~/.config/nvim -> ~/.dotfiles/nvim`
- adds shared shell config to bash/zsh rc files
- runs `nvim --headless "+Lazy! sync" +qa`

No `sudo` required.

## Useful Neovim commands

```vim
:Lazy        " plugin manager
:Lazy sync   " install/update plugins
:Mason       " install LSPs/formatters/linters
:LazyExtras  " enable LazyVim language extras
```

## Shell config

Shared bash/zsh config lives in:

```txt
shell/env.sh
shell/aliases.sh
```

Useful aliases include:

```sh
c          # clear
v          # nvim
gs         # git status
ll         # long ls/eza listing
..         # cd ..
```

## Current Neovim stack

- Neovim
- LazyVim
- lazy.nvim
- Catppuccin Macchiato transparent theme
- clangd extra for C/C++
