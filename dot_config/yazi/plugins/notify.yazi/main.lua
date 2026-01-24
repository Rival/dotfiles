return {
    entry = function(self, job)
        -- Parse the arguments
        local title = job.args.title or "Default Title"
        local content = job.args.content or "Default Content"
        local level = job.args.level or "info"

        local content = "{"
        for k, v in pairs(job.args) do
            content = content .. "\n  [" .. tostring(k) .. "] = " .. tostring(v)
        end
        content = content .. "\n}"

        ya.notify {
            title = title,
            content = content,
            timeout = 6.5,
            level = level,
        }
    end,
}
