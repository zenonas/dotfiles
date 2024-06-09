return {
  -- Quickly toggle between common alternative layouts for strings, arrays, etc.
  {
    "AndrewRadev/switch.vim",
  },
  --
  -- Smartcase replacement with S
  {"johmsalas/text-case.nvim",
    config = function()
      require("textcase").setup({})
    end,
  },

  {
    'Wansmer/treesj',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = { use_default_keymaps = false },
    event = "VeryLazy"
  },
}
