-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.cmd("source ~/.config/nvim/vim/common.vim")

if vim.g.neovide then
  require("config.neovide")
end
--KITTY integration upating tab title with file names
-- if vim.env.KITTY_PID then
--     require("config.kitty-integration")
-- end
if vim.env.KITTY_PID then
  local kitty = require("config.kitty-integration")
  kitty.setup() -- Explicitly call setup
else
  print("Kitty integration not initialized")
end

-- Set the keymap to Russian JCUKEN
vim.opt.keymap = "russian-jcukenwin"
vim.env.LANG = "en_US.UTF-8"

-- Start in English (0) for both insert and search
vim.opt.iminsert = 0
vim.opt.imsearch = 0
-- For global setting (affects all floating windows)
vim.opt.winblend = 15 -- value from 0 (opaque) to 100 (transparent)
--fixes too fast scroll
vim.opt.mousescroll = "ver:1,hor:1"  -- Default is ver:3,hor:6

vim.o.timeout = true -- keypresses sequence timeout
vim.o.timeoutlen = 500
vim.g.autoformat = false

-- Enable project-local configuration files
vim.o.exrc = true
vim.o.secure = true

-- -- In lua/config/keymaps.lua (or in a plugin's configuration file)
-- local keys = require("lazyvim.plugins.lsp.keymaps").get()
--
-- -- Disable the default "K" keymap
-- keys[#keys + 1] = { "K", false }
--
-- -- Add a new keymap for "K" with a different function
-- keys[#keys + 1] = { "K", "<cmd>echo 'hello'<cr>" }
-- vim.o.winborder = "rounded"
require("config.lsp")
--🔨⚙️👻📁📄📇📃📜💡🔎🩸🩺💬💭🗯⛔️📛❕❗️‼️⁉️💥🧧
--🐤🧶🐣🐥🦆🐦‍🔥🐓🦚🪿🦢📟⌨️💻🪟🃏🦞⚠️📌🧨📞☎️📍🏮

-- vim.lsp.set_log_level("debug")
