vim.opt.guifont = "JetBrainsMono Nerd Font Mono:h13"
-- vim.opt.linespace = -5
vim.g.neovide_confirm_quit = false
vim.g.neovide_background_image = "/home/andrei/Documents/dark-denim-tile-6.png"
-- Helper function for transparency formatting
local alpha = function()
  return string.format("%x", math.floor(255 * vim.g.transparency or 0.8))
end
-- g:neovide_opacity should be 0 if you want to unify transparency of content and title bar.
vim.g.neovide_opacity = 0.95
vim.g.transparency = 0.8
vim.g.neovide_background_color = "#0f1117" .. alpha()

vim.g.neovide_floating_blur_amount_x = 2.0
vim.g.neovide_floating_blur_amount_y = 2.0
vim.g.neovide_position_animation_length = 0.15
vim.g.neovide_scroll_animation_length = 0.3

vim.g.neovide_cursor_animation_length = 0.06
vim.g.neovide_cursor_trail_size = 0.6
vim.g.neovide_cursor_vfx_mode = "railgun"

--colors for neovide
vim.api.nvim_set_hl(0, "Cursor", { bg = "orange" })
vim.g.neovide_cursor_vfx_mode = "pixiedust" --railgun", "ripple", "sonicboom"
vim.g.neovide_cursor_vfx_opacity = 200.0
vim.g.neovide_cursor_vfx_particle_lifetime = 1.5
vim.g.neovide_cursor_vfx_particle_density = 77.0
vim.g.neovide_cursor_vfx_particle_speed = 10.0
--only in railgun
--Sets the mass movement of particles, or how individual each one acts. The
--higher the value, the less particles rotate in accordance to each other, the
--lower, the more line-wise all particles become.
vim.g.neovide_cursor_vfx_particle_phase = 3.5
--Sets the velocity rotation speed of particles. The higher, the less particles
--actually move and look more "nervous", the lower, the more it looks like a
--collapsing sine wave.
vim.g.neovide_cursor_vfx_particle_curl = 10.0
-- Enable Neovide multigrid support
vim.g.neovide_multigrid = true
vim.cmd([[
  augroup NeovideCursorColors
    autocmd!
    autocmd InsertEnter * highlight Cursor guibg=#66FF99
    autocmd InsertLeave * highlight Cursor guibg=orange
  augroup END
]])

--When scrolling more than one screen at a time, only this many lines at the
--end of the scroll action will be animated. Set it to 0 to snap to the final
--position without any animation, or to something big like 9999 to always
--scroll the whole screen
vim.g.neovide_scroll_animation_far_lines = 5
vim.g.neovide_hide_mouse_when_typing = true

vim.g.neovide_theme = "dark"
vim.g.neovide_profiler = false

-- local function set_ime(args)
--   if args.event:match("Enter$") then
--     vim.g.neovide_input_ime = true
--   else
--     vim.g.neovide_input_ime = false
--   end
-- end

-- This lets you disable the IME input. For example, to only enables IME in
-- input mode and when searching, so that you can navigate normally
-- local ime_input = vim.api.nvim_create_augroup("ime_input", { clear = true })

-- vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
--   group = ime_input,
--   pattern = "*",
--   callback = set_ime,
-- })
--
-- vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineLeave" }, {
--   group = ime_input,
--   pattern = "[/\\?]",
--   callback = set_ime,
-- })
-- fixes for scrolling when changing buffers  https://github.com/neovide/neovide/issues/1771

vim.api.nvim_create_autocmd("BufLeave", {
  callback = function()
    vim.g.neovide_scroll_animation_length = 0
    vim.g.neovide_cursor_animation_length = 0
  end,
})
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.fn.timer_start(70, function()
      vim.g.neovide_scroll_animation_length = 0.3
      vim.g.neovide_cursor_animation_length = 0.08
    end)
  end,
})

vim.g.neovide_scale_factor = 1.0
local change_scale_factor = function(delta)
  vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
end
vim.keymap.set("n", "<C-=>", function()
  change_scale_factor(1.25)
end)
vim.keymap.set("n", "<C-->", function()
  change_scale_factor(1 / 1.25)
end)

-- Helper function for transparency formatting
local alpha = function()
  return string.format("%x", math.floor(255 * vim.g.neovide_transparency_point or 0.8))
end
-- Set transparency and background color (title bar color)
vim.g.neovide_opacity = 1
vim.g.neovide_transparency_point = 0.8
vim.g.neovide_background_color = "#0f1117" .. alpha()
-- -- Add keybinds to change transparency
-- local change_transparency = function(delta)
--   vim.g.neovide_transparency_point = vim.g.neovide_transparency_point + delta
--   vim.g.neovide_background_color = "#0f1117" .. alpha()
-- end
-- vim.keymap.set({ "n", "v", "o" }, "<C-]>", function()
--   change_transparency(0.01)
-- end)
-- vim.keymap.set({ "n", "v", "o" }, "<C-[>", function()
--   change_transparency(-0.01)
-- end)
-- vim.g.neovide_title_background_color = string.format(
--     "%x",
--     vim.api.nvim_get_hl(0, {id=vim.api.nvim_get_hl_id_by_name("Normal")}).bg
-- )
--
-- vim.g.neovide_title_text_color = "pink"
-- vim.g.neovide_text_gamma = 0.0
-- vim.g.neovide_text_contrast = 0.5
