--[[
    ProductionTypes

    Tipos do sistema de producao de edificios.
    Define a estrutura dos eventos de producao
    disparados no EventBus.
]]

export type ProductionCompletedEvent = {
    kingdomId: string,
    buildingId: string,
    definitionId: string,
    outputs: { [number]: number },
    timestamp: number,
}

return {}
