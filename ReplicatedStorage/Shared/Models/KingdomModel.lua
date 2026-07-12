--[[
    KingdomModel

    Factory pura para criacao de KingdomData.
    Responsabilidade unica: gerar uma tabela KingdomData valida.
    Nenhuma logica de negocio, nenhuma validacao, nenhum getter/setter.
    Toda validacao pertence ao KingdomService.
]]

local ResourceType = require(script.Parent.Parent.Enums.ResourceType)
local KingdomTypes = require(script.Parent.Parent.Types.KingdomTypes)
local HttpService = game:GetService("HttpService")

local KingdomModel = {}

function KingdomModel.new(ownerUserId: number, displayName: string): KingdomTypes.KingdomData
    return {
        kingdomId = HttpService:GenerateGUID(false),
        ownerUserId = ownerUserId,
        displayName = displayName,
        level = 1,
        state = "Loading",
        createdAt = os.time(),
        lastLoadedAt = os.time(),
        lastSavedAt = os.time(),
        schemaVersion = 1,
        metadata = {},
        statistics = {},
        resources = {
            [ResourceType.Gold] = 0,
            [ResourceType.Wood] = 0,
            [ResourceType.Stone] = 0,
            [ResourceType.Food] = 0,
            [ResourceType.Gems] = 0,
        },
        buildings = {},
        workers = {},
        technologies = {},
    }
end

return KingdomModel
