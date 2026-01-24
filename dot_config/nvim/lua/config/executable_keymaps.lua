-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

-- -- Move lines up/down with Ctrl + j/k in normal mode
-- vim.keymap.set("n", "<C-j>", ":m .+1<CR>==", { noremap = true, silent = true, desc = "Move line down" })
-- vim.keymap.set("n", "<C-k>", ":m .-2<CR>==", { noremap = true, silent = true, desc = "Move line up" })
--
-- -- Move lines up/down with Ctrl + j/k in visual mode
-- vim.keymap.set("v", "<C-j>", ":m '>+1<CR>gv=gv", { noremap = true, silent = true, desc = "Move selection down" })
-- vim.keymap.set("v", "<C-k>", ":m '<-2<CR>gv=gv", { noremap = true, silent = true, desc = "Move selection up" })
--
-- quitting
-- Remap ZZ to close all buffers and quit Neovim
vim.keymap.set("n", "ZZ", ":wqa<CR>", { noremap = true, silent = true, desc = "Close all buffers and quit Neovim" })
vim.keymap.set("n", "<S-C-s>", ":wall<CR>", { noremap = true, silent = true, desc = "[S]ave all buffers" })

-- ctrl+q exit from anywhere
-- Normal, Insert, Visual
vim.keymap.set({ "n", "i", "v" }, "<C-q>", "<Esc>:qa<CR>", { noremap = true, silent = true, desc = "Quit Neovim" })
-- Terminal
vim.keymap.set("t", "<C-q>", "<C-\\><C-n>:qa<CR>", { noremap = true, silent = true, desc = "Quit Neovim" })
-- Command-line (search / :)
vim.keymap.set("c", "<C-q>", "<C-c>:qa<CR>", { noremap = true, silent = true, desc = "Quit Neovim from command-line" })

-- smart window closing
-- vim.keymap.set("n", "<S-BS>", function()
--   if #vim.api.nvim_list_wins() > 1 then
--     vim.cmd("close")
--   else
--     print("Can't close the last window")
--   end
-- end, { desc = "Smart close window" })
local smart_close_window = function()
    if #vim.api.nvim_list_wins() > 1 then
        vim.cmd("close")
    else
        print("Can't close the last window")
    end
end
vim.keymap.set("n", "<S-M-p>", smart_close_window, { desc = "Smart close window" })
vim.keymap.set("n", "<C-p>", smart_close_window, { desc = "Smart close window" })

-- buffer closing
-- vim.keymap.set("n", "<M-BS>", function()
--   Snacks.bufdelete()
-- end, { noremap = true, silent = true, desc = "Delete Buffer" })
vim.keymap.set("n", "<M-p>", function()
    Snacks.bufdelete()
end, { noremap = true, silent = true, desc = "Delete Buffer" })

-- vim.keymap.set("n", "<a-j>", "m`o<Esc>``")
-- vim.keymap.set("n", "<a-k>", "m`O<Esc>``")
-- vim.keymap.set("n", "<a-j>", "m`o<Esc>``")
-- vim.keymap.set("n", "<a-k>", "m`O<Esc>``")


vim.keymap.set("n", "<leader>u\\r", function()
    package.loaded["confetti"] = nil
    require("confetti").load()
end, { desc = "Reload color configuration" })
-- vim.keymap.set("n", "<leader>\\i", function()
--     print(vim.inspect(vim.inspect_pos()))
-- end, { desc = "highlight inspect pos" })
vim.keymap.set("n", "<leader>u\\s", function()
    print(vim.inspect(vim.show_pos()))
end, { desc = "highlight show pos" })

require("config.handsdown").setup()

local copyfile = require("config.copyfile")
-- Copy current buffer/file
vim.keymap.set("n", "kc", copyfile.copy_file, { desc = "Copy file/buffer to clipboard" })


vim.keymap.set("n", "<leader>m", function() require("noice").cmd("all") end, {desc = "Noice All" })

--test
-- vim.keymap.set("n", "<leader>uv", function()
--     local new_config = not vim.diagnostic.config().virtual_lines
--     vim.diagnostic.config({ virtual_lines = new_config })
-- end, { desc = "Toggle diagnostic virtual_lines" })
-- print("my keymap is loaded")
-- vim.api.nvim_create_autocmd("User", {
--   pattern = "LazyLoad",
--   callback = function(args)
--     if args.data == "flash.nvim" then
--       print("🔦 flash.nvim was just loaded!")
--     end
--   end,
-- })

