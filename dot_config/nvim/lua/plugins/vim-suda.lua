return {
    -- superuser commands
    "lambdalisue/vim-suda",
    -- opts = {
    --     suda_smart_edit = 1,
    -- },
  keys = {
-- vim.keymap.set('c', 'w!!', "<esc>:lua require'utils'.sudo_write()<CR>", { silent = true })
    { "<leader>qU", ":SudaWrite<cr>", desc = "Write file using sudo" }
  }
}
