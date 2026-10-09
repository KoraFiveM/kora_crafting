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

Limits = {
    recipeItems = 20,      -- different materials in one recipe
    recipeAmount = 1000,   -- amount of one material, or made
    materialResults = 24,  -- results shown when adding materials
    pickerResults = 36,    -- items shown in the "what it makes" grid
    stationLocations = 50,
    stationRecipes = 100,
    xp = 100000,
    level = 1000,
}
