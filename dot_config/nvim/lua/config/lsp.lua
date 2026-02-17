-- vim.lsp.enable("csharp")
-- vim.lsp.enable("pyright")
-- https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.config()
vim.diagnostic.config({
    -- virtual_lines = true,
    -- virtual_lines = {
    --     severity = {vim.diagnostic.severity.WARN,vim.diagnostic.severity.ERROR},
    --     current_line = true,
    -- },
    -- -- virtual_text = true,
    -- underline = true,
    -- update_in_insert = false,
    -- severity_sort = true,
    -- -- virtual_text = {
    -- --     virt_text_pos = 'right_align',
    -- --     current_line = true,
    -- --     -- virt_text_pos = 'eol_right_align',
    -- --     -- format =
    -- --     --     function(diagnostic)
    -- --     --         if diagnostic.severity == vim.diagnostic.severity.WARN then
    -- --     --             return string.format("⚠️ %s", diagnostic.message)
    -- --     --         end
    -- --     --         return diagnostic.message
    -- --     --     end
    -- -- },
    -- float = {
    --     border = "rounded",
    --     source = true,
    -- },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "🩸",
            [vim.diagnostic.severity.WARN] = "⚠️",
            [vim.diagnostic.severity.INFO] = "💬",
            [vim.diagnostic.severity.HINT] = "💡",
        },
        numhl = {
            [vim.diagnostic.severity.ERROR] = "ErrorMsg",
            [vim.diagnostic.severity.WARN] = "DiagnosticWarn",
        },
    },
})

-- Add the same capabilities to ALL server configurations.
-- Refer to :h vim.lsp.config() for more information.
-- vim.lsp.config("*", {
--     capabilities = vim.lsp.protocol.make_client_capabilities()
-- })

-- local lsp_utils = require "config/lsp_utils"
-- vim.api.nvim_create_autocmd("LspAttach", {
--   callback = function(ev)
--     local bufnr = ev.buf
--     local client = vim.lsp.get_client_by_id(ev.data.client_id)
--
--     if client then
--       lsp_utils.on_attach(client, bufnr)
--     end
--
--     if client:supports_method "textDocument/inlayHint" then
--       vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
--     end
--   end,
-- })
-- vim.g.lsp_mappings = false  -- Disable all default LSP mappings
vim.lsp.enable('nushell')
-- vim.lsp.enable('lua_ls')
vim.lsp.enable('stylua')
vim.lsp.enable('pyright')
-- vim.lsp.enable('csharp')
-- require("lspconfig").qmlls.setup {}
vim.lsp.enable('qmlls')

-- vim.lsp.enable('roslyn')
-- vim.api.nvim_create_autocmd('LspAttach', {
--     callback = function(args)
--         -- Unset 'formatexpr'
--         vim.bo[args.buf].formatexpr = nil
--         -- Unset 'omnifunc'
--         vim.bo[args.buf].omnifunc = nil
--         -- Unmap gr
--         -- vim.keymap.del('n', 'gr', { buffer = args.buf })
--     end,
-- })            { "<c-Insert>", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "Yank text" },

vim.api.nvim_create_user_command('LspCaps', function()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then
        vim.notify("No LSP attached", vim.log.levels.WARN)
        return
    end

    for _, client in ipairs(clients) do
        vim.notify(client.name .. " capabilities:", vim.log.levels.INFO)
        vim.print(client.server_capabilities)
    end
end, {})
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)

        -- Helper to create opts with description
        local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = 'LSP: ' .. desc })
        end

        -- Hover is always available
        map('n', 'sk', vim.lsp.buf.hover, 'Hover documentation')

        -- Check for specific capabilities using supports_method
        -- if client.supports_method('textDocument/definition') then
        --     map('n', 'gd', "<CMD>Glance definitions<CR>", 'Go to definition')
        -- end
        if client.supports_method('textDocument/definition') then
            map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
        end
        if client.supports_method('textDocument/definition') then
            map('n', 'gD', vim.lsp.buf.type_definition, 'Go to type definition')
        end

        -- if client.supports_method('textDocument/references') then
        --     map('n', 'g<Space>', "<cmd>FzfLua lsp_references jump1 ignore_current_line=true<cr>", 'Find references')
        -- end
        if client.supports_method('textDocument/references') then
            map('n', 'g<Space>', "<CMD>Glance references<CR>", 'Find references')
        end

        -- if client.supports_method('textDocument/implementation') then
        --     map('n', 'gi', vim.lsp.buf.implementation, 'Go to implementation')
        -- end
        if client.supports_method('textDocument/implementation') then
            map('n', 'gi', "<CMD>Glance implementations<CR>", 'Go to implementation')
        end

        -- if client.supports_method('textDocument/typeDefinition') then
        --     map('n', 'gt', vim.lsp.buf.type_definition, 'Go to type definition')
        -- end
        if client.supports_method('textDocument/typeDefinition') then
            map('n', 'gt', "<CMD>Glance type_definitions<CR>", 'Go to type definition')
        end

        if client.supports_method('textDocument/rename') then
            map('n', 'sn', vim.lsp.buf.rename, 'Rename symbol')
        end

        if client.supports_method('textDocument/codeAction') then
            map('n', 'sa', vim.lsp.buf.code_action, 'Code action')
        end

        -- Optional: Document formatting
        if client.supports_method('textDocument/formatting') then
            map('n', 'sf', vim.lsp.buf.format, 'Format document')
        end

        -- Optional: Range formatting
        if client.supports_method('textDocument/rangeFormatting') then
            map('v', 'sf', vim.lsp.buf.format, 'Format selection')
        end

        -- Workspace symbols - выбираем метод в зависимости от LSP
        if client.supports_method('workspace/symbol') then
            local symbols_filter = "Class|Function|Method|Interface|Struct|Enum"
            local use_live = client.name ~= "roslyn"  -- roslyn не поддерживает пустой query

            map('n', 'go', function()
                local method = use_live and "lsp_live_workspace_symbols" or "lsp_workspace_symbols"
                require("fzf-lua")[method]({
                    regex_filter = symbols_filter,
                })
            end, 'Workspace symbols')

            map('n', 'gO', function()
                require("fzf-lua").lsp_document_symbols({
                    regex_filter = symbols_filter,
                })
            end, 'Document symbols')
        end

        -- -- Register with which-key (if using which-key)
        -- local ok, wk = pcall(require, 'which-key')
        -- if ok then
        --     wk.add({
        --         { "k", group = "LSP", buffer = ev.buf },
        --         { "kk", desc = "Hover documentation", buffer = ev.buf },
        --         { "kn", desc = "Rename symbol", buffer = ev.buf },
        --         { "ka", desc = "Code action", buffer = ev.buf },
        --     })
        -- end
        -- vim.keymap.set('n', 'gD', '<CMD>Glance definitions<CR>')
        -- vim.keymap.set('n', 'gR', '<CMD>Glance references<CR>')
        -- vim.keymap.set('n', 'gY', '<CMD>Glance type_definitions<CR>')
        -- vim.keymap.set('n', 'gM', '<CMD>Glance implementations<CR>')
    end,
})
-- vim.api.nvim_create_autocmd("LspAttach", {
--     group = vim.api.nvim_create_augroup("lsp-attach", { clear = false }),
--     -- Create a function that lets us more easily define mappings specific LSP related items.
--     -- It sets the mode, buffer and description for us each time.
--     callback = function(event)
--         local map = function(keys, func, desc)
--             vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
--         end
--         -- print("LSP ATTACHED!")
--         -- Check if it's C# LSP
--         -- local client = vim.lsp.get_client_by_id(event.data.client_id)
--         -- if client.name ~= "csharp_ls" then
--         -- 	local root_dir = client.config.root_dir .. "/Assets"
--         -- 	if root_dir then
--         -- 		-- Set Neovim's working directory
--         -- 		vim.cmd("cd " .. root_dir)
--         -- 	end
--         -- 	-- Configure Neo-tree to show only .cs files
--         -- 	local fs_config = require("neo-tree").config.filesystem
--         -- 	fs_config.filtered_items.custom = {
--         -- 		{
--         -- 			pattern = function(name, path)
--         -- 				-- Hide everything that doesn't end with .cs
--         -- 				return not string.match(name, "%.cs$")
--         -- 			end,
--         -- 			display_name = "Non-C# files",
--         -- 		},
--         -- 	}
--         --
--         -- 	require("neo-tree.sources.filesystem.commands").refresh(require("neo-tree.sources.manager").get_state("filesystem"))
--         -- 	-- Refresh Neo-tree to apply changes
--         -- 	-- require("neo-tree.sources.filesystem").refresh()
--         -- else
--         -- 	-- WARN: This is not Goto Definition, this is Goto Declaration.
--         -- 	--  For example, in C this would take you to the header
--         -- 	map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
--         -- end
--
--         -- Jump to the definition of the word under your cursor.
--         --  This is where a variable was first declared, or where a function is defined, etc.
--         --  To jump back, press <C-T>.
--         -- map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
--
--         -- Find references for the word under your cursor.
--         -- map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
--
--         -- Jump to the implementation of the word under your cursor.
--         --  Useful when your language has ways of declaring types without an actual implementation.
--         -- map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
--
--         -- Jump to the type of the word under your cursor.
--         --  Useful when you're not sure what type a variable is and you want to see
--         --  the definition of its *type*, not where it was *defined*.
--         -- map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
--
--         -- Fuzzy find all the symbols in your current document.
--         --  Symbols are things like variables, functions, types, etc.
--         -- map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
--         -- local fzf = require("fzf-lua")
--         -- if fzf ~= nil then
--         --     --FzfLua
--         --     map("<leader>cw", fzf.lsp_live_workspace_symbols, "[C]ode [W]orkspace Symbols")
--         --     map("<leader>cW", fzf.lsp_workspace_symbols, "[Code] [W]orkspace Symbols")
--         --     map("gd", "<cmd>FzfLua lsp_definitions jump1 ignore_current_line=true<cr>", "[G]oto [D]efinition")
--         --     map("grr", "<cmd>FzfLua lsp_references jump1 ignore_current_line=true<cr>", "References")
--         --     map("gri", "<cmd>FzfLua lsp_implementations jump1 ignore_current_line=true<cr>", "Goto Implementation")
--         --     map(
--         --         "gy",
--         --         "<cmd>FzfLua lsp_typedefs        jump_to_single_result=true ignore_current_line=true<cr>",
--         --         "Goto T[y]pe Definition"
--         --     )
--         -- else
--         --     -- Picker
--         --     map("gd", function()
--         --         Snacks.picker.lsp_definitions()
--         --     end, "Goto Definition")
--         --     map("grr", function()
--         --         Snacks.picker.lsp_references()
--         --     end, "References")
--         --     map("gri", function()
--         --         Snacks.picker.lsp_implementations()
--         --     end, "Goto Implementation")
--         --     map("gy", function()
--         --         Snacks.picker.lsp_type_definitions()
--         --     end, "Goto T[y]pe Definition")
--         --     map("<leader>ss", function()
--         --         Snacks.picker.lsp_symbols()
--         --     end, "LSP Symbols")
--         -- end
--         -- map("<leader>ds", fzf.lsp_document_symbols, "[D]ocument [S]ymbols")
--
--         -- Fuzzy find all the symbols in your current workspace
--         --  Similar to document symbols, except searches over your whole project.
--         -- map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
--
--         -- LSP
--
--         -- map("<leader>cr", vim.lsp.buf.rename, "[C]ode [R]ename")
--         -- map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
--         --
--         -- vim.keymap.set("n", "<leader>cp", function()
--         --     local workspace_folders = vim.lsp.buf.list_workspace_folders()
--         --     local current_workspace = workpace_folders[1] -- Assuming there's only one folder
--         --     print("Current workspace path: " .. (current_workspace or "None"))
--         -- end, { noremap = true })
--         --
--         -- vim.keymap.set("n", "<leader>ct", function()
--         --     local lsp_util = vim.lsp.util
--         --
--         --     -- Query the LSP for document symbols
--         --     local params = { textDocument = vim.lsp.util.make_text_document_params() }
--         --     vim.lsp.buf_request(0, "textDocument/documentSymbol", params, function(err, result, ctx)
--         --         if err or not result then
--         --             vim.notify("No symbols found", vim.log.levels.WARN)
--         --             return
--         --         end
--         --
--         --         -- Filter only classes and structs
--         --         local items = {}
--         --         for _, symbol in ipairs(result) do
--         --             print(symbol)
--         --             if symbol.kind == 5 or symbol.kind == 6 then -- 5: Class, 6: Struct
--         --                 table.insert(items, {
--         --                     display = string.format(
--         --                         "%s (%s:%d:%d)",
--         --                         symbol.name,
--         --                         ctx.bufnr,
--         --                         symbol.range.start.line + 1,
--         --                         symbol.range.start.character
--         --                     ),
--         --                     lnum = symbol.range.start.line + 1,
--         --                     col = symbol.range.start.character + 1,
--         --                     filename = vim.api.nvim_buf_get_name(ctx.bufnr),
--         --                 })
--         --             end
--         --         end
--         --
--         --         -- Check if any items match
--         --         if #items == 0 then
--         --             vim.notify("No classes or structs found", vim.log.levels.WARN)
--         --             return
--         --         end
--         --
--         --         -- Pass items to fzf
--         --         fzf.fzf_exec(items, {
--         --             prompt = "Classes/Structs> ",
--         --             previewer = false,
--         --             -- Define a key action to jump to the location
--         --             actions = {
--         --                 ["default"] = function(selected)
--         --                     local selected_item = items[tonumber(selected[1])]
--         --                     if selected_item then
--         --                         vim.cmd("edit " .. selected_item.filename)
--         --                         vim.fn.cursor(selected_item.lnum, selected_item.col)
--         --                     end
--         --                 end,
--         --             },
--         --         })
--         --     end)
--         -- end, { noremap = true, silent = true })
--
--         -- Rename the variable under your cursor
--         --  Most Language Servers support renaming across files, etc.
--         -- map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
--
--         -- Execute a code action, usually your cursor needs to be on top of an error
--         -- or a suggestion from your LSP for this to activate.
--
--         -- Opens a popup that displays documentation about the word under your cursor
--         --  See `:help K` for why this keymap
--         -- map("K", vim.lsp.buf.hover, "Hover Documentation")
--
--         -- map("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
--
--         -- local function get_messages_lines()
--         --   local messages = vim.fn.execute("messages")
--         --   local lines = vim.split(messages, "\n") -- Split by newline
--         --   return lines
--         -- end
--         --
--         -- vim.keymap.set("n", "<leader>m", function()
--         --   local fzf = require("fzf-lua")
--         --   --
--         --   fzf.fzf_exec(function(fzf_cb)
--         --     -- Get all messages as a single string
--         --     local messages = vim.fn.execute("messages")
--         --
--         --     -- Split into individual messages and iterate
--         --     for message in messages:gmatch("[^\r\n]+") do
--         --       fzf_cb(message)
--         --     end
--         --     fzf_cb()
--         --   end)
--         -- end, { noremap = true, silent = true })
--         -- vim.keymap.set("n", "<leader>m", function()
--         --   vim.fn.execute(":mes")
--         -- end, { noremap = true, silent = true })
--         -- Simple way - just show messages
--         -- vim.keymap.set("n", "<leader>m", ":messages<CR>", { noremap = true })
--
--
--         -- The following two autocommands are used to highlight references of the
--         -- word under your cursor when your cursor rests there for a little while.
--         --    See `:help CursorHold` for information about when this is executed
--         --
--         -- When you move your cursor, the highlights will be cleared (the second autocommand).
--         -- local client = vim.lsp.get_client_by_id(event.data.client_id)
--         -- if client and client.server_capabilities.documentHighlightProvider then
--         --   vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
--         --     buffer = event.buf,
--         --     callback = vim.lsp.buf.document_highlight,
--         --   })
--         --
--         --   vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
--         --     buffer = event.buf,
--         --     callback = vim.lsp.buf.clear_references,
--         --   })
--         -- end
--     end,
-- })
