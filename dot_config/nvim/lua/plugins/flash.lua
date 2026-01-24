return {
    "folke/flash.nvim",
    event = "VeryLazy",
    -- event = nil,
    -- event = "b",
    lazy = true,
    -- init = function()
    --   print("flash applied")
    --   -- -- This runs *before* the plugin is loaded
    --   -- -- vim.keymap.set({ "n", "x", "o" }, "L", "<nop>") -- unmap or disable default behavior
    --   -- vim.keymap.del({ "n", "x", "o" }, "L") -- unmap or disable default behavior
    keys = function ()
        return {
            -- disable the default flash keymap
            { "s", mode = { "n", "x", "o" }, false },
            { "e", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
            { "E", mode = { "n", "o", "x" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
        }
    end,-- end,
    ---@type Flash.Config
    opts = {
        modes = {
            char = {
                keys = {
                    ["f"] = "y",
                    ["F"] = "Y",
                    ["t"] = "o",
                    ["T"] = "O",
                    [";"] = ".",
                    [","] = ",",
                },
            },
        },
    },
}
