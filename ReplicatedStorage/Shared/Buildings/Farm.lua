--[[
    BuildingDefinition: Farm

    Edificio basico de producao de comida.
    Primeiro edificio que o jogador pode construir.
    Requer apenas nivel 1.
]]

local ResourceType = require(script.Parent.Parent.Enums.ResourceType)
local BuildingCategory = require(script.Parent.BuildingCategories)

return {
    schemaVersion = 1,
    id = "farm",
    displayName = "Farm",
    category = BuildingCategory.Resource,
    tags = {
        early_game = true,
        food = true,
    },

    footprint = { width = 3, depth = 3 },

    buildCost = {
        [ResourceType.Gold] = 100,
        [ResourceType.Wood] = 50,
    },
    buildTime = 30,

    unlockRequirements = { level = 1 },

    modelId = "farm_1",

    production = {
        outputs = { [ResourceType.Food] = 10 },
        interval = 60,
        requiresWorker = true,
        startsPaused = false,
    },
}
