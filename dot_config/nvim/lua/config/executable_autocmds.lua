-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- local setup_unity_dap = require("config.unihug.dap-unity")
-- -- Set up the autocmd
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "cs",
--   callback = setup_unity_dap,
-- })

-- require("config.layout_switcher")

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
  -- Create a function that lets us more easily define mappings specific LSP related items.
  -- It sets the mode, buffer and description for us each time.
  callback = function(event)
    -- Check if it's C# LSP
    -- local client = vim.lsp.get_client_by_id(event.data.client_id)
    -- if client.name == "csharp_ls" then -- Changed from != to ==
    --
    -- end
  end,
})

-- vim.api.nvim_create_autocmd("DirChanged", {
--   callback = function(args)
--     print("Directory changed!")
--     print("New dir:", args.file)
--     print("Event triggered by:", vim.inspect(debug.traceback()))
--   end,
-- })
vim.api.nvim_create_autocmd("FileType", {
  pattern = "cs", -- replace with your file type
  callback = function()
    vim.opt_local.tabstop = 4 -- Number of spaces a tab counts for
    vim.opt_local.shiftwidth = 4 -- Number of spaces a tab counts for
    vim.opt_local.softtabstop = 4 -- Number of spaces a tab counts for while editing

    vim.opt_local.expandtab = true
    vim.opt_local.smartindent = true -- Optional: Other C# specific settings
    vim.opt_local.colorcolumn = "120" -- Visual marker at 120 characters
    vim.opt_local.textwidth = 120 -- Line wrapping at 120 characterse
    -- Set the character(s) to show at the start of wrapped lines
    vim.opt.showbreak = "↪" -- You can use other characters like '⤷ ' or '»  ' or '▸ 'o

    -- Make wrapped lines easier to navigate
    vim.opt.linebreak = true -- Break lines at word boundaries
    vim.opt.breakindent = true -- Maintain indent of wrapped lines
    -- Optional: Enhanced wrapped line display
    vim.opt.breakindentopt = "shift:2" -- Indent wrapped lines an additional 2 spaces
    vim.opt.formatoptions:append("l") -- Don't break long lines in insert mode
    -- Or create a custom highlight group specifically for showbreak
    -- vim.api.nvim_command("highlight ShowBreak guifg=#87ff87") -- Green
    -- vim.b.autoformat = false
    --     vim.api.nvim_clear_autocmds({
    --         group = "noice_lsp_progress",
    --         event = "LspProgress",
    --         pattern = "*",
    --     })
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "lua", -- replace with your file type
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true
    vim.opt_local.smartindent = true
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qml",
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.expandtab = true
  end,
})

vim.filetype.add({
  extension = {
    plist = "xml",
    meta = "yaml",
  },
})
-- vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
--   pattern = "*.plist",
--   command = "set filetype=xml",
-- })
-- vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
--   pattern = "*.meta",
--   command = "set filetype=yaml",
-- })
-- we hide lualine when seraching so it will not cover up serach
vim.api.nvim_create_autocmd("CmdlineEnter", {
  pattern = { "/", "?" },
  callback = function()
    vim.o.laststatus = 0
  end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
  pattern = { "/", "?" },
  callback = function()
    vim.o.laststatus = 3
  end,
})
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    vim.defer_fn(function()
      -- This runs 500ms after "VeryLazy"
      -- print("Extra delay after VeryLazy")
      require("config.handsdown").apply()
    end, 100)
  end,
})

-- Auto-enter insert mode when sidekick opens
vim.api.nvim_create_autocmd("FileType", {
  pattern = "sidekick",
  callback = function()
    -- Auto-enter insert mode
    vim.cmd("startinsert")

    -- Make it easier to close sidekick with Escape in normal mode
    vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = true, silent = true })

    -- Optional: Use Ctrl+c to close from insert mode
    vim.keymap.set("i", "<C-c>", "<Esc><cmd>close<cr>", { buffer = true, silent = true })
  end,
})
-- -- HOTFIX: suppress noice errors
-- vim.api.nvim_create_autocmd("FileType", {
--     pattern = { "cs" },
--     callback = function()
--         vim.api.nvim_clear_autocmds({
--             group = "noice_lsp_progress",
--             event = "LspProgress",
--             pattern = "*",
--         })
--     end,
-- })
