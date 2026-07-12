--[[
    ConstructionTimer

    Gerencia a transicao de edificios do estado
    Constructing (1) para Active (2) apos o tempo
    de construcao definido na BuildingDefinition.

    Escuta BuildingPlaced para iniciar o timer.
    Dispara BuildingActivated quando a construcao termina.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingState = require(ReplicatedStorage.Shared.Enums.BuildingState)

export type ConstructionTimer = {
    _serviceLocator: any,
    _logger: any,
    _eventBus: any,
    _kingdomService: any,
    _buildingRegistry: any,
    _subscriptions: { any },
    _running: boolean,
}

local ConstructionTimer: ConstructionTimer = {}
ConstructionTimer.__index = ConstructionTimer

function ConstructionTimer.new(serviceLocator: any): ConstructionTimer
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = nil,
        _eventBus = nil,
        _kingdomService = nil,
        _buildingRegistry = nil,
        _subscriptions = {},
        _running = false,
    }, ConstructionTimer)
end

function ConstructionTimer:init()
    self._logger = self._serviceLocator:get("Logger")
    self._eventBus = self._serviceLocator:get("EventBus")
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._buildingRegistry = self._serviceLocator:get("BuildingRegistry")
    self._logger:info("ConstructionTimer initialized")
end

function ConstructionTimer:start()
    table.insert(self._subscriptions, self._eventBus:on("BuildingPlaced", function(data: any)
        self:_onBuildingPlaced(data.kingdomId, data.building, data.definitionId)
    end))
    self._running = true
    self._logger:info("ConstructionTimer started")
end

function ConstructionTimer:stop()
    for _, sub: any in ipairs(self._subscriptions) do
        sub:Disconnect()
    end
    self._subscriptions = {}
    self._running = false
    self._logger:info("ConstructionTimer stopped")
end

function ConstructionTimer:_onBuildingPlaced(kingdomId: string, building: any, definitionId: string)
    local definition: any = self._buildingRegistry:GetById(definitionId)
    if not definition then
        return
    end

    local buildTime: number = definition.buildTime or 0

    if buildTime <= 1 then
        self:_activateBuilding(kingdomId, building.buildingId, definitionId)
        return
    end

    task.delay(buildTime, function()
        self:_activateBuilding(kingdomId, building.buildingId, definitionId)
    end)
end

function ConstructionTimer:_activateBuilding(kingdomId: string, buildingId: string, definitionId: string)
    if not self._running then
        return
    end

    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return
    end

    local building: any = kingdom.buildings[buildingId]
    if not building or building.state ~= BuildingState.Constructing then
        return
    end

    building.state = BuildingState.Active
    kingdom.lastSavedAt = os.time()

    self._eventBus:fire("BuildingActivated", {
        kingdomId = kingdomId,
        buildingId = buildingId,
        definitionId = definitionId,
        timestamp = os.time(),
    })

    self._logger:info(string.format("Building %s activated in kingdom %s", buildingId, kingdomId))
end

return ConstructionTimer
