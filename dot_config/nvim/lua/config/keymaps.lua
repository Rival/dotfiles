require("config.base_keymaps")
require("config.mobile")

-- Plugin-dependent keymaps below

vim.keymap.set("n", "<M-p>", function()
  Snacks.bufdelete()
end, { noremap = true, silent = true, desc = "Delete Buffer" })

vim.keymap.set("n", "<leader>u\\r", function()
  package.loaded["confetti"] = nil
  require("confetti").load()
end, { desc = "Reload color configuration" })

vim.keymap.set("n", "<leader>u\\s", function()
  print(vim.inspect(vim.show_pos()))
end, { desc = "highlight show pos" })

vim.keymap.set("n", "<leader>u<C-l>", function()
  vim.cmd("e ~/.config/nvim/themes/confetti.nvim/lua/lush_theme/confetti.lua")
end, { desc = "Open confetti theme" })

require("config.handsdown").setup()

local copyfile = require("config.copyfile")
vim.keymap.set("n", "kc", copyfile.copy_file, { desc = "Copy file/buffer to clipboard" })

vim.keymap.set("n", "<leader>m", function()
  local noice_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("noice") or vim.api.nvim_buf_get_option(buf, "filetype") == "noice" then
      noice_win = win
      break
    end
  end

  if noice_win then
    vim.api.nvim_win_close(noice_win, true)
    vim.schedule(function()
      pcall(function()
        require("lualine").refresh({
          scope = "all",
          place = { "statusline" },
          force = true,
        })
      end)
      vim.cmd("redrawstatus!")
    end)
  else
    require("noice").cmd("all")
    vim.schedule(function()
      vim.cmd("normal! G")
    end)
  end
end, { desc = "Toggle Noice Log" })
