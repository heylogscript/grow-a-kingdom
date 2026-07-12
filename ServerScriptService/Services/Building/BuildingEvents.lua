local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingDomainTypes = require(ReplicatedStorage.Shared.Types.BuildingDomainTypes)

export type BuildingEvents = {
    _serviceLocator: any,
    _eventBus: any,
    _logger: any,
}

local BuildingEvents: BuildingEvents = {}
BuildingEvents.__index = BuildingEvents

function BuildingEvents.new(serviceLocator: any): BuildingEvents
    return setmetatable({
        _serviceLocator = serviceLocator,
        _eventBus = nil,
        _logger = nil,
    }, BuildingEvents)
end

function BuildingEvents:init()
    self._eventBus = self._serviceLocator:get("EventBus")
    self._logger = self._serviceLocator:get("Logger")
end

function BuildingEvents:Placed(kingdomId: string, building: BuildingDomainTypes.BuildingData, definitionId: string)
    local ok: boolean, err: any = pcall(function()
        self._eventBus:fire("BuildingPlaced", {
            kingdomId = kingdomId,
            building = building,
            definitionId = definitionId,
            timestamp = os.time(),
        })
    end)
    if not ok then
        self._logger:error("BuildingPlaced event failed: " .. tostring(err))
    end
end

function BuildingEvents:Removed(kingdomId: string, buildingId: string, reason: string)
    local ok: boolean, err: any = pcall(function()
        self._eventBus:fire("BuildingRemoved", {
            kingdomId = kingdomId,
            buildingId = buildingId,
            reason = reason,
            timestamp = os.time(),
        })
    end)
    if not ok then
        self._logger:error("BuildingRemoved event failed: " .. tostring(err))
    end
end

function BuildingEvents:Changed(kingdomId: string, action: string, buildingId: string, changes: { [string]: any }?)
    local ok: boolean, err: any = pcall(function()
        self._eventBus:fire("BuildingChanged", {
            kingdomId = kingdomId,
            action = action,
            buildingId = buildingId,
            changes = changes,
            timestamp = os.time(),
        })
    end)
    if not ok then
        self._logger:error("BuildingChanged event failed: " .. tostring(err))
    end
end

return BuildingEvents
