local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingFactory = require(script.Parent.BuildingFactory)
local BuildingDomainTypes = require(ReplicatedStorage.Shared.Types.BuildingDomainTypes)
local BuildingState = require(ReplicatedStorage.Shared.Enums.BuildingState)

export type BuildingService = {
    _serviceLocator: any,
    _logger: any,
    _resourceService: any,
    _kingdomService: any,
    _plotService: any,
    _placementValidator: any,
    _requirementValidator: any,
    _events: any,
    _factory: any,
    _buildingRegistry: any,
}

local BuildingService: BuildingService = {}
BuildingService.__index = BuildingService

function BuildingService.new(serviceLocator: any): BuildingService
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = nil,
        _resourceService = nil,
        _kingdomService = nil,
        _plotService = nil,
        _placementValidator = nil,
        _requirementValidator = nil,
        _events = nil,
        _factory = nil,
        _buildingRegistry = nil,
    }, BuildingService)
end

function BuildingService:init()
    self._logger = self._serviceLocator:get("Logger")
    self._resourceService = self._serviceLocator:get("Resource")
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._plotService = self._serviceLocator:get("Plot")
    self._placementValidator = self._serviceLocator:get("PlacementValidator")
    self._requirementValidator = self._serviceLocator:get("RequirementValidator")
    self._events = self._serviceLocator:get("BuildingEvents")
    self._factory = BuildingFactory.new()
    self._buildingRegistry = self._serviceLocator:get("BuildingRegistry")
    self._logger:info("BuildingService initialized")
end

function BuildingService:start()
    self._logger:info("BuildingService started")
end

function BuildingService:stop()
    self._logger:info("BuildingService stopped")
end

function BuildingService:_refund(kingdomId: string, cost: { [number]: number })
    for resourceType: number, amount: number in cost do
        self._resourceService:Add(kingdomId, resourceType, amount, "building_rollback")
    end
end

function BuildingService:_refundIfSpent(kingdomId: string, cost: { [number]: number }?)
    if cost and next(cost) ~= nil then
        self:_refund(kingdomId, cost)
    end
end

--- Saga: coloca um edificio no grid de um Kingdom.
--- F1: PlacementValidator (read-only)
--- F2: RequirementValidator (read-only)
--- F3: PlotService.ReserveArea (occupancy cache atomico)
--- F4: ResourceService.TrySpend (debita recursos)
--- F5: BuildingFactory.Create (monta BuildingData)
--- F6: KingdomService.AddBuilding (persiste)
--- F7: BuildingEvents.Placed (opcional, falha so loga)
function BuildingService:PlaceBuilding(
    kingdomId: string,
    definitionId: string,
    x: number,
    z: number,
    rotation: number?
): (boolean, string?, BuildingDomainTypes.BuildingData?)
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return false, "Kingdom not found", nil
    end

    local definition: any = self._buildingRegistry:GetById(definitionId)
    if not definition then
        return false, "Definition not found", nil
    end

    local cost: { [number]: number }? = definition.buildCost
    local footprint: any = definition.footprint
    local fw: number = footprint and footprint.width or 1
    local fz: number = footprint and footprint.depth or 1

    -- F1: Validar posicionamento (read-only)
    local placementOk: boolean
    local placementReason: string?
    placementOk, placementReason = self._placementValidator:Validate(kingdomId, definitionId, x, z, rotation)
    if not placementOk then
        return false, placementReason, nil
    end

    -- F2: Validar requisitos (read-only)
    local reqOk: boolean
    local reqReason: string?
    reqOk, reqReason = self._requirementValidator:Validate(kingdomId, definitionId, cost)
    if not reqOk then
        return false, reqReason, nil
    end

    local rot: number = rotation or 0

    -- F3: Reservar celulas (atomico: valida todas, ocupa todas)
    local reserved: boolean = self._plotService:ReserveArea(kingdomId, x, z, fw, fz, rot, definitionId)
    if not reserved then
        return false, "Failed to reserve area", nil
    end

    -- F4: Gastar recursos
    if cost and next(cost) ~= nil then
        local spent: boolean = self._resourceService:TrySpend(kingdomId, cost, "building_placement")
        if not spent then
            self._plotService:ReleaseArea(kingdomId, x, z, fw, fz, rot, definitionId)
            return false, "Failed to spend resources", nil
        end
    end

    -- F5: Criar BuildingData (factory pura, sem level/state)
    local building: BuildingDomainTypes.BuildingData = self._factory:Create(definitionId, { x = x, z = z }, rotation)
    building.state = BuildingState.Constructing
    building.level = 1

    -- Atualizar reserva com o ID real (sem validacao — celulas ja ocupadas pelo placeholder)
    self._plotService:SetReservation(kingdomId, x, z, fw, fz, rot, building.buildingId)

    -- F6: Persistir no KingdomData
    local persisted: boolean = self._kingdomService:AddBuilding(kingdomId, building)
    if not persisted then
        self:_refundIfSpent(kingdomId, cost)
        self._plotService:ReleaseArea(kingdomId, x, z, fw, fz, rot, building.buildingId)
        return false, "Failed to persist building", nil
    end

    -- F7: Notificar (falha nao quebra a transacao)
    self._events:Placed(kingdomId, building, definitionId)

    self._logger:info(string.format(
        "Building %s (%s) placed at (%d, %d) in kingdom %s",
        building.buildingId, definitionId, x, z, kingdomId
    ))
    return true, nil, building
end

--- Remove um edificio de um Kingdom.
function BuildingService:RemoveBuilding(kingdomId: string, buildingId: string): (boolean, string?)
    local building: BuildingDomainTypes.BuildingData? = self._kingdomService:GetBuilding(kingdomId, buildingId)
    if not building then
        return false, "Building not found"
    end

    local definition: any = self._buildingRegistry:GetById(building.definitionId)
    local fw: number = 1
    local fz: number = 1
    if definition and definition.footprint then
        fw = definition.footprint.width or 1
        fz = definition.footprint.depth or 1
    end
    local rot: number = building.rotation or 0

    local removed: boolean = self._kingdomService:RemoveBuilding(kingdomId, buildingId)
    if not removed then
        return false, "Failed to remove building from kingdom"
    end

    self._plotService:ReleaseArea(kingdomId, building.position.x, building.position.z, fw, fz, rot, building.buildingId)
    self._events:Removed(kingdomId, buildingId, "destroyed")

    self._logger:info(string.format("Building %s removed from kingdom %s", buildingId, kingdomId))
    return true, nil
end

return BuildingService
