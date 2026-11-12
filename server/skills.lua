
local cfg = Config.Skills
local warned = {}

local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    Kora.print.warn('[kora_crafting] ' .. message)
end

local function callSkills(name, ...)
    if type(name) ~= 'string' then return false end
    local args = { ... }
    local ok, result, extra = pcall(function()
        local resource = exports[cfg.resource]
        return resource[name](resource, table.unpack(args))
    end)
    if not ok then
        warnOnce(name, ('the %s export "%s" failed: %s'):format(cfg.resource, name, tostring(result)))
        return false
    end
    return true, result, extra
end

function GetSkills()
    local ok, data = callSkills(cfg.getData)
    if ok and type(data) == 'table' then return data end
    return nil
end

function GetSkillList()
    local list = {}
    for name, label in pairs(GetSkills() or {}) do
        if type(name) == 'string' then
            list[#list + 1] = { value = name, label = tostring(label) }
        end
    end
    table.sort(list, function(a, b)
        local la, lb = a.label:lower(), b.label:lower()
        if la ~= lb then return la < lb end
        return a.value < b.value
    end)
    return list
end

function HasSkillLevel(src, skill, level)
    local ok, result = callSkills(cfg.isLevel, src, skill, level)
    if not ok then return nil end
    return result == true
end

function SkillLevel(src, skill)
    local ok, data = callSkills(cfg.getRep, src, skill)
    if not ok or type(data) ~= 'table' then return nil end
    return tonumber(data.level)
end

function GiveSkillXp(src, skill, xp)
    local ok, result, reason = callSkills(cfg.addRep, src, skill, xp)
    if ok and result == true then return true end
    if ok then warnOnce('addRep', ('%s refused %d xp in "%s": %s'):format(cfg.resource, xp, tostring(skill), tostring(reason))) end
    return false
end
