-- event-bus.lua
-- Use _G for persistence
if not _G.__eventbus then
  _G.__eventbus = {
    callbacks = {},
  }
end

local eventbus = {}

function eventbus.set_neotree_preload(fn)
  _G.__eventbus.callbacks.neotree_preload = fn
end

function eventbus.invoke_neotree_preload(...)
  return _G.__eventbus.callbacks.neotree_preload(...)
end

return eventbus
