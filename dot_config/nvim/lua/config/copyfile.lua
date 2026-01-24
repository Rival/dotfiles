-- Module for copying files to clipboard on Wayland

local M = {}

-- Copy file as object to clipboard
-- @param bufnr number|nil Buffer number (0 or nil for current buffer)
-- @param filepath string|nil Optional filepath to copy (overrides buffer)
M.copy_file = function(bufnr, filepath)
    bufnr = bufnr or 0  -- 0 means current buffer
    local temp_file_created = false

    -- If filepath provided, use it directly
    if filepath and filepath ~= "" then
        filepath = vim.fn.expand(filepath)
    else
        -- Try to get the buffer's file
        filepath = vim.api.nvim_buf_get_name(bufnr)

        -- If buffer is not a file or doesn't exist, create a temporary file
        if filepath == "" or vim.fn.filereadable(filepath) == 0 then
            -- Get buffer info
            local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
            local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')

            -- Get buffer name for temp file naming
            local bufname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':t')
            if bufname == "" or bufname:match("^%w+://") then
                bufname = buftype ~= "" and buftype or "buffer"
            end

            -- Create temp file with appropriate extension
            local extension = filetype ~= "" and ("." .. filetype) or ".txt"
            filepath = vim.fn.tempname() .. "_" .. bufname:gsub("[^%w%-_.]", "_") .. extension

            -- Get buffer contents
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local content = table.concat(lines, "\n")

            -- Write to temp file
            local file = io.open(filepath, "w")
            if not file then
                vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
                return false
            end
            file:write(content)
            file:close()

            temp_file_created = true
            vim.notify(string.format("Created temporary file for %s buffer", bufname), vim.log.levels.INFO)
        end
    end

    -- Check if file exists
    if vim.fn.filereadable(filepath) == 0 then
        vim.notify(string.format("Error: '%s' does not exist", filepath), vim.log.levels.ERROR)
        return false
    end

    -- Create file URI
    local file_uri = "file://" .. filepath

    -- Copy to clipboard using wl-copy
    local cmd = string.format("echo '%s' | wl-copy --type text/uri-list", file_uri)
    local result = vim.fn.system(cmd)

    if vim.v.shell_error == 0 then
        local filename = vim.fn.fnamemodify(filepath, ":t")
        if temp_file_created then
            vim.notify(string.format("Copied %s as temporary file object", filename))
        else
            vim.notify(string.format("Copied %s as file object", filename))
        end
        return true
    else
        vim.notify("Failed to copy file to clipboard", vim.log.levels.ERROR)
        return false
    end
end

return M
