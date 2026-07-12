--[[
    WorkerTypes

    Tipos do sistema de trabalhadores.
    Define os eventos disparados pelo WorkerService.
]]

export type WorkerEvent = {
    kingdomId: string,
    workerId: string,
    workerType: string,
    buildingId: string?,
    timestamp: number,
}

return {}
