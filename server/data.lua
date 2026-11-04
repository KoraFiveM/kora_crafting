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
    if not Kora.sql.ready(60000) then
        Kora.print.warn('[qbcrafting] kora_sql was unavailable; crafting data is not loaded until restart.')
        return
    end
    local reports, schemaErr = Kora.sql.ensureTables(QBCraftingSchema)
    if schemaErr then
        Kora.print.warn(('[qbcrafting] schema failed: %s'):format(tostring(schemaErr)))
        return
    end
    for _, report in ipairs(reports or {}) do
        for _, warning in ipairs(report.warnings or {}) do
            Kora.print.warn(('[qbcrafting] %s: %s'):format(tostring(report.table), tostring(warning)))
        end
    end
    local recipesOk, recipeRows = pcall(Kora.sql.query, 'SELECT * FROM `kora_crafting_recipes`')
    local stationsOk, stationRows = pcall(Kora.sql.query, 'SELECT * FROM `kora_crafting_stations`')
    local logsOk, logRows = pcall(Kora.sql.query, 'SELECT * FROM `kora_crafting_logs`')
    if not (recipesOk and stationsOk and logsOk) then
        Kora.print.warn(('[qbcrafting] could not read the database: %s'):format(tostring(recipesOk and stationsOk and logsOk and logRows or recipeRows)))
        return
    end
    pcall(Kora.sql.update, 'DELETE FROM `kora_crafting_logs` WHERE `created_at` < (NOW() - INTERVAL ? DAY)', { LogKeepDays })
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
