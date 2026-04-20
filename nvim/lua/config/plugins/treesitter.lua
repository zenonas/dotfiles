return {
  "nvim-treesitter",
  beforeAll = function()
    _G.Paq.add({
      {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        build = ":TSUpdate",
      },
      {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
      },
    })
  end,
  load = function(name)
    vim.cmd.packadd(name)
    vim.cmd.packadd("nvim-treesitter-textobjects")
  end,
  after = function()
    -- Note that some queries have dependencies, but if a dependency is
    -- deleted, it won't automatically be reinstalled
    require("nvim-treesitter").install({
      "bash",
      "comment",
      "css",
      "dockerfile",
      "elm",
      "gitignore",
      "go",
      "gomod",
      "html",
      "javascript",
      "json",
      "lua",
      "make",
      "markdown",
      "markdown_inline",
      "proto",
      "php",
      "python",
      "regex",
      "ruby",
      "scss",
      "sql",
      "terraform",
      "toml",
      "tsx",
      "typescript",
      "vim",
      "yaml",
    })

    require("nvim-treesitter-textobjects").setup({
      select = {
        lookahead = true,
      },
    })

    local function map(lhs, obj)
      vim.keymap.set({ "x", "o" }, lhs, function()
        require("nvim-treesitter-textobjects.select").select_textobject(
          obj,
          "textobjects"
        )
      end)
    end

    map("aa", "@parameter.outer")
    map("ia", "@parameter.inner")
    map("af", "@function.outer")
    map("if", "@function.inner")
    map("ac", "@class.outer")
    map("ic", "@class.inner")

    -- Register the todotxt parser to be used for text filetypes
    vim.treesitter.language.register("todotxt", "text")

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(ev)
        if pcall(vim.treesitter.start) then
          -- Set indentexpr for queries that have an indents.scm, check in
          -- ~/.local/share/nvim/site/queries/QUERY/
          -- Hopefully this will happen automatically in the future
          if
            ({
              c = true,
              lua = true,
              markdown = true,
              python = true,
              query = true,
              xml = true,
            })[ev.match]
            then
              vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end
        end,
      })
    end,
  "andymass/vim-matchup",                       -- Extend % for more languages
}
