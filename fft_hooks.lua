-- Optional FFT development hooks (client). Listed last in fxmanifest.lua and
-- inert unless `setr fft_kora_hooks true`. No other file references FFT.
--
-- kora_crafting has no exports and ships no stations: they exist only once an
-- admin builds them in /craftCreator, and a location is placed with a world
-- raycast. This hook builds and removes a throwaway station through the same
-- admin callbacks the creator app sends (server/creator.lua), so the server's
-- "command" ace check, validation and audit log all stay in force. It never
-- touches a recipe or station whose id does not start with `fft_`, and it does
-- not open a station or craft anything: that is done through kora_target and
-- the crafting app.
if GetConvar('fft_kora_hooks', 'false') ~= 'true' then return end

local RUNNER = 'fft'
local VERSION = 1
local PREFIX = 'fft_'            -- makeId() of any label starting with "FFT "
local TARGET_LABEL = 'FFT test craft'
local MAX_LEVEL = 1000           -- Limits.level (shared/constants.lua)

local function session()
    if GetResourceState(RUNNER) ~= 'started' then return nil end
    local id = LocalPlayer.state.fftSession
    return type(id) == 'string' and id or nil
end

local function owned(id)
    return type(id) == 'string' and id:sub(1, #PREFIX) == PREFIX
end

local function call(name, ...)
    local result, err = Kora.callback.trigger(name, ...)
    if not result then return nil, tostring(err or ('No answer from ' .. name)) end
    return result
end

local function itemName(value)
    return type(value) == 'string' and #value <= 64 and value:match('^[%w_%-%.]+$') ~= nil
end

local function find(list, id)
    for _, entry in ipairs(list or {}) do
        if entry.id == id then return entry end
    end
end

local actions = {}

-- Client-side view: whether a station menu or craft is running, and which test
-- stations this client has built targets for.
function actions.state()
    local stations = {}
    for id, entry in pairs(Stations) do
        if owned(id) and type(entry) == 'table' then
            stations[#stations + 1] = { id = id, targetLabel = entry.targetLabel,
                locations = type(entry.locations) == 'table' and #entry.locations or 0 }
        end
    end
    return { crafting = Crafting == true, stations = stations }
end

-- Server-side view of the test recipes and stations (admin only, read only).
function actions.registry()
    local data, err = call('kora_crafting:creator:get')
    if not data then return false, err, 'rejected' end
    local recipes, stations = {}, {}
    for _, recipe in ipairs(data.recipes or {}) do
        if owned(recipe.id) then recipes[#recipes + 1] = recipe.id end
    end
    for _, station in ipairs(data.stations or {}) do
        if owned(station.id) then stations[#stations + 1] = station.id end
    end
    return { recipes = recipes, stations = stations, skills = #(data.skills or {}) }
end

-- Deletes every test station and recipe. Stations first, so no station is
-- re-saved when its recipe goes.
function actions.purge()
    local data, err = call('kora_crafting:creator:get')
    if not data then return false, err, 'rejected' end
    local removed = 0
    for _, station in ipairs(data.stations or {}) do
        if owned(station.id) then
            local ok, why = call('kora_crafting:creator:stations:delete', station.id)
            if not ok then return false, why, 'rejected' end
            removed = removed + 1
        end
    end
    for _, recipe in ipairs(data.recipes or {}) do
        if owned(recipe.id) then
            local ok, why = call('kora_crafting:creator:recipes:delete', recipe.id)
            if not ok then return false, why, 'rejected' end
            removed = removed + 1
        end
    end
    return true, removed
end

---Builds one recipe on one station placed just in front of the tester.
---@param spec { makes: string, amount?: integer, give?: { item: string, amount: integer, keep?: boolean }[], job?: string, skillLocked?: boolean }
function actions.fixture(spec)
    if type(spec) ~= 'table' or not itemName(spec.makes) then return false, 'Fixture needs an item to make', 'invalid' end
    local amount = math.tointeger(spec.amount or 1)
    if not amount or amount < 1 or amount > 10 then return false, 'Fixture amount must be 1-10', 'invalid' end
    if spec.job ~= nil and not (type(spec.job) == 'string' and #spec.job <= 32 and spec.job:match('^[%w_%-]+$')) then
        return false, 'Invalid job', 'invalid'
    end
    local give = {}
    for _, entry in ipairs(type(spec.give) == 'table' and spec.give or {}) do
        local count = type(entry) == 'table' and math.tointeger(entry.amount)
        if #give >= 5 or not count or count < 1 or count > 50 or not itemName(entry.item) then
            return false, 'Invalid fixture material', 'invalid'
        end
        give[#give + 1] = { item = entry.item, amount = count, keep = entry.keep == true }
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return false, 'Leave the vehicle first', 'blocked' end

    local purged, purgeErr = actions.purge()
    if not purged then return false, purgeErr, 'rejected' end

    local created, err = call('kora_crafting:creator:recipes:create', 'FFT recipe')
    if not created then return false, err, 'rejected' end
    local recipeId = created.id
    if not owned(recipeId) then return false, 'Unexpected recipe id', 'rejected' end

    local data
    data, err = call('kora_crafting:creator:recipes:item', recipeId, spec.makes)
    if not data then return false, err, 'rejected' end
    if #give > 0 then
        data, err = call('kora_crafting:creator:recipes:give', recipeId, give)
        if not data then return false, err, 'rejected' end
    end

    local skill
    if spec.skillLocked == true then
        skill = data.skills and data.skills[1] and data.skills[1].value
        if type(skill) ~= 'string' then return false, 'No skills are registered', 'blocked' end
    end
    if amount ~= 1 or skill then
        local recipe = find(data.recipes, recipeId)
        if not recipe then return false, 'Recipe vanished', 'rejected' end
        -- The creator's "details" form always sends the whole record.
        data, err = call('kora_crafting:creator:recipes:details', recipeId, {
            label = recipe.label, tag = recipe.tag, amount = amount,
            progress = recipe.progress, anim = recipe.anim,
            skill = skill, level = skill and MAX_LEVEL or nil,
        })
        if not data then return false, err, 'rejected' end
    end

    created, err = call('kora_crafting:creator:stations:create', 'FFT station')
    if not created then return false, err, 'rejected' end
    local stationId = created.id
    if not owned(stationId) then return false, 'Unexpected station id', 'rejected' end

    data, err = call('kora_crafting:creator:stations:details', stationId, { label = 'FFT station', targetLabel = TARGET_LABEL })
    if not data then return false, err, 'rejected' end
    data, err = call('kora_crafting:creator:stations:recipes', stationId, { recipeId })
    if not data then return false, err, 'rejected' end

    -- A 2 m target box (client/_functions.lua createBox) whose floor is under the
    -- ground 1.6 m ahead, so a ray aimed at that ground point lands inside it.
    local at, forward = GetEntityCoords(ped), GetEntityForwardVector(ped)
    local centre = { x = at.x + forward.x * 1.6, y = at.y + forward.y * 1.6, z = at.z - 0.5 }
    data, err = call('kora_crafting:creator:stations:locations', stationId, { { coords = centre, job = spec.job } })
    if not data then return false, err, 'rejected' end

    local deadline = GetGameTimer() + 3000
    while GetGameTimer() < deadline do
        local entry = Stations[stationId]
        if type(entry) == 'table' and type(entry.locations) == 'table' and #entry.locations == 1 then break end
        Wait(50)
    end
    if not (type(Stations[stationId]) == 'table' and #(Stations[stationId].locations or {}) == 1) then
        return false, 'The station was not published to this client', 'rejected'
    end

    return {
        recipe = recipeId, station = stationId, targetLabel = TARGET_LABEL,
        aim = { x = centre.x, y = centre.y, z = at.z - 0.95 },
    }
end

exports('fftVersion', function() return VERSION end)
exports('fftAction', function(action, ...)
    if GetInvokingResource() ~= RUNNER or not session() then
        return false, 'FFT hooks are disabled or session is not authorised'
    end
    local handler = actions[action]
    if not handler then return false, 'Unsupported FFT action: ' .. tostring(action) end
    return handler(...)
end)
