-- Better approach: Handle debouncing on the Neovim side

local M = {}

-- Cache for tab data and debouncing
local previous_data = nil
local pending_timer = nil
-- local last_update_time = 0

local last_real_buffer = nil

local kitty_pid = vim.env.KITTY_PID
local kitty_window_id = vim.env.KITTY_WINDOW_ID


-- trackint of last real buffer
function M.on_buffer_enter()
    local buf = vim.api.nvim_get_current_buf()
    if M.is_real_buffer(buf) then
        last_real_buffer = buf
    end
end

-- Configuration
local DEBOUNCE_DELAY = 500 -- 500ms in milliseconds

-- Check if running in Kitty
function M.is_kitty()
  return vim.env.KITTY_PID ~= nil
end

-- Function to get open buffers (only real files)
function M.get_open_buffers()
  local bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if M.is_real_buffer(buf) then
      table.insert(bufs, buf)
    end
  end
  return bufs
end

-- Check if a buffer is a "real" buffer
function M.is_real_buffer(buf)
  if not vim.api.nvim_buf_is_loaded(buf) or not vim.bo[buf].buflisted then
    return false
  end

  local ft = vim.bo[buf].filetype
  local bt = vim.bo[buf].buftype
  local name = vim.api.nvim_buf_get_name(buf)

  if ft == "neo-tree" or bt ~= "" or name:match("neo%-tree") then
    return false
  end

  return true
end

-- Actually send the update to Kitty (no debouncing here)
function M.send_to_kitty()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  local bufs = M.get_open_buffers()
  local tabs = {}
  local current_idx = nil
  -- local current_buf = vim.api.nvim_get_current_buf()
  for i, buf in ipairs(bufs) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then
      name = "[No Name]"
    else
      name = vim.fn.fnamemodify(name, ":t")
    end

    table.insert(tabs, {
      name = name,
      modified = vim.bo[buf].modified,
    })

    if buf == last_real_buffer then
      current_idx = i
    end
  end

  local data = {
    cwd = cwd,
    tabs = tabs,
    current_idx = current_idx or 0,
  }

  local json_data = vim.fn.json_encode(data)
  -- Only send if data has changed (reduce system calls)
  if json_data ~= previous_data then
    previous_data = json_data
    -- Write to a file both processes can access
    local kitty_pid = vim.env.KITTY_PID or "unknown"
    local window_id = vim.env.KITTY_WINDOW_ID or "default"
    local tmp_file = "/tmp/kitty_nvim_" .. kitty_pid .. "_" .. window_id .. ".json"
    -- print("kitty_nvim_path" .. tmp_file)
    local file = io.open(tmp_file, "w")
    file:write(json_data)
    file:close()
    -- -- Also update the tab title with a prefix to identify Neovim tabs
    -- local title = "nvim:" .. cwd
    -- vim.fn.system({ "kitty", "@", "set-tab-title", json_data})

    -- Send to kitty as JSON
    -- vim.fn.system({ "kitty", "@", "kitten", "nvim_tabs_kitten.py"})
    -- vim.fn.system({ "kitty", "@", "set-user-vars", "env:KITTY_MY_VAR=WAKA"})
    vim.fn.system({ "kitty", "@", "kitten", "nvim_tabs_kitten.py", json_data })
  end
end

-- Debounced update function
function M.update_kitty_tabs()
  -- local current_time = vim.fn.reltimestr(vim.fn.reltime())
  -- current_time = tonumber(current_time) * 1000  -- Convert to milliseconds

  -- Cancel existing timer if it exists
  if pending_timer then
    vim.fn.timer_stop(pending_timer)
    pending_timer = nil
  end

  -- Check if we should update immediately (for important events)
  -- if current_time - last_update_time > DEBOUNCE_DELAY then
  --     -- It's been a while, update immediately
  --     M.send_to_kitty()
  --     last_update_time = current_time
  -- else
  -- Recent activity, delay the update
  pending_timer = vim.fn.timer_start(DEBOUNCE_DELAY, function()
    M.send_to_kitty()
    -- last_update_time = vim.fn.reltimestr(vim.fn.reltime()) * 1000
    pending_timer = nil
  end)
  -- end
end

-- Immediate update for critical events
function M.update_kitty_tabs_immediate()
  -- Cancel any pending timer
  if pending_timer then
    vim.fn.timer_stop(pending_timer)
    pending_timer = nil
  end

  -- Update immediately
  M.send_to_kitty()
  last_update_time = vim.fn.reltimestr(vim.fn.reltime()) * 1000
end

-- Setup autocommands
function M.setup()
    if kitty_pid == nil or kitty_window_id == nil then
        return
    end

    local augroup = vim.api.nvim_create_augroup("KittyIntegration", { clear = true })

    -- -- Set up the autocmd
    -- vim.api.nvim_create_autocmd("BufEnter", {
    --     callback = M.on_buffer_enter
    -- })
    -- Immediate updates for buffer navigation
    vim.api.nvim_create_autocmd({
        "BufEnter",
        -- "BufLeave"
    }, {
            group = augroup,
            callback = function()
                M.on_buffer_enter()
                M.update_kitty_tabs()
            end,
        })

  -- -- Debounced updates for other events
  -- vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "DirChanged" }, {
  --   group = augroup,
  --   callback = function()
  --     M.update_kitty_tabs()
  --   end,
  -- })

  -- Highly debounced updates for text changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    callback = function()
      M.update_kitty_tabs()
    end,
  })

  -- Initialize
  M.update_kitty_tabs()

  -- vim.notify("Kitty integration initialized (Neovim-side debouncing)", vim.log.levels.INFO)
end

-- Auto-setup when loaded
M.setup()

return M
