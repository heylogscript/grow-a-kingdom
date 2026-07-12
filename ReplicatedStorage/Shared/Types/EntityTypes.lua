--[[
    EntityTypes

    Tipos de entidades compostas que pertencem ao Kingdom.
    Separados de KingdomTypes para:
    - Evitar arquivos monoliticos
    - Permitir que sistemas especializados (BuildingService, WorkerService)
      importem apenas seus proprios tipos
    - Baixo acoplamento entre definicoes
]]

export type WorkerData = {
    workerId: string,
    workerType: string,
    assignedToBuildingId: string?,
    hiredAt: number,
}

export type TechState = {
    techId: string,
    researched: boolean,
    researchedAt: number?,
}

return {}
