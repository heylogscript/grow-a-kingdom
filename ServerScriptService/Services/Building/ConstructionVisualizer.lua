--[[
    ConstructionVisualizer

    Responsavel por criar e gerenciar as representacoes 3D
    dos edificios no Workspace.

    Fluxo:
    1. Escuta evento BuildingPlaced no EventBus
    2. Obtem Model do AssetRegistry via definitionId
    3. Posiciona no Workspace segudo GridMath
    4. Se estado Constructing: modelo semi-transparente + scaffold
    5. Se estado Active: modelo normal
    6. Escuta BuildingRemoved para cleanup
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GridMath = require(ReplicatedStorage.Shared.Grid.GridMath)
local BuildingState = require(ReplicatedStorage.Shared.Enums.BuildingState)

export type ConstructionVisualizer = {
    _serviceLocator: any,
    _logger: any,
    _eventBus: any,
    _assetRegistry: any,
    _buildingRegistry: any,
    _kingdomService: any,
    _workspaceFolder: Folder?,
    _buildingVisuals: { [string]: { [string]: Model } },
    _subscriptions: { any },
}

local CONSTRUCTION_TRANSPARENCY = 0.5
local SCAFFOLD_COLOR = Color3.fromRGB(200, 160, 80)

local ConstructionVisualizer: ConstructionVisualizer = {}
ConstructionVisualizer.__index = ConstructionVisualizer

function ConstructionVisualizer.new(serviceLocator: any): ConstructionVisualizer
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = nil,
        _eventBus = nil,
        _assetRegistry = nil,
        _buildingRegistry = nil,
        _kingdomService = nil,
        _workspaceFolder = nil,
        _buildingVisuals = {},
        _subscriptions = {},
    }, ConstructionVisualizer)
end

function ConstructionVisualizer:init()
    self._logger = self._serviceLocator:get("Logger")
    self._eventBus = self._serviceLocator:get("EventBus")
    self._assetRegistry = self._serviceLocator:get("AssetRegistry")
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._buildingRegistry = self._serviceLocator:get("BuildingRegistry")
    self._logger:info("ConstructionVisualizer initialized")
end

function ConstructionVisualizer:start()
    table.insert(self._subscriptions, self._eventBus:on("BuildingPlaced", function(data: any)
        self:_onBuildingPlaced(data.kingdomId, data.building, data.definitionId)
    end))
    table.insert(self._subscriptions, self._eventBus:on("BuildingActivated", function(data: any)
        self:SetCompleted(data.kingdomId, data.buildingId)
    end))
    table.insert(self._subscriptions, self._eventBus:on("BuildingRemoved", function(data: any)
        self:_onBuildingRemoved(data.kingdomId, data.buildingId)
    end))

    local connection: RBXScriptConnection? = Players.PlayerRemoving:Connect(function(player: Player)
        local kingdom: any = self._kingdomService:GetByPlayer(player.UserId)
        if kingdom then
            self:_cleanupKingdom(kingdom.kingdomId)
        end
    end)
    table.insert(self._subscriptions, connection)

    self._logger:info("ConstructionVisualizer started")
end

function ConstructionVisualizer:stop()
    for _, sub: any in ipairs(self._subscriptions) do
        if sub.Disconnect then
            sub:Disconnect()
        end
    end
    self._subscriptions = {}
    self:_cleanupAll()
    self._logger:info("ConstructionVisualizer stopped")
end

function ConstructionVisualizer:_cleanupKingdom(kingdomId: string)
    local visuals: { [string]: Model }? = self._buildingVisuals[kingdomId]
    if not visuals then
        return
    end
    for _, model: Model in visuals do
        local scaffold: Model? = self:_findScaffold(model)
        if scaffold then
            scaffold:Destroy()
        end
        model:Destroy()
    end
    self._buildingVisuals[kingdomId] = nil
end

function ConstructionVisualizer:_cleanupAll()
    for kingdomId: string, visuals: { [string]: Model } in self._buildingVisuals do
        for _, model: Model in visuals do
            local scaffold: Model? = self:_findScaffold(model)
            if scaffold then
                scaffold:Destroy()
            end
            model:Destroy()
        end
    end
    self._buildingVisuals = {}
end

function ConstructionVisualizer:_ensureWorkspaceFolder(): Folder
    if not self._workspaceFolder then
        local folder: Folder? = Workspace:FindFirstChild("Buildings")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "Buildings"
            folder.Parent = Workspace
        end
        self._workspaceFolder = folder
    end
    return self._workspaceFolder
end

function ConstructionVisualizer:_getBuildingCFrame(building: any, definition: any): CFrame
    local footprint: any = definition.footprint or { width = 1, depth = 1 }
    return GridMath.GetFootprintCFrame(
        { x = building.position.x, z = building.position.z },
        footprint.width,
        footprint.depth,
        building.rotation or 0
    )
end

function ConstructionVisualizer:_setModelTransparency(model: Model, transparency: number)
    for _, part: Instance in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = math.max(part.Transparency, transparency)
        end
    end
end

function ConstructionVisualizer:_createScaffold(cframe: CFrame, footprintWidth: number, footprintDepth: number): Model
    local scaffold: Model = Instance.new("Model")
    scaffold.Name = "Scaffold"

    local cs: number = 4
    local w: number = footprintWidth * cs
    local d: number = footprintDepth * cs

    local function makeBeam(size: Vector3, offset: CFrame)
        local part: Part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Size = size
        part.Color = SCAFFOLD_COLOR
        part.Material = Enum.Material.Wood
        part.Transparency = 0.3
        part.CFrame = cframe * offset
        part.Parent = scaffold
        return part
    end

    local h: number = 2
    makeBeam(Vector3.new(0.2, h, 0.2), CFrame.new(-w / 2, 0, -d / 2))
    makeBeam(Vector3.new(0.2, h, 0.2), CFrame.new(w / 2, 0, -d / 2))
    makeBeam(Vector3.new(0.2, h, 0.2), CFrame.new(-w / 2, 0, d / 2))
    makeBeam(Vector3.new(0.2, h, 0.2), CFrame.new(w / 2, 0, d / 2))

    makeBeam(Vector3.new(w, 0.2, 0.2), CFrame.new(0, h, -d / 2))
    makeBeam(Vector3.new(w, 0.2, 0.2), CFrame.new(0, h, d / 2))
    makeBeam(Vector3.new(0.2, 0.2, d), CFrame.new(-w / 2, h, 0))
    makeBeam(Vector3.new(0.2, 0.2, d), CFrame.new(w / 2, h, 0))

    scaffold.Parent = self:_ensureWorkspaceFolder()
    return scaffold
end

function ConstructionVisualizer:_onBuildingPlaced(kingdomId: string, building: any, definitionId: string)
    local definition: any = self._buildingRegistry:GetById(definitionId)
    if not definition then
        return
    end

    local model: Model? = self._assetRegistry:GetByDefinitionId(definitionId)
    if not model then
        return
    end

    local cframe: CFrame = self:_getBuildingCFrame(building, definition)
    local footprint: any = definition.footprint or { width = 1, depth = 1 }

    local clone: Model = model:Clone()
    clone.Name = building.buildingId
    clone.Parent = self:_ensureWorkspaceFolder()
    clone:SetPrimaryPartCFrame(cframe)

    if building.state == BuildingState.Constructing then
        self:_setModelTransparency(clone, CONSTRUCTION_TRANSPARENCY)
        self:_createScaffold(cframe, footprint.width, footprint.depth)
        clone:SetAttribute("ConstructionState", "Constructing")
    end

    if not self._buildingVisuals[kingdomId] then
        self._buildingVisuals[kingdomId] = {}
    end
    self._buildingVisuals[kingdomId][building.buildingId] = clone
end

function ConstructionVisualizer:_onBuildingRemoved(kingdomId: string, buildingId: string)
    local kingdomVisuals: { [string]: Model }? = self._buildingVisuals[kingdomId]
    if not kingdomVisuals then
        return
    end

    local model: Model? = kingdomVisuals[buildingId]
    if not model then
        return
    end

    local scaffold: Model? = self:_findScaffold(model)
    if scaffold then
        scaffold:Destroy()
    end

    model:Destroy()
    kingdomVisuals[buildingId] = nil
end

function ConstructionVisualizer:_findScaffold(model: Model): Model?
    for _, child: Instance in ipairs(self._workspaceFolder:GetChildren()) do
        if child:IsA("Model") and child.Name == "Scaffold" then
            local distance: number = (model:GetPrimaryPartCFrame().Position - child:GetPrimaryPartCFrame().Position).Magnitude
            if distance < 1 then
                return child
            end
        end
    end
    return nil
end

--- Transiciona um edificio do estado Constructing para Active.
--- @param kingdomId string
--- @param buildingId string
function ConstructionVisualizer:SetCompleted(kingdomId: string, buildingId: string)
    local kingdomVisuals: { [string]: Model }? = self._buildingVisuals[kingdomId]
    if not kingdomVisuals then
        return
    end

    local model: Model? = kingdomVisuals[buildingId]
    if not model then
        return
    end

    self:_setModelTransparency(model, 0)
    model:SetAttribute("ConstructionState", nil)

    local scaffold: Model? = self:_findScaffold(model)
    if scaffold then
        scaffold:Destroy()
    end
end

--- Retorna o Model visual de um edificio.
--- @param kingdomId string
--- @param buildingId string
--- @return Model?
function ConstructionVisualizer:GetVisual(kingdomId: string, buildingId: string): Model?
    local kingdomVisuals: { [string]: Model }? = self._buildingVisuals[kingdomId]
    if not kingdomVisuals then
        return nil
    end
    return kingdomVisuals[buildingId]
end

return ConstructionVisualizer
