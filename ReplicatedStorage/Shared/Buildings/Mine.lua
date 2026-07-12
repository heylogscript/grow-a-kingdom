--[[
    BuildingDefinition: Mine

    Edificio de producao de pedra.
    Desbloqueado no nivel 3.
    Requer um worker designado para operar.
]]

local ResourceType = require(script.Parent.Parent.Enums.ResourceType)
local BuildingCategory = require(script.Parent.BuildingCategories)

return {
    schemaVersion = 1,
    id = "mine",
    displayName = "Mine",
    category = BuildingCategory.Resource,
    tags = {
        early_game = true,
        stone = true,
    },

    footprint = { width = 3, depth = 3 },

    buildCost = {
        [ResourceType.Gold] = 200,
        [ResourceType.Wood] = 100,
        [ResourceType.Stone] = 50,
    },
    buildTime = 45,

    unlockRequirements = { level = 3 },

    modelId = "mine_1",

    production = {
        outputs = { [ResourceType.Stone] = 8 },
        interval = 60,
        requiresWorker = true,
        startsPaused = false,
    },
}
