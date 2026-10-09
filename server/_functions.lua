-- Helpers every server script uses. Anything that comes from a player or from the creator goes
-- through the validators below first.

function decodeJson(raw, fallback)
    if type(raw) ~= 'string' or raw == '' then return fallback end
    local ok, decoded = pcall(json.decode, raw)
    return ok and type(decoded) == 'table' and decoded or fallback
end

-- A trimmed string of at most `max` characters, or nil when it is empty or not a string.
function trim(value, max)
    if type(value) ~= 'string' or not value:match('%S') then return nil end
    return value:match('^%s*(.-)%s*$'):sub(1, max)
end

-- A number inside [min, max] (rounded down when `whole`), or nil. Rejects NaN.
function inRange(value, min, max, whole)
    local n = tonumber(value)
    if not n or n ~= n or n < min or n > max then return nil end
    return whole and math.floor(n) or n
end

-- trim() plus a character check. nil = empty, false = it has characters the pattern does not allow.
function cleanName(value, max, pattern)
    local text = trim(value, max)
    if not text then return nil end
    return text:match(pattern) and text or false
end

-- { x, y, z } with every part a real number inside +-limit, or nil.
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

function isAdmin(src)
    src = tonumber(src)
    return src ~= nil and src > 0 and IsPlayerAceAllowed(src, 'command')
end

function isNear(src, coords, radius)
    if type(coords) ~= 'table' then return false end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not (x and y and z) then return false end
    return QB.distance.player(src, vec3(x, y, z), radius or Config.Distance)
end

-- ----------------------------------------------------------------------------
-- Who is the player: job and gang, for locked locations.
-- ----------------------------------------------------------------------------

local warnedPlayer = false

-- { job = 'police', gang = 'ballas' } for a player, or nil when it can not be read.
-- If your core is different, this is the one function to change.
function playerAccess(src)
    local ok, player = pcall(function() return exports.qbcore:getPlayer(src) end)
    local data = ok and type(player) == 'table' and (player.PlayerData or player.playerData or player.data or player) or nil
    if type(data) ~= 'table' or (data.job == nil and data.gang == nil) then
        if not warnedPlayer then
            warnedPlayer = true
            QB.print.warn('[qbcrafting] could not read a player\'s job and gang, so job/gang locked locations stay closed. Fix playerAccess() in server/_functions.lua.')
        end
        return nil
    end
    return {
        job = type(data.job) == 'table' and data.job.name or nil,
        gang = type(data.gang) == 'table' and data.gang.name or nil,
    }
end

-- A location with a gang and/or a job is open to a member of either one. No lock = open to everyone.
function locationAllowed(src, location)
    if not (location.gang or location.job) then return true end
    local access = playerAccess(src)
    if not access then return false end
    return (location.gang ~= nil and access.gang == location.gang)
        or (location.job ~= nil and access.job == location.job)
end

-- ----------------------------------------------------------------------------
-- Database rows
-- ----------------------------------------------------------------------------

local function exists(tableName, id)
    local rows = QB.sql.query(('SELECT `id` FROM `%s` WHERE `id` = ? LIMIT 1'):format(tableName), { id })
    return rows and rows[1] ~= nil
end

-- Inserts the row, or updates it when it already exists. Returns ok, err.
function dbSaveRecipe(id, data)
    if exists('qbcrafting_recipes', id) then
        return QB.sql.update('UPDATE `qbcrafting_recipes` SET `data` = ? WHERE `id` = ?', { json.encode(data), id })
    end
    return QB.sql.update('INSERT INTO `qbcrafting_recipes` (`id`, `data`) VALUES (?, ?)', { id, json.encode(data) })
end

function dbSaveStation(id, data, locations)
    if exists('qbcrafting_stations', id) then
        return QB.sql.update(
            'UPDATE `qbcrafting_stations` SET `data` = ?, `locations` = ? WHERE `id` = ?',
            { json.encode(data), json.encode(locations), id }
        )
    end
    return QB.sql.update(
        'INSERT INTO `qbcrafting_stations` (`id`, `data`, `locations`) VALUES (?, ?, ?)',
        { id, json.encode(data), json.encode(locations) }
    )
end

function dbDeleteRecipe(id)
    return QB.sql.update('DELETE FROM `qbcrafting_recipes` WHERE `id` = ?', { id })
end

function dbDeleteStation(id)
    return QB.sql.update('DELETE FROM `qbcrafting_stations` WHERE `id` = ?', { id })
end
