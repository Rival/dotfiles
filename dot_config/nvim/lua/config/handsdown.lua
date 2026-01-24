-- Leaders are set in init.lua before lazy.nvim loads

local function escape(str)
  local escape_chars = [[;,."|\]]
  return vim.fn.escape(str, escape_chars)
end

-- Russian → Prometeus mapping (based on physical key positions)
-- Physical key: QWERTY → Russian → Prometeus
local prometeus =       [[vpdlx/,.;zsnthkqeaicfwgmj-uoyb]]
local prometeus_shift = [[VPDLX?<>:ZSNTHKQEAICFWGMJ_UOYB]]
local ru =              [[йцукенгшщзфывапролджячсмитьбю.]]
local ru_shift =        [[ЙЦУКЕНГШЩЗФЫВАПРОЛДЖЯЧСМИТЬБЮ,]]

vim.opt.langmap = vim.fn.join({
  escape(ru_shift) .. ';' .. escape(prometeus_shift),
  escape(ru) .. ';' .. escape(prometeus),
}, ',')

local handsdown = {}

local mappings = {
    { modes = { "n", "o", "x" }, lhs = "n", rhs = "h", desc = "Left (h)" },
    -- Up/down/left/right
    { modes = { "n", "o", "x" }, lhs = "n", rhs = "h", desc = "Left (h)" },
    { modes = { "n", "o", "x" }, lhs = "d", rhs = "k", desc = "Up (k)" },
    { modes = { "n", "o", "x" }, lhs = "t", rhs = "j", desc = "Down (j)" },
    { modes = { "n", "o", "x" }, lhs = "h", rhs = "l", desc = "Right (l)" },
    --
    -- { modes = { "n", "o", "x" }, lhs = ";", rhs = ".", desc = "Repeat" },

    -- Jumplist navigation
    -- { modes = { "n" }, lhs = "<C-u>", rhs = "<C-i>", desc = "Jumplist forward" },
    -- { modes = { "n" }, lhs = "<C-e>", rhs = "<C-o>", desc = "Jumplist forward" },

    -- -- Word left/right
    { modes = { "n", "o", "x" }, lhs = "w", rhs = "b", desc = "Word back" },
    { modes = { "n", "o", "x" }, lhs = "m", rhs = "w", desc = "Word forward" },
    { modes = { "n", "o", "v" }, lhs = "<S-w>", rhs = "B", desc = "WORD back" },
    { modes = { "n", "o", "v" }, lhs = "<S-m>", rhs = "W", desc = "WORD forward" },
    --
    -- -- End of word left/right
    { modes = { "n", "o", "x" }, lhs = "<M-w>", rhs = "ge", desc = "End of word back" },
    { modes = { "n", "o", "x" }, lhs = "<M-S-m>", rhs = "gE", desc = "End of WORD back" },
    { modes = { "n", "o", "x" }, lhs = "<M-w>", rhs = "e", desc = "End of word forward" },
    { modes = { "n", "o", "x" }, lhs = "<M-S-m>", rhs = "E", desc = "End of WORD forward" },

    -- Change
    -- { modes = { "n", "x" }, lhs = "H", rhs = "C" },
    -- { modes = { "n", "x" }, lhs = "H", rhs = "C" },
    -- { modes = { "n", "x" }, lhs = "H", rhs = "C" },
    -- Text objects
    -- diw is drw. daw is now dtw.
    -- { modes = { "o", "v" }, lhs = "r", rhs = "i", desc = "O/V mode: inner (i)" },
    -- { modes = { "o", "v" }, lhs = "t", rhs = "a", desc = "O/V mode: a/an (a)" },
    -- Move visual replace from 'r' to 'R'
    -- { modes = { "o", "v" }, lhs = "R", rhs = "r", desc = "Replace" },

    -- Folds
    -- { modes = { "n", "x" }, lhs = "b", rhs = "z" },
    -- { modes = { "n", "x" }, lhs = "bb", rhs = "zb", desc = "Scroll line and cursor to bottom" },
    -- { modes = { "n", "x" }, lhs = "bu", rhs = "zk", desc = "Move up to fold" },
    -- { modes = { "n", "x" }, lhs = "be", rhs = "zj", desc = "Move down to fold" },

    -- Copy/paste
    -- { modes = { "n", "o", "x" }, lhs = "c", rhs = "y" },

    -- { modes = { "n", "o", "x" }, lhs = "h", rhs = "c" },
    -- { modes = { "n", "x" }, lhs = "H", rhs = "C" },

    -- Visual mode
    -- { modes = { "n", "x" }, lhs = "b", rhs = "v" },
    -- { modes = { "n", "x" }, lhs = "B", rhs = "V" },
    -- { modes = { "n", "x" }, lhs = "<C-b>", rhs = "<C-v>" },

    -- Insert in Visual mode
    -- { modes = { "v" }, lhs = "S", rhs = "I" },

    -- Search
    -- { modes = { "n", "o", "x" }, lhs = "k", rhs = "n" },
    -- { modes = { "n", "o", "x" }, lhs = "K", rhs = "N" },

    -- Fix diffput (t for 'transfer')
    -- { modes = { "n" }, lhs = "dt", rhs = "de", desc = "diffput (t for 'transfer')" },

    -- Misc overridden keys must be prefixed with g
    -- { modes = { "n", "x" }, lhs = "gb", rhs = "gx" },
    -- { modes = { "n", "x" }, lhs = "gx", rhs = "gv" },--select visual

    -- { modes = { "n", "x" }, lhs = "gU", rhs = "U" },
    -- { modes = { "n", "x" }, lhs = "gQ", rhs = "Q" },
    -- { modes = { "n", "x" }, lhs = "gK", rhs = "K" },
    -- extra alias
    -- { modes = { "n" }, lhs = "gh", rhs = "K" },
    -- { modes = { "x" }, lhs = "gh", rhs = "K" },
    -- { modes = { "n" }, lhs = "T", rhs = "H" },
    -- { modes = { "n" }, lhs = "R", rhs = "L" },  
    -- { modes = { "n" }, lhs = "<C-l>", rhs = "<C-b>", desc = "Screen back" },
    -- { modes = { "n" }, lhs = "<C-h>", rhs = "<C-f>", desc = "Screen forward" },
    -- Screen navigation (mouse thumb buttons)
    { modes = { "n", "t", "i"}, lhs = "<MouseDown-4>", rhs = "<C-b>", desc = "Screen back (mouse button 4)" },
    { modes = { "n", "t", "i"  }, lhs = "<MouseDown-5>", rhs = "<C-f>", desc = "Screen forward (mouse button 5)" },
    -- Window navigation
    { modes = { "n", "t", "i"  }, lhs = "<C-n>", rhs = "<C-w>h" },
    { modes = { "n", "t", "i"  }, lhs = "<C-h>", rhs = "<C-w>l" },
    { modes = { "n", "t", "i"  }, lhs = "<C-t>", rhs = "<C-w>j" },
    { modes = { "n", "t", "i"  }, lhs = "<C-d>", rhs = "<C-w>k" },
    -- Insert/terminal mode window navigation
    -- { modes = { "i", "t" }, lhs = "<C-h>", rhs = "<C-w>h", desc = "Window right" },
    -- { modes = { "i", "t" }, lhs = "<C-n>", rhs = "<C-w>l", desc = "Window left" },

    -- { modes = { "n" }, lhs = "<C-w>r", rhs = "<C-w>h" },
    -- { modes = { "n" }, lhs = "<C-w>f", rhs = "<C-w>k" },
    -- { modes = { "n" }, lhs = "<C-w>s", rhs = "<C-w>j" },
    -- { modes = { "n" }, lhs = "<C-w>t", rhs = "<C-w>l" },
    -- Move window
    { modes = { "n" }, lhs = "<C-M-n>", rhs = "<C-w>H" },
    { modes = { "n" }, lhs = "<C-M-d>", rhs = "<C-w>K" },
    { modes = { "n" }, lhs = "<C-M-t>", rhs = "<C-w>J" },
    { modes = { "n" }, lhs = "<C-M-h>", rhs = "<C-w>L" },
    -- Disable spawning empty buffer
    { modes = { "n" }, lhs = "<C-w><C-n>", rhs = "<nop>" },
    { modes = { "n" }, lhs = "<C-w>I", rhs = "<C-w>L" },

    { modes = { "n", "x" }, lhs = "<M-k>", rhs = "<nop>" },
    { modes = { "n", "x" }, lhs = "<M-j>", rhs = "<nop>" },
    -- { modes = { "n" }, lhs = "<Space>f", rhs = "<Space>v" },
    -- { modes = { "n","v","i" }, lhs = "<M-t>", rhs = "<M-j>" },
    -- { modes = { "n","v","i" }, lhs = "<M-d>", rhs = "<M-k>" },
    -- -- Next previous buffer
    -- { modes = { "n" }, lhs = "<S-r>", rhs = "<S-h>" },
    -- { modes = { "n" }, lhs = "<S-t>", rhs = "<S-l>" },

    -- Add lines (cursor stays on current line)
    { modes = { "n" }, lhs = "<C-S-b>", rhs = function() vim.fn.append(vim.fn.line('.')-1, '') end, desc = "Add line above" },
    { modes = { "n" }, lhs = "<C-b>", rhs = function() vim.fn.append(vim.fn.line('.'), '') end, desc = "Add line below" },
    { modes = { "n" }, lhs = "<C-A-d>", rhs = function() vim.fn.append(vim.fn.line('.')-1, '') end, desc = "Add line above" },
    { modes = { "n" }, lhs = "<C-A-t>", rhs = function() vim.fn.append(vim.fn.line('.'), '') end, desc = "Add line below" },
    -- map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
    -- map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
    -- { modes = { "n" }, lhs = "h", rhs = "f" },
    -- { modes = { "n" }, lhs = "e", rhs = "s" },
    -- { modes = { "n", "x", "o" Экологичный AI: Оптимизация кода для снижения энергопотребления устройств, что полезно для "зеленой" репутации компании.}, lhs = "y", rhs = "f" },
    -- { modes = { "n", "x", "o" }, lhs = "Y", rhs = "F" },
    -- { modes = { "n", "x", "o" }, lhs = "l", rhs = "t" },
    -- { modes = { "n", "x", "o" }, lhs = "L", rhs = "T" },
}

function handsdown.setup(_)
    -- colemak.apply()
    vim.api.nvim_create_user_command("HandsdownEnable", handsdown.apply, { desc = "applies colemak mappings" })
    vim.api.nvim_create_user_command("HandsdownDisable", handsdown.unapply, { desc = "removes colemak mappings" })
end

function handsdown.apply()
    for _, mapping in pairs(mappings) do
        vim.keymap.set(mapping.modes, mapping.lhs, mapping.rhs, { desc = mapping.desc })
    end

    handsdown.custom_mappings()
    -- print("handsdown applied")
    -- vim.keymap.set({ "n", "x", "o" }, "h", function()
    --   require("flash").jump({
    --     search = { forward = true, wrap = false, multi_window = false },
    --   })
    -- end, { noremap = true, silent = true, desc = "Flash" })
    -- vim.keymap.set({ "n", "x", "o" }, "l", function()
    --   require("flash").jump({
    --     search = { forward = false, wrap = false, multi_window = false },
    --   })
    -- end, { noremap = true, silent = true, desc = "Flash" })
    -- { "s", mode = , function() require("flash").jump() end, desc = "Flash" },
    -- { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    -- { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    -- { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    -- { "<c-l>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
end

function handsdown.custom_mappings()
    local map = vim.keymap.set
    map("n", "<M-h>", "<cmd>bnext<cr>", { desc = "Prev buffer" })
    map("n", "<M-n>", "<cmd>bprevious<cr>", { desc = "Next buffer" })
    map("n", "L", "N", { desc = "Prev search result" })

    map('n', '<C-k>', '<C-d>', { noremap = true, silent = true, desc = "Scroll down" })

    map('n', '<A-k>', '<Esc>yiw', { noremap = true, silent = true, desc = "Yahk word" })
    map('n', '<A-j>', '<Esc>viwP', { noremap = true, silent = true, desc = "Paste in word" })
    -- vim.keymap.del('n', 'k');
    -- -- moving lines
    -- map("n", "<A-d>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
    -- map("i", "<A-d>", "<Esc><Cmd>m .-2<cr>==gi", { desc = "Move line down" })
    -- map("v", "<A-d>", ":<C-u>execute \"'<lt>,'>move '<lt>-\" . (v:count1 + 1)<CR>gv=gv", { desc = "Move lines up" })
    --
    -- map("n", "<A-t>", "<Cmd>m .+1<cr>==", { desc = "Move line down" })
    -- map("i", "<A-t>", "<Esc><Cmd>m .+1<cr>==gi", { desc = "Move line down" })
    -- map("v", "<A-t>", ":<C-u>execute \"'<lt>,'>move '>+\" . (v:count1 + 1)<CR>gv=gv", { desc = "Move lines up" })

    -- Move lines up/down with Ctrl + j/k in normal mode
    vim.keymap.set("n", "<M-t>", ":m .+1<CR>==", { noremap = true, silent = true, desc = "Move line down" })
    vim.keymap.set("n", "<M-d>", ":m .-2<CR>==", { noremap = true, silent = true, desc = "Move line up" })

    vim.keymap.set("v", "<M-t>", ":m '>+1<CR>gv=gv", { noremap = true, silent = true, desc = "Move selection down" })
    -- Move lines up/down with Ctrl + j/k in visual mode
    vim.keymap.set("v", "<M-d>", ":m '<-2<CR>gv=gv", { noremap = true, silent = true, desc = "Move selection up" })

    -- Horizontal split
    map("n", "<leader>wh", ":split<CR>", { desc = "Horizontal split" })
    --Horizontal split
    map("n", "<leader>wt", ":vsplit<CR>", { desc = " Vertical split" })

    -- Increase width
    map("n", "<A-S-h>", ":vertical resize +5<CR>", { silent = true, desc = "Increase width"})
    -- Decrease width
    map("n", "<A-S-n>", ":vertical resize -5<CR>", { silent = true, desc = "Increase width"}) 
    -- Increase height
    map("n", "<A-S-d>", ":resize +5<CR>",  { silent = true, desc = "Increase height"}) 
    -- Decrease height
    map("n", "<A-S-t>", ":resize -5<CR>", { silent = true, desc = "Increase height"}) 

    -- -- -- Normal mode
    -- vim.keymap.del("n", "<leader>wL")
    -- vim.keymap.del("n", "<leader>wI")
end

function handsdown.unapply()
    for _, mapping in pairs(mappings) do
        vim.keymap.del(mapping.modes, mapping.lhs)
    end
end

return handsdown
