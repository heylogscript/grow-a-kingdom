--[[
    BuildingDefinition: TownHall

    Edificio central do reino.
    Unico por reino.
    Nao produz recursos — funciona como hub de progressao.
    Nao requer desbloqueio (ja vem com o reino).
]]

local ResourceType = require(script.Parent.Parent.Enums.ResourceType)
local BuildingCategory = require(script.Parent.BuildingCategories)

return {
    schemaVersion = 1,
    id = "townhall",
    displayName = "Town Hall",
    category = BuildingCategory.Special,
    tags = {
        core = true,
        unique = true,
    },

    footprint = { width = 5, depth = 5 },

    buildCost = {},
    buildTime = 1,

    modelId = "townhall_1",
}
