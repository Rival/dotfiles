-- Mobile / QWERTY profile for Android Termux SSH.
--
-- Activated when REMOTE_PHONE=1 is in the environment, which the Termux
-- side injects via:
--     ssh -t cachy "REMOTE_PHONE=1 exec zj-main mobile"
--
-- Desktop nvim keymaps are already QWERTY-friendly (hjkl + <leader> chords),
-- so this module mainly sets a global flag for conditional tweaks and is the
-- single place to add mobile-specific bindings later.
local M = {}

function M.setup()
  if not vim.env.REMOTE_PHONE then
    return
  end

  vim.g.remote_phone = true

  -- Mobile-friendly keymap tweaks go here.
  -- Touch keyboards make held-modifier chords (Ctrl/Shift/Meta combos) hard,
  -- so prefer simple keys, <leader> sequences, and plain hjkl/arrows.
  --
  -- Example (uncomment to use):
  -- vim.keymap.set("n", "<leader>Q", ":qa!<CR>", { desc = "Force quit (mobile)" })
end

M.setup()
return M
