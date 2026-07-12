--[[
    ResourceTypes

    Tipos do sistema de recursos.
    Separado de EntityTypes para que ResourceService
    e consumidores do evento ResourceChanged possam
    importar apenas o necessario.
]]

export type Resources = { [number]: number }

export type CostTable = { [number]: number }

export type ResourceChange = {
    resourceType: number,
    oldValue: number,
    newValue: number,
}

export type ResourceChangedEvent = {
    kingdomId: string,
    reason: string,
    timestamp: number,
    changes: { ResourceChange },
    triggeredBy: string,
}

return {}
