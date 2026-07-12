--[[
    BuildingDefinition: House

    Edificio de habitacao para workers.
    Aumenta capacidade maxima de workers do reino.
    Nao produz recursos.
]]

local ResourceType = require(script.Parent.Parent.Enums.ResourceType)
local BuildingCategory = require(script.Parent.BuildingCategories)

return {
    schemaVersion = 1,
    id = "house",
    displayName = "House",
    category = BuildingCategory.Housing,
    tags = {
        early_game = true,
        housing = true,
    },

    footprint = { width = 2, depth = 2 },

    buildCost = {
        [ResourceType.Gold] = 50,
        [ResourceType.Wood] = 100,
    },
    buildTime = 20,

    unlockRequirements = { level = 2 },

    modelId = "house_1",
}
