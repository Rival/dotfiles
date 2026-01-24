--- @since 25.2.26
---Get the selected files or hovered file
---@type fun(): table[]|nil Array of tables with {path: string, name: string} or nil if no file
local get_selected_files = ya.sync(function()
    local tab = cx.active
    local selected = {}

    for _, url in pairs(tab.selected) do
        table.insert(selected, {
            path = tostring(url),
            name = url.name  -- Gets just the filename
        })
    end

    if #selected == 0 then
        ya.dbg("No file selected")
        local hovered = tab.current.hovered
        if hovered then
            table.insert(selected, {
                path = tostring(hovered.url),
                name = hovered.name
            })
        end
    end

    return selected
end)

return {
    entry = function()
        ya.emit("escape", { visual = true })
        local files = get_selected_files()
        
        -- Check if any files are selected
        if #files == 0 then
            ya.notify {
                title = "Copy File",
                content = "No file selected",
                timeout = 3,
                level = "error",
            }
            return
        end
        
        -- ya.dbg("Hello")
        local success_count = 0
        local fail_count = 0

        -- Process each file
        local command = Command("/home/andrei/.scripts/copy-multiple.nu")
        for _, file in ipairs(files) do
            command:arg(file.path)
            success_count = success_count + 1
        end

        local output, err = command:output()

		ya.mgr_emit("yank", { visual = true })
        -- Show notification with results
        local message
        if not err then
            -- Success case
            if #files == 1 then
                -- Single file: show the filename
                -- local filename = files[1]:match("^.+/(.+)$") or files[1]
                message = string.format("Copied %s", files[1].name)
            else
                -- Multiple files: show count
                message = string.format("Copied %d file(s)", success_count)
            end

            ya.notify {
                title = "Copied to buffer",
                content = message,
                timeout = 3,
                level = "info",
            }
        elseif success_count == 0 then
            -- Total failure
            message = string.format("Failed to copy: %s", tostring(err))
            ya.notify {
                title = "Copy failed",
                content = message,
                timeout = 3,
                level = "error",
            }
        else
            -- Partial failure (shouldn't happen with your approach, but kept for completeness)
            message = string.format("Copied %d, failed %d: %s", success_count, fail_count, tostring(err))
            ya.notify {
                title = "Copy completed with errors",
                content = message,
                timeout = 3,
                level = "warn",
            }
        end 
    end,
}
