--[[
    WorkerService

    Service responsavel por gerenciar trabalhadores dos reinos.

    Responsabilidades:
    - Contratar/demitir workers
    - Atribuir/desatribuir workers a edificios
    - Calcular capacidade maxima (derivada de edificios Housing)
    - Impedir producao em edificios sem worker atribuido

    Capacidade:
    - Cada House ativa fornece +2 vagas de worker
    - Base inicial: 0
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local EntityTypes = require(ReplicatedStorage.Shared.Types.EntityTypes)
local WorkerTypes = require(ReplicatedStorage.Shared.Types.WorkerTypes)
local BuildingCategory = require(ReplicatedStorage.Shared.Buildings.BuildingCategories)

local WORKER_CAPACITY_PER_HOUSE = 2

export type WorkerService = {
    _serviceLocator: any,
    _logger: any,
    _eventBus: any,
    _kingdomService: any,
    _buildingRegistry: any,
    _subscriptions: { any },
}

local WorkerService: WorkerService = {}
WorkerService.__index = WorkerService

function WorkerService.new(serviceLocator: any): WorkerService
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = nil,
        _eventBus = nil,
        _kingdomService = nil,
        _buildingRegistry = nil,
        _subscriptions = {},
    }, WorkerService)
end

function WorkerService:init()
    self._logger = self._serviceLocator:get("Logger")
    self._eventBus = self._serviceLocator:get("EventBus")
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._buildingRegistry = self._serviceLocator:get("BuildingRegistry")
    self._logger:info("WorkerService initialized")
end

function WorkerService:start()
    table.insert(self._subscriptions, self._eventBus:on("BuildingActivated", function(data: any)
        self:_onBuildingActivated(data.kingdomId, data.buildingId, data.definitionId)
    end))
    self._logger:info("WorkerService started")
end

function WorkerService:stop()
    for _, sub: any in ipairs(self._subscriptions) do
        sub:Disconnect()
    end
    self._subscriptions = {}
    self._logger:info("WorkerService stopped")
end

-- Auto-atribuicao

function WorkerService:_onBuildingActivated(kingdomId: string, buildingId: string, definitionId: string)
    local definition: any = self._buildingRegistry:GetById(definitionId)
    if not definition or not definition.production then
        return
    end
    if not definition.production.requiresWorker then
        return
    end
    if self:IsWorkerAssigned(kingdomId, buildingId) then
        return
    end

    local counts: { total: number, assigned: number, idle: number, capacity: number } = self:GetWorkerCount(kingdomId)
    if counts.idle < 1 then
        return
    end

    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return
    end

    for _: string, worker: EntityTypes.WorkerData in kingdom.workers do
        if worker.assignedToBuildingId == nil then
            worker.assignedToBuildingId = buildingId
            kingdom.lastSavedAt = os.time()

            self._eventBus:fire("WorkerAssigned", {
                kingdomId = kingdomId,
                workerId = worker.workerId,
                workerType = worker.workerType,
                buildingId = buildingId,
                timestamp = os.time(),
            })

            self._logger:info(string.format(
                "Auto-assigned worker %s to building %s in kingdom %s",
                worker.workerId, buildingId, kingdomId
            ))
            break
        end
    end
end

-- Capacidade

--- Calcula capacidade maxima de workers de um Kingdom.
--- Base: 0. Cada House (Active) adiciona WORKER_CAPACITY_PER_HOUSE.
--- @param kingdomId string
--- @return number
function WorkerService:GetCapacity(kingdomId: string): number
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return 0
    end

    local capacity: number = 0
    for _: string, building: any in kingdom.buildings do
        if building.state ~= 2 then
            continue
        end
        local definition: any = self._buildingRegistry:GetById(building.definitionId)
        if not definition then
            continue
        end
        if definition.category == BuildingCategory.Housing then
            capacity += WORKER_CAPACITY_PER_HOUSE
        end
    end
    return capacity
end

--- Retorna contagem atual de workers.
--- @param kingdomId string
--- @return { total: number, assigned: number, idle: number, capacity: number }
function WorkerService:GetWorkerCount(kingdomId: string): { total: number, assigned: number, idle: number, capacity: number }
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return { total = 0, assigned = 0, idle = 0, capacity = 0 }
    end

    local total: number = 0
    local assigned: number = 0
    for _: string, worker: EntityTypes.WorkerData in kingdom.workers do
        total += 1
        if worker.assignedToBuildingId ~= nil then
            assigned += 1
        end
    end

    return {
        total = total,
        assigned = assigned,
        idle = total - assigned,
        capacity = self:GetCapacity(kingdomId),
    }
end

--- Verifica se um edificio possui worker atribuido.
--- @param kingdomId string
--- @param buildingId string
--- @return boolean
function WorkerService:IsWorkerAssigned(kingdomId: string, buildingId: string): boolean
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return false
    end
    for _: string, worker: EntityTypes.WorkerData in kingdom.workers do
        if worker.assignedToBuildingId == buildingId then
            return true
        end
    end
    return false
end

--- Retorna o workerId do worker atribuido a um edificio.
--- @param kingdomId string
--- @param buildingId string
--- @return string?
function WorkerService:GetAssignedWorker(kingdomId: string, buildingId: string): string?
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return nil
    end
    for _: string, worker: EntityTypes.WorkerData in kingdom.workers do
        if worker.assignedToBuildingId == buildingId then
            return worker.workerId
        end
    end
    return nil
end

-- Contratacao

--- Contrata um novo worker para o Kingdom.
--- Respeita o limite de capacidade.
--- @param kingdomId string
--- @param workerType string — tipo de worker (ex: "builder")
--- @return EntityTypes.WorkerData?, string?
function WorkerService:HireWorker(kingdomId: string, workerType: string): (EntityTypes.WorkerData?, string?)
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return nil, "Kingdom not found"
    end
    if kingdom.state ~= "Ready" then
        return nil, "Kingdom not ready"
    end

    local counts: { total: number, assigned: number, idle: number, capacity: number } = self:GetWorkerCount(kingdomId)
    if counts.total >= counts.capacity then
        return nil, "Worker capacity reached"
    end

    local worker: EntityTypes.WorkerData = {
        workerId = HttpService:GenerateGUID(false),
        workerType = workerType,
        assignedToBuildingId = nil,
        hiredAt = os.time(),
    }

    local added: boolean = self._kingdomService:AddWorker(kingdomId, worker)
    if not added then
        return nil, "Failed to add worker to kingdom"
    end

    self._eventBus:fire("WorkerHired", {
        kingdomId = kingdomId,
        workerId = worker.workerId,
        workerType = workerType,
        buildingId = nil,
        timestamp = os.time(),
    })

    self._logger:info(string.format("Worker %s hired in kingdom %s", worker.workerId, kingdomId))
    return worker, nil
end

--- Demite um worker do Kingdom.
--- @param kingdomId string
--- @param workerId string
--- @return boolean, string?
function WorkerService:FireWorker(kingdomId: string, workerId: string): (boolean, string?)
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return false, "Kingdom not found"
    end

    local worker: EntityTypes.WorkerData? = kingdom.workers[workerId]
    if not worker then
        return false, "Worker not found"
    end

    local removed: boolean = self._kingdomService:RemoveWorker(kingdomId, workerId)
    if not removed then
        return false, "Failed to remove worker"
    end

    self._eventBus:fire("WorkerFired", {
        kingdomId = kingdomId,
        workerId = workerId,
        workerType = worker.workerType,
        buildingId = nil,
        timestamp = os.time(),
    })

    self._logger:info(string.format("Worker %s fired from kingdom %s", workerId, kingdomId))
    return true, nil
end

-- Atribuicao

--- Atribui um worker a um edificio produtor.
--- @param kingdomId string
--- @param workerId string
--- @param buildingId string
--- @return boolean, string?
function WorkerService:AssignWorker(kingdomId: string, workerId: string, buildingId: string): (boolean, string?)
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return false, "Kingdom not found"
    end

    local worker: EntityTypes.WorkerData? = kingdom.workers[workerId]
    if not worker then
        return false, "Worker not found"
    end
    if worker.assignedToBuildingId ~= nil then
        return false, "Worker already assigned"
    end

    local building: any = kingdom.buildings[buildingId]
    if not building then
        return false, "Building not found"
    end
    if building.state ~= 2 then
        return false, "Building is not active"
    end

    local definition: any = self._buildingRegistry:GetById(building.definitionId)
    if not definition or not definition.production then
        return false, "Building does not require workers"
    end
    if not definition.production.requiresWorker then
        return false, "Building does not require workers"
    end

    if self:IsWorkerAssigned(kingdomId, buildingId) then
        return false, "Building already has a worker assigned"
    end

    worker.assignedToBuildingId = buildingId
    kingdom.lastSavedAt = os.time()

    self._eventBus:fire("WorkerAssigned", {
        kingdomId = kingdomId,
        workerId = workerId,
        workerType = worker.workerType,
        buildingId = buildingId,
        timestamp = os.time(),
    })

    self._logger:info(string.format("Worker %s assigned to building %s in kingdom %s", workerId, buildingId, kingdomId))
    return true, nil
end

--- Remove a atribuicao de um worker do seu edificio atual.
--- @param kingdomId string
--- @param workerId string
--- @return boolean, string?
function WorkerService:UnassignWorker(kingdomId: string, workerId: string): (boolean, string?)
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return false, "Kingdom not found"
    end

    local worker: EntityTypes.WorkerData? = kingdom.workers[workerId]
    if not worker then
        return false, "Worker not found"
    end
    if worker.assignedToBuildingId == nil then
        return false, "Worker is not assigned"
    end

    local previousBuildingId: string = worker.assignedToBuildingId
    worker.assignedToBuildingId = nil
    kingdom.lastSavedAt = os.time()

    self._eventBus:fire("WorkerUnassigned", {
        kingdomId = kingdomId,
        workerId = workerId,
        workerType = worker.workerType,
        buildingId = previousBuildingId,
        timestamp = os.time(),
    })

    self._logger:info(string.format("Worker %s unassigned from building %s in kingdom %s", workerId, previousBuildingId, kingdomId))
    return true, nil
end

-- Consultas

--- Retorna dados de um worker.
--- @param kingdomId string
--- @param workerId string
--- @return EntityTypes.WorkerData?
function WorkerService:GetWorker(kingdomId: string, workerId: string): EntityTypes.WorkerData?
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return nil
    end
    return kingdom.workers[workerId]
end

--- Retorna todos os workers de um Kingdom.
--- @param kingdomId string
--- @return { [string]: EntityTypes.WorkerData }
function WorkerService:GetWorkers(kingdomId: string): { [string]: EntityTypes.WorkerData }
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return {}
    end
    return kingdom.workers
end

return WorkerService
