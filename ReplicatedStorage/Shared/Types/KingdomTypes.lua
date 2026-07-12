--[[
    KingdomTypes

    Definicao central do tipo KingdomData.
    KingdomData e a fonte unica de verdade do estado do jogador.
    Nenhum sistema deve modificar seus campos diretamente —
    todas as alteracoes passam pelo KingdomService.
]]

local EntityTypes = require(script.Parent.EntityTypes)
local ResourceTypes = require(script.Parent.ResourceTypes)
local PlotTypes = require(script.Parent.PlotTypes)
local BuildingDomainTypes = require(script.Parent.BuildingDomainTypes)

export type KingdomState = "Loading" | "Ready" | "Saving" | "Closing"

export type KingdomData = {
    -- Identificacao
    kingdomId: string,
    ownerUserId: number,
    displayName: string,

    -- Core
    level: number,
    state: KingdomState,

    -- Timestamps
    createdAt: number,
    lastLoadedAt: number,
    lastSavedAt: number,

    -- Versionamento para DataStore migrations
    schemaVersion: number,
    metadata: { [string]: any },
    statistics: { [string]: number },

    -- Dominios
    resources: ResourceTypes.Resources,
    plot: PlotTypes.PlotData?,
    buildings: { [string]: BuildingDomainTypes.BuildingData },
    workers: { [string]: EntityTypes.WorkerData },
    technologies: { [string]: EntityTypes.TechState },
}

return {}
