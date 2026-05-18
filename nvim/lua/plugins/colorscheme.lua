return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "macchiato",
      transparent_background = true,
      float = {
        transparent = true,
      },
      integrations = {
        snacks = true,
        noice = true,
        mason = true,
        native_lsp = {
          enabled = true,
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-macchiato",
    },
  },
}
