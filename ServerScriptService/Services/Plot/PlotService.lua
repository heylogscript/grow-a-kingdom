local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotTypes = require(ReplicatedStorage.Shared.Types.PlotTypes)
local PlotModel = require(ReplicatedStorage.Shared.Models.PlotModel)
local GridMath = require(ReplicatedStorage.Shared.Grid.GridMath)

export type PlotService = {
    _serviceLocator: any,
    _logger: any,
    _kingdomService: any,
    _buildingRegistry: any,
    _occupancy: { [string]: { [string]: string } },
}

local PlotService: PlotService = {}
PlotService.__index = PlotService

function PlotService.new(serviceLocator: any): PlotService
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = serviceLocator:get("Logger"),
        _kingdomService = nil,
        _buildingRegistry = nil,
        _occupancy = {},
    }, PlotService)
end

function PlotService:init()
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._buildingRegistry = self._serviceLocator:get("BuildingRegistry")
    self._logger:info("PlotService initialized")
end

function PlotService:start()
    self._logger:info("PlotService started")
end

function PlotService:stop()
    self._occupancy = {}
    self._logger:info("PlotService stopped")
end

function PlotService:CreatePlot(kingdomId: string): boolean
    local plotData: PlotTypes.PlotData = PlotModel.new()
    local ok: boolean = self._kingdomService:SetPlotData(kingdomId, plotData)
    if ok then
        self:RebuildOccupancy(kingdomId)
        self._logger:info(string.format("Plot created for kingdom %s: %dx%d", kingdomId, plotData.gridWidth, plotData.gridDepth))
    end
    return ok
end

function PlotService:GetPlot(kingdomId: string): PlotTypes.PlotData?
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return nil
    end
    return kingdom.plot
end

function PlotService:IsInside(kingdomId: string, x: number, z: number): boolean
    local plot: PlotTypes.PlotData? = self:GetPlot(kingdomId)
    if not plot then
        return false
    end
    return x >= 1 and x <= plot.gridWidth and z >= 1 and z <= plot.gridDepth
end

function PlotService:IsCellFree(kingdomId: string, x: number, z: number): boolean
    local cells: { [string]: string }? = self._occupancy[kingdomId]
    if not cells then
        return true
    end
    local key: string = x .. "," .. z
    return cells[key] == nil
end

function PlotService:IsAreaFree(kingdomId: string, startX: number, startZ: number, width: number, depth: number, rotation: number?): boolean
    local rot: number = rotation or 0
    local cells: any = GridMath.GetOccupiedCells(startX, startZ, width, depth, rot)
    for _, cell: any in ipairs(cells) do
        if not self:IsInside(kingdomId, cell.x, cell.z) then
            return false
        end
        if not self:IsCellFree(kingdomId, cell.x, cell.z) then
            return false
        end
    end
    return true
end

function PlotService:ReserveArea(kingdomId: string, x: number, z: number, width: number, depth: number, rotation: number, buildingId: string): boolean
    if not self:IsAreaFree(kingdomId, x, z, width, depth, rotation) then
        return false
    end

    if not self._occupancy[kingdomId] then
        self._occupancy[kingdomId] = {}
    end

    local cellsTable: { [string]: string } = self._occupancy[kingdomId]
    local occupied: any = GridMath.GetOccupiedCells(x, z, width, depth, rotation)
    for _, cell: any in ipairs(occupied) do
        cellsTable[cell.x .. "," .. cell.z] = buildingId
    end
    return true
end

function PlotService:SetReservation(kingdomId: string, x: number, z: number, width: number, depth: number, rotation: number, buildingId: string)
    if not self._occupancy[kingdomId] then
        self._occupancy[kingdomId] = {}
    end
    local cellsTable: { [string]: string } = self._occupancy[kingdomId]
    local occupied: any = GridMath.GetOccupiedCells(x, z, width, depth, rotation)
    for _, cell: any in ipairs(occupied) do
        cellsTable[cell.x .. "," .. cell.z] = buildingId
    end
end

function PlotService:ReleaseArea(kingdomId: string, x: number, z: number, width: number, depth: number, rotation: number, buildingId: string)
    local cellsTable: { [string]: string }? = self._occupancy[kingdomId]
    if not cellsTable then
        return
    end
    local occupied: any = GridMath.GetOccupiedCells(x, z, width, depth, rotation)
    for _, cell: any in ipairs(occupied) do
        local key: string = cell.x .. "," .. cell.z
        if cellsTable[key] == buildingId then
            cellsTable[key] = nil
        end
    end
end

function PlotService:RebuildOccupancy(kingdomId: string)
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return
    end
    self._occupancy[kingdomId] = {}
    local cells: { [string]: string } = self._occupancy[kingdomId]

    for _bid: string, building: any in kingdom.buildings do
        local pos: any = building.position
        if not pos then
            continue
        end
        local definition: any = self._buildingRegistry:GetById(building.definitionId)
        local fw: number = 1
        local fz: number = 1
        if definition and definition.footprint then
            fw = definition.footprint.width or 1
            fz = definition.footprint.depth or 1
        end
        local rotation: number = building.rotation or 0
        local occupied: any = GridMath.GetOccupiedCells(pos.x, pos.z, fw, fz, rotation)
        for _, cell: any in ipairs(occupied) do
            cells[cell.x .. "," .. cell.z] = building.buildingId
        end
    end
end

function PlotService:GetCell(kingdomId: string, buildingId: string): { x: number, z: number }?
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return nil
    end
    local building: any = kingdom.buildings[buildingId]
    if not building then
        return nil
    end
    return {
        x = building.position.x,
        z = building.position.z,
    }
end

function PlotService:GetNeighbors(kingdomId: string, x: number, z: number): { { x: number, z: number } }
    local neighbors: { { x: number, z: number } } = {}
    local dirs: { { dx: number, dz: number } } = {
        { dx = -1, dz = 0 },
        { dx = 1, dz = 0 },
        { dx = 0, dz = -1 },
        { dx = 0, dz = 1 },
    }
    for _i: number, dir: { dx: number, dz: number } in dirs do
        local nx: number = x + dir.dx
        local nz: number = z + dir.dz
        if self:IsInside(kingdomId, nx, nz) then
            table.insert(neighbors, { x = nx, z = nz })
        end
    end
    return neighbors
end

return PlotService
