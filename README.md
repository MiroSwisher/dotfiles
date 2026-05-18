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
- backs up any existing `~/.config/nvim`
- symlinks `~/.config/nvim -> ~/.dotfiles/nvim`
- runs `nvim --headless "+Lazy! sync" +qa`
- adds `~/.local/bin` to `~/.bashrc` if needed

No `sudo` required.

## Useful Neovim commands

```vim
:Lazy        " plugin manager
:Lazy sync   " install/update plugins
:Mason       " install LSPs/formatters/linters
:LazyExtras  " enable LazyVim language extras
```

## Current Neovim stack

- Neovim
- LazyVim
- lazy.nvim
- Catppuccin Macchiato transparent theme
- clangd extra for C/C++
