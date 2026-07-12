--[[
    ProductionService

    Service responsavel por gerenciar a producao automatica
    de recursos pelos edificios.

    Cada edificio com campo `production` na definicao e registrado
    como produtor ao ser construido. Um heartbeat periodico verifica
    se o intervalo de producao foi atingido e adiciona os recursos
    ao Kingdom.

    Estados:
    - paused: true → producao congelada (ex: sem worker)
    - paused: false → produz no intervalo definido
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProductionTypes = require(ReplicatedStorage.Shared.Types.ProductionTypes)

local HEARTBEAT_INTERVAL = 3

export type ProductionService = {
    _serviceLocator: any,
    _logger: any,
    _eventBus: any,
    _resourceService: any,
    _kingdomService: any,
    _workerService: any,
    _buildingRegistry: any,
    _running: boolean,
    _producerList: { ProducerState },
    _producerMap: { [string]: { [string]: ProducerState } },
    _subscriptions: { any },
}

type ProducerState = {
    buildingId: string,
    kingdomId: string,
    definitionId: string,
    interval: number,
    outputs: { [number]: number },
    lastProducedAt: number,
    requiresWorker: boolean,
    paused: boolean,
}

local ProductionService: ProductionService = {}
ProductionService.__index = ProductionService

function ProductionService.new(serviceLocator: any): ProductionService
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = nil,
        _eventBus = nil,
        _resourceService = nil,
        _kingdomService = nil,
        _buildingRegistry = nil,
        _running = false,
        _producerList = {},
        _producerMap = {},
        _subscriptions = {},
    }, ProductionService)
end

function ProductionService:init()
    self._logger = self._serviceLocator:get("Logger")
    self._eventBus = self._serviceLocator:get("EventBus")
    self._resourceService = self._serviceLocator:get("Resource")
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._workerService = self._serviceLocator:get("Workers")
    self._buildingRegistry = self._serviceLocator:get("BuildingRegistry")
    self._logger:info("ProductionService initialized")
end

function ProductionService:start()
    table.insert(self._subscriptions, self._eventBus:on("BuildingActivated", function(data: any)
        self:_registerProducer(data.kingdomId, data.buildingId, data.definitionId)
    end))
    table.insert(self._subscriptions, self._eventBus:on("BuildingRemoved", function(data: any)
        self:_onBuildingRemoved(data.kingdomId, data.buildingId)
    end))

    self._running = true
    task.spawn(function()
        while self._running do
            task.wait(HEARTBEAT_INTERVAL)
            self:_tick()
        end
    end)

    self._logger:info("ProductionService started")
end

function ProductionService:stop()
    self._running = false
    for _, sub: any in ipairs(self._subscriptions) do
        sub:Disconnect()
    end
    self._subscriptions = {}
    self._producerList = {}
    self._producerMap = {}
    self._logger:info("ProductionService stopped")
end

-- Registro

function ProductionService:_registerProducer(kingdomId: string, buildingId: string, definitionId: string)
    local definition: any = self._buildingRegistry:GetById(definitionId)
    if not definition then
        return
    end

    local config: any = definition.production
    if not config then
        return
    end

    local state: ProducerState = {
        buildingId = buildingId,
        kingdomId = kingdomId,
        definitionId = definitionId,
        interval = config.interval or 60,
        outputs = config.outputs or {},
        lastProducedAt = os.time(),
        requiresWorker = config.requiresWorker or false,
        paused = config.startsPaused or false,
    }

    table.insert(self._producerList, state)

    if not self._producerMap[kingdomId] then
        self._producerMap[kingdomId] = {}
    end
    self._producerMap[kingdomId][buildingId] = state
end

function ProductionService:_onBuildingRemoved(kingdomId: string, buildingId: string)
    local kingdomProducers: { [string]: ProducerState }? = self._producerMap[kingdomId]
    if not kingdomProducers then
        return
    end

    local state: ProducerState? = kingdomProducers[buildingId]
    if not state then
        return
    end

    kingdomProducers[buildingId] = nil

    for i: number = #self._producerList, 1, -1 do
        if self._producerList[i] == state then
            table.remove(self._producerList, i)
            break
        end
    end
end

-- Heartbeat

function ProductionService:_tick()
    local now: number = os.time()

    for _, producer: ProducerState in ipairs(self._producerList) do
        if producer.paused then
            continue
        end

        if now - producer.lastProducedAt >= producer.interval then
            self:_produce(producer)
            producer.lastProducedAt = now
        end
    end
end

function ProductionService:_produce(producer: ProducerState)
    if producer.requiresWorker then
        if not self._workerService:IsWorkerAssigned(producer.kingdomId, producer.buildingId) then
            return
        end
    end

    local kingdom: any = self._kingdomService:GetById(producer.kingdomId)
    if not kingdom or kingdom.state ~= "Ready" then
        return
    end

    local building: any = kingdom.buildings[producer.buildingId]
    if not building or building.state ~= 2 then
        return
    end

    for resourceType: number, amount: number in producer.outputs do
        self._resourceService:Add(producer.kingdomId, resourceType, amount, "production")
    end

    self._eventBus:fire("ProductionCompleted", {
        kingdomId = producer.kingdomId,
        buildingId = producer.buildingId,
        definitionId = producer.definitionId,
        outputs = producer.outputs,
        timestamp = os.time(),
    })
end

-- API Publica

--- Pausa a producao de um edificio.
--- @param kingdomId string
--- @param buildingId string
--- @return boolean
function ProductionService:Pause(kingdomId: string, buildingId: string): boolean
    local producer: ProducerState? = self:_findProducer(kingdomId, buildingId)
    if not producer then
        return false
    end
    producer.paused = true
    return true
end

--- Retoma a producao de um edificio.
--- @param kingdomId string
--- @param buildingId string
--- @return boolean
function ProductionService:Resume(kingdomId: string, buildingId: string): boolean
    local producer: ProducerState? = self:_findProducer(kingdomId, buildingId)
    if not producer then
        return false
    end
    producer.paused = false
    return true
end

--- Retorna estado atual da producao de um edificio.
--- @param kingdomId string
--- @param buildingId string
--- @return { paused: boolean, lastProducedAt: number, interval: number }?
function ProductionService:GetStatus(kingdomId: string, buildingId: string): { paused: boolean, lastProducedAt: number, interval: number }?
    local producer: ProducerState? = self:_findProducer(kingdomId, buildingId)
    if not producer then
        return nil
    end
    return {
        paused = producer.paused,
        lastProducedAt = producer.lastProducedAt,
        interval = producer.interval,
    }
end

function ProductionService:_findProducer(kingdomId: string, buildingId: string): ProducerState?
    local kingdomProducers: { [string]: ProducerState }? = self._producerMap[kingdomId]
    if not kingdomProducers then
        return nil
    end
    return kingdomProducers[buildingId]
end

return ProductionService
