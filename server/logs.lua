local function rowLimit(value)
    local n = tonumber(value)
    if not n or n ~= n then return 20 end
    return math.max(1, math.min(200, math.floor(n)))
end

local function formatRow(row)
    return ('[%s] #%s %s (%s) %s %s'):format(
        tostring(row.created_at), tostring(row.id), tostring(row.name),
        tostring(row.identifier), tostring(row.action), tostring(row.details)
    )
end

RegisterCommand('craftLogs', function(source, args)
    if source ~= 0 then Kora.print.debug('[kora_crafting] This command can only be run from the server console.') return end

    local ok, rows = pcall(Kora.sql.query,
        'SELECT `id`, CAST(`created_at` AS CHAR) AS `created_at`, `name`, `identifier`, `action`, `details` FROM `kora_crafting_logs` ORDER BY `id` DESC LIMIT ?',
        { rowLimit(args[1]) }
    )
    if not ok then
        Kora.print.debug('[kora_crafting] could not read the logs: ' .. tostring(rows))
        return
    end
    if not rows or #rows == 0 then
        Kora.print.debug('[kora_crafting] no logs yet.')
        return
    end

    for _, row in ipairs(rows) do Kora.print.debug(formatRow(row)) end
end, true)
