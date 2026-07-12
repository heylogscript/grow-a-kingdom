export type PlacementValidator = {
    _serviceLocator: any,
    _logger: any,
    _plotService: any,
    _buildingRegistry: any,
}

local PlacementValidator: PlacementValidator = {}
PlacementValidator.__index = PlacementValidator

function PlacementValidator.new(serviceLocator: any): PlacementValidator
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = serviceLocator:get("Logger"),
        _plotService = nil,
        _buildingRegistry = nil,
    }, PlacementValidator)
end

function PlacementValidator:init()
    self._plotService = self._serviceLocator:get("Plot")
    self._buildingRegistry = self._serviceLocator:get("BuildingRegistry")
    self._logger:info("PlacementValidator initialized")
end

local VALID_ROTATIONS: { [number]: boolean } = {
    [0] = true,
    [90] = true,
    [180] = true,
    [270] = true,
}

function PlacementValidator:Validate(kingdomId: string, definitionId: string, x: number, z: number, rotation: number?): (boolean, string?)
    local definition: any = self._buildingRegistry:GetById(definitionId)
    if not definition then
        return false, "Definition not found: " .. definitionId
    end

    local rot: number = rotation or 0
    if not VALID_ROTATIONS[rot] then
        return false, "Invalid rotation: " .. tostring(rot)
    end

    local footprint: any = definition.footprint
    local fw: number = footprint and footprint.width or 1
    local fz: number = footprint and footprint.depth or 1

    if not self._plotService:IsAreaFree(kingdomId, x, z, fw, fz, rot) then
        return false, "Footprint area not available"
    end

    return true, nil
end

return PlacementValidator
