local which_key_status_ok, wk = pcall(require, "which-key")
if not which_key_status_ok then
  return
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.schedule(TestRunner)
  end,
})

function TestRunner()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
  local test_keymaps = {}

  -- local fName = vim.fn.expand "%:p:t"
  -- local fAbsPath = vim.fn.expand "%:p"
  local pAbsPath = vim.fn.expand "%:p:h"
  -- local fRelPath = vim.fn.expand "%:."
  -- local fRelPathLine = fRelPath .. ':' .. vim.fn.line('.')

  if ft == "ruby" then
    test_keymaps = {
      t = { [[:call InvokeViaTmux("rspec", expand("%:p") . " -fdoc")<CR>]], "Test file" },
      T = { [[:call InvokeViaTmux("rspec", expand("%:p") . ":" . line('.'))<CR>]], "Test line" },
    }
  elseif ft == "go" then
    test_keymaps = {
      t = { [[:call InvokeInTestTab("go test -v ]]..pAbsPath..[[")<CR>]], "Test file" },
      T = { [[:call InvokeInTestTab("go test -v ]]..pAbsPath..[[")<CR>]], "Test file" },
    }
  elseif ft == "markdown" then
    test_keymaps = {
      t = { [[:Vale<cr>]], "Test file (Run Vale)" },
    }
  end

  if next(test_keymaps) ~= nil then
    wk.register(
      test_keymaps,
      { mode = "n", silent = true, noremap = true, buffer = bufnr, prefix = "<leader>" }
    )
  end
end
