local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceBuildingRemote = require(ReplicatedStorage.Shared.Remotes.PlaceBuilding)

local PlacementHandler = {}
PlacementHandler.__index = PlacementHandler

function PlacementHandler.new(serviceLocator: any): any
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = nil,
        _kingdomService = nil,
        _buildingService = nil,
    }, PlacementHandler)
end

function PlacementHandler:init()
    self._logger = self._serviceLocator:get("Logger")
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._buildingService = self._serviceLocator:get("Building")
    self._logger:info("PlacementHandler initialized")
end

function PlacementHandler:start()
    PlaceBuildingRemote.OnServerInvoke = function(player: Player, definitionId: string, x: number, z: number, rotation: number): (boolean, string?)
        local kingdom: any = self._kingdomService:GetByPlayer(player.UserId)
        if not kingdom then
            return false, "Kingdom not found"
        end
        local success: boolean
        local reason: string?
        success, reason = self._buildingService:PlaceBuilding(kingdom.kingdomId, definitionId, x, z, rotation)
        return success, reason
    end
    self._logger:info("PlacementHandler started")
end

function PlacementHandler:stop()
    PlaceBuildingRemote.OnServerInvoke = nil
    self._logger:info("PlacementHandler stopped")
end

return PlacementHandler
