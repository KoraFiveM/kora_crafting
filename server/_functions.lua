
function decodeJson(raw, fallback)
    if type(raw) ~= 'string' or raw == '' then return fallback end
    local ok, decoded = pcall(json.decode, raw)
    return ok and type(decoded) == 'table' and decoded or fallback
end

function trim(value, max)
    if type(value) ~= 'string' or not value:match('%S') then return nil end
    return value:match('^%s*(.-)%s*$'):sub(1, max)
end

function inRange(value, min, max, whole)
    local n = tonumber(value)
    if not n or n ~= n or n < min or n > max then return nil end
    return whole and math.floor(n) or n
end

function cleanName(value, max, pattern)
    local text = trim(value, max)
    if not text then return nil end
    return text:match(pattern) and text or false
end

function cleanVec(value, limit)
    if type(value) ~= 'table' then return nil end
    limit = limit or 10000.0
    local x, y, z = inRange(value.x, -limit, limit), inRange(value.y, -limit, limit), inRange(value.z, -limit, limit)
    if x and y and z then return { x = x, y = y, z = z } end
end

function copyTable(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = copyTable(inner) end
    return copy
end

-- Cuts text to at most max characters (not bytes), so a multibyte name is never cut in half.
function cutText(text, max)
    text = tostring(text)
    if not utf8.len(text) then text = (text:gsub('[\128-\255]', '?')) end
    local stop = utf8.offset(text, max + 1)
    return stop and text:sub(1, stop - 1) or text
end

-- One timer per key and player, so a player cannot repeat a call faster than its cooldown.
local timers = {}

function onCooldown(src, key)
    return timers[key] ~= nil and timers[key][src] == true
end

function startCooldown(src, key, duration)
    timers[key] = timers[key] or {}
    timers[key][src] = true
    SetTimeout(duration, function() timers[key][src] = nil end)
end

AddEventHandler('playerDropped', function()
    local src = source
    for _, byPlayer in pairs(timers) do byPlayer[src] = nil end
end)

function isAdmin(src)
    src = tonumber(src)
    return src ~= nil and src > 0 and IsPlayerAceAllowed(src, 'command')
end

function isNear(src, coords, radius)
    if type(coords) ~= 'table' then return false end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not (x and y and z) then return false end
    return Kora.distance.player(src, vec3(x, y, z), radius or Config.Distance)
end


local logLimits = { name = 64, identifier = 64, action = 64, details = 16000 }

local function license(src)
    local ok, identifier = pcall(GetPlayerIdentifierByType, src, 'license')
    return ok and identifier or 'unknown'
end

function logAction(src, action, details)
    pcall(function()
        src = tonumber(src) or 0
        Kora.sql.update(
            'INSERT INTO `qbcrafting_logs` (`source`, `name`, `identifier`, `action`, `details`) VALUES (?, ?, ?, ?, ?)',
            {
                src,
                cutText(GetPlayerName(src) or 'unknown', logLimits.name),
                cutText(license(src), logLimits.identifier),
                cutText(action, logLimits.action),
                cutText(json.encode(details or {}), logLimits.details),
            }
        )
    end)
end

local warnedPlayer = false

function playerAccess(src)
    local ok, player = pcall(function() return exports.kora_core:getPlayer(src) end)
    local data = ok and type(player) == 'table' and (player.PlayerData or player.playerData or player.data or player) or nil
    if type(data) ~= 'table' or (data.job == nil and data.gang == nil) then
        if not warnedPlayer then
            warnedPlayer = true
            Kora.print.warn('[qbcrafting] could not read a player\'s job and gang, so job/gang locked locations stay closed. Fix playerAccess() in server/_functions.lua.')
        end
        return nil
    end
    return {
        job = type(data.job) == 'table' and data.job.name or nil,
        gang = type(data.gang) == 'table' and data.gang.name or nil,
    }
end

function locationAllowed(src, location)
    if not (location.gang or location.job) then return true end
    local access = playerAccess(src)
    if not access then return false end
    return (location.gang ~= nil and access.gang == location.gang)
        or (location.job ~= nil and access.job == location.job)
end

local function exists(tableName, id)
    local rows = Kora.sql.query(('SELECT `id` FROM `%s` WHERE `id` = ? LIMIT 1'):format(tableName), { id })
    return rows and rows[1] ~= nil
end

function dbSaveRecipe(id, data)
    if exists('qbcrafting_recipes', id) then
        return Kora.sql.update('UPDATE `qbcrafting_recipes` SET `data` = ? WHERE `id` = ?', { json.encode(data), id })
    end
    return Kora.sql.update('INSERT INTO `qbcrafting_recipes` (`id`, `data`) VALUES (?, ?)', { id, json.encode(data) })
end

function dbSaveStation(id, data, locations)
    if exists('qbcrafting_stations', id) then
        return Kora.sql.update(
            'UPDATE `qbcrafting_stations` SET `data` = ?, `locations` = ? WHERE `id` = ?',
            { json.encode(data), json.encode(locations), id }
        )
    end
    return Kora.sql.update(
        'INSERT INTO `qbcrafting_stations` (`id`, `data`, `locations`) VALUES (?, ?, ?)',
        { id, json.encode(data), json.encode(locations) }
    )
end

function dbDeleteRecipe(id)
    return Kora.sql.update('DELETE FROM `qbcrafting_recipes` WHERE `id` = ?', { id })
end

function dbDeleteStation(id)
    return Kora.sql.update('DELETE FROM `qbcrafting_stations` WHERE `id` = ?', { id })
end
