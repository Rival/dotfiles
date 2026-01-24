return {
  -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "confetti",
    },
  },
  {
    -- "rival/confetti",
    name = "confetti",
    dir = vim.fn.stdpath("config") .. "/themes/confetti.nvim", -- Dynamically resolve the path
    -- config = function()
    --   require("confetti").setup()
    -- end,
    dev = true,
  },
}
