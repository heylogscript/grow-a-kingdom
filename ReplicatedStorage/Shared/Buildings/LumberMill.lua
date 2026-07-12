--[[
    BuildingDefinition: LumberMill

    Edificio de producao de madeira.
    Desbloqueado no nivel 2.
    Requer worker designado.
]]

local ResourceType = require(script.Parent.Parent.Enums.ResourceType)
local BuildingCategory = require(script.Parent.BuildingCategories)

return {
    schemaVersion = 1,
    id = "lumbermill",
    displayName = "Lumber Mill",
    category = BuildingCategory.Resource,
    tags = {
        early_game = true,
        wood = true,
    },

    footprint = { width = 3, depth = 2 },

    buildCost = {
        [ResourceType.Gold] = 150,
        [ResourceType.Wood] = 50,
    },
    buildTime = 35,

    unlockRequirements = { level = 2 },

    modelId = "lumbermill_1",

    production = {
        outputs = { [ResourceType.Wood] = 12 },
        interval = 60,
        requiresWorker = true,
        startsPaused = false,
    },
}
