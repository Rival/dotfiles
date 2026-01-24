return {
  {
    "snacks.nvim",
    opts = {
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = false }, -- we set this in options.lua
      toggle = { map = LazyVim.safe_keymap_set },
      words = { enabled = true },
    },
    -- stylua: ignore
    -- keys = {
    --   { "<leader>n", function()
    --     Snacks.notifier.show_history()
    --     -- Wait for the buffer to be created and then set wrap
    --     vim.schedule(function()
    --       -- Check if the buffer is the correct type, then set wrap
    --       for _, win in ipairs(vim.api.nvim_list_wins()) do
    --         local bufId = vim.api.nvim_win_get_buf(win)
    --         if vim.api.nvim_get_option_value("filetype", {buf = bufId}) == "snacks_notif_history" then
    --           vim.api.nvim_set_option_value("wrap", true,{win = win})
    --         end
    --       end
    --     end)
    --   end, desc = "Notification History" },
    --   { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
    -- },
  },
}
