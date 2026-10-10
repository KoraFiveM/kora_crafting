ProgressDisableOptions = {
    { value = 'move', label = 'Movement' },
    { value = 'combat', label = 'Combat' },
    { value = 'car', label = 'Vehicle (car)' },
    { value = 'vehicle', label = 'Vehicle (vehicle)' },
}

-- What a brand new recipe starts with.
DefaultAnim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 }
DefaultProgress = {
    time = 5000,
    label = 'Crafting...',
    disable = { move = true, combat = true, car = true },
}

-- Milliseconds a player must wait between calls of the same kind.
Cooldowns = {
    menu = 1000,
    begin = 1000,
}

-- Crafting log rows older than this many days are deleted.
LogKeepDays = 30

Limits = {
    recipeItems = 20,      -- different materials in one recipe
    recipeAmount = 1000,   -- amount of one material, or made
    materialResults = 24,  -- results shown when adding materials
    stationLocations = 50,
    stationRecipes = 100,
    xp = 100000,
    level = 1000,
}
