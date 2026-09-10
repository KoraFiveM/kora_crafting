local function craftability(id)
    if type(id) ~= 'string' then return nil, 'invalid craftable id' end
    local ok, result = pcall(function()
        return Citizen.Await(QB.callback.trigger('qbcrafting:server:craftability', id))
    end)
    if not ok then return nil, tostring(result) end
    return result
end

---@param id string
---@return boolean, string|nil
local function canCraftItem(id)
    local result, err = craftability(id)
    if not result then return false, err end
    return result.canCraft == true, result.reason
end

---@param id string
---@return table|nil, table|string|nil
local function getCraftingRequirements(id)
    local result, err = craftability(id)
    if not result then return nil, err end
    return result.requirements, result.skills
end

exports('CanCraftItem', canCraftItem)
exports('GetCraftingRequirements', getCraftingRequirements)
