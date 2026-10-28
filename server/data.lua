-- The recipes and stations, kept in memory and saved to the database.
--   Recipes  [id] = recipe     the server only: players never receive these
--   Stations [id] = { id, data, locations }
-- Clients are sent just what they need to build the targets: each station's name, target text and locations.

Recipes = {}
Stations = {}
DataLoaded = false

local function publicEntry(station)
    return {
        id = station.id,
        label = station.data.label,
        targetLabel = station.data.targetLabel,
        targetIcon = station.data.targetIcon,
        locations = station.locations,
    }
end

local function publish(id)
    local stations = {}
    for stationId, station in pairs(Stations) do stations[stationId] = publicEntry(station) end
    GlobalState.Crafting = { stations = stations } -- keeps players who join later up to date
    if id then
        TriggerClientEvent('qbcrafting:client:stationReload', -1, id, Stations[id] and publicEntry(Stations[id]) or nil)
    end
end

-- Each of these saves, updates the memory copy and tells the clients. They return ok, err.

function SaveRecipe(id, recipe)
    local ok, err = dbSaveRecipe(id, recipe)
    if not ok then return false, err end
    Recipes[id] = recipe
    return true
end

function SaveStation(id, data, locations)
    local ok, err = dbSaveStation(id, data, locations)
    if not ok then return false, err end
    Stations[id] = { id = id, data = data, locations = locations }
    publish(id)
    return true
end

function DeleteStation(id)
    local ok, err = dbDeleteStation(id)
    if not ok then return false, err end
    Stations[id] = nil
    publish(id)
    return true
end

-- Deleting a recipe also takes it off every station that had it.
function DeleteRecipe(id)
    local ok, err = dbDeleteRecipe(id)
    if not ok then return false, err end
    Recipes[id] = nil

    for stationId, station in pairs(Stations) do
        local kept, changed = {}, false
        for _, recipeId in ipairs(station.data.recipes) do
            if recipeId == id then changed = true else kept[#kept + 1] = recipeId end
        end
        if changed then
            local data = copyTable(station.data)
            data.recipes = kept
            SaveStation(stationId, data, station.locations)
        end
    end
    return true
end

CreateThread(function()
    Wait(1000)
    while GetResourceState('kora_sql') ~= 'started' do Wait(500) end

    pcall(QB.sql.update, 'CREATE TABLE IF NOT EXISTS `qbcrafting_recipes` (`id` varchar(48) NOT NULL, `data` longtext NOT NULL, PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4')
    pcall(QB.sql.update, 'CREATE TABLE IF NOT EXISTS `qbcrafting_stations` (`id` varchar(48) NOT NULL, `data` longtext NOT NULL, `locations` longtext NOT NULL, PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4')
    pcall(QB.sql.update, [[CREATE TABLE IF NOT EXISTS `qbcrafting_logs` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          `source` int(11) NOT NULL,
          `name` varchar(64) NOT NULL,
          `identifier` varchar(64) NOT NULL,
          `action` varchar(64) NOT NULL,
          `details` text NOT NULL,
          PRIMARY KEY (`id`),
          KEY `created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
    local recipesOk, recipeRows = pcall(QB.sql.query, 'SELECT * FROM `qbcrafting_recipes`')
    local stationsOk, stationRows = pcall(QB.sql.query, 'SELECT * FROM `qbcrafting_stations`')
    local logsOk, logRows = pcall(QB.sql.query, 'SELECT * FROM `qbcrafting_logs`')
    if not (recipesOk and stationsOk and logsOk) then
        QB.print.warn(('[qbcrafting] could not read the database: %s'):format(tostring(recipesOk and stationsOk and logsOk and logRows or recipeRows)))
        return
    end
    pcall(QB.sql.update, 'DELETE FROM `qbcrafting_logs` WHERE `created_at` < (NOW() - INTERVAL ? DAY)', { LogKeepDays })
    for _, row in ipairs(recipeRows or {}) do
        if validId(row.id) then Recipes[row.id] = readRecipe(row.id, row.data) end
    end
    for _, row in ipairs(stationRows or {}) do
        if validId(row.id) then
            local data, locations = readStation(row.id, row)
            Stations[row.id] = { id = row.id, data = data, locations = locations }
        end
    end

    DataLoaded = true
    publish()
end)
