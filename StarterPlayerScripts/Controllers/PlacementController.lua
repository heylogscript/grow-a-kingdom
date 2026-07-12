local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingRegistryModule = require(ReplicatedStorage.Shared.Buildings.BuildingRegistry)
local GridMath = require(ReplicatedStorage.Shared.Grid.GridMath)
local PreviewRenderer = require(script.Parent.Parent.Preview.PreviewRenderer)
local PlaceBuildingRemote = require(ReplicatedStorage.Shared.Remotes.PlaceBuilding)

export type PlacementController = {
    _active: boolean,
    _definitionId: string?,
    _rotation: number,
    _gridPos: GridMath.GridPosition?,
    _renderer: any,
    _connections: { RBXScriptConnection },
    _localPlayer: Player,
    _buildingRegistry: any,
    _remoteFunction: RemoteFunction,
    _placing: boolean,
}

local PlacementController: PlacementController = {}
PlacementController.__index = PlacementController

function PlacementController.new(): PlacementController
    return setmetatable({
        _active = false,
        _definitionId = nil,
        _rotation = 0,
        _gridPos = nil,
        _renderer = nil,
        _connections = {},
        _localPlayer = Players.LocalPlayer,
        _buildingRegistry = BuildingRegistryModule.new(),
        _remoteFunction = PlaceBuildingRemote,
        _placing = false,
    }, PlacementController)
end

--- Inicia modo de posicionamento.
--- Obtem o footprint automaticamente do BuildingRegistry.
--- @param definitionId string — id da definicao (ex: "farm")
function PlacementController:StartPlacement(definitionId: string)
    if self._active then
        self:Cancel()
    end

    local definition: any = self._buildingRegistry:GetById(definitionId)
    if not definition then
        return
    end

    local footprint: any = definition.footprint
    local w: number = footprint and footprint.width or 1
    local d: number = footprint and footprint.depth or 1

    self._active = true
    self._definitionId = definitionId
    self._rotation = 0
    self._gridPos = nil

    self._renderer = PreviewRenderer.new()
    self._renderer:Create(w, d, 0)

    self:_connectInput()
    self:_updateFromMouse()
end

function PlacementController:Cancel()
    if self._renderer then
        self._renderer:Destroy()
        self._renderer = nil
    end
    self:_disconnectAll()
    self._active = false
    self._definitionId = nil
end

--- Retorna dados para construcao.
--- @return string?, number, number, number
function PlacementController:GetPlacementData(): (string?, number, number, number)
    if not self._active or not self._gridPos or not self._renderer or not self._renderer:IsValid() then
        return nil, 0, 0, 0
    end
    return self._definitionId, self._gridPos.x, self._gridPos.z, self._rotation
end

function PlacementController:IsActive(): boolean
    return self._active
end

function PlacementController:GetRotation(): number
    return self._rotation
end

--- Envia pedido de posicionamento ao servidor.
--- Se aprovado, sai do modo de posicionamento.
--- @return (boolean, string?)
function PlacementController:TryPlace(): (boolean, string?)
    if not self._active then
        return false, "Not in placement mode"
    end
    local definitionId: string?, x: number, z: number, rotation: number = self:GetPlacementData()
    if not definitionId then
        return false, "Invalid placement position"
    end
    local success: boolean
    local reason: string?
    success, reason = self._remoteFunction:InvokeServer(definitionId, x, z, rotation)
    if success then
        self:Cancel()
        return true, nil
    end
    return false, reason
end

-- Input

function PlacementController:_connectInput()
    local mouse: Mouse = self._localPlayer:GetMouse()

    table.insert(self._connections, mouse.Move:Connect(function()
        self:_updateFromMouse()
    end))

    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then
            return
        end
        if input.KeyCode == Enum.KeyCode.R then
            self:_rotate()
        elseif input.KeyCode == Enum.KeyCode.Escape then
            self:Cancel()
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 and self._active and not self._placing then
            self._placing = true
            local ok: boolean, err: string? = self:TryPlace()
            self._placing = false
            if not ok and err then
                self._renderer:SetValid(false)
                task.delay(0.15, function()
                    if self._renderer and self._renderer.IsValid and self._renderer:IsValid() then
                        self._renderer:SetValid(true)
                    end
                end)
            end
        end
    end))
end

function PlacementController:_disconnectAll()
    for _, conn: RBXScriptConnection in ipairs(self._connections) do
        conn:Disconnect()
    end
    self._connections = {}
end

-- Update

function PlacementController:_getDefinition(): any?
    if not self._definitionId then
        return nil
    end
    return self._buildingRegistry:GetById(self._definitionId)
end

function PlacementController:_updateFromMouse()
    if not self._active or not self._renderer then
        return
    end

    local definition: any = self:_getDefinition()
    if not definition then
        return
    end
    local footprint: any = definition.footprint
    local w: number = footprint and footprint.width or 1
    local d: number = footprint and footprint.depth or 1

    local mouse: Mouse = self._localPlayer:GetMouse()
    local origin: Vector3 = mouse.UnitRay.Origin
    local direction: Vector3 = mouse.UnitRay.Direction * 500

    local params: RaycastParams = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist

    local character: Model? = self._localPlayer.Character
    if character then
        params.FilterDescendantsInstances = { character }
    end

    local result: RaycastResult? = workspace:Raycast(origin, direction, params)
    if not result then
        self._renderer:SetValid(false)
        return
    end

    local hitPos: Vector3 = result.Position
    self._gridPos = GridMath.WorldToGrid(hitPos)

    local cframe: CFrame = GridMath.GetFootprintCFrame(self._gridPos, w, d, self._rotation, nil, hitPos.Y)
    self._renderer:UpdatePosition(cframe)

    self._renderer:SetValid(true)
end

function PlacementController:_rotate()
    if not self._active or not self._renderer then
        return
    end
    self._rotation = (self._rotation + 90) % 360

    local definition: any = self:_getDefinition()
    if not definition then
        return
    end
    local footprint: any = definition.footprint
    local w: number = footprint and footprint.width or 1
    local d: number = footprint and footprint.depth or 1

    self._renderer:SetRotation(w, d, self._rotation)

    if self._gridPos then
        local cframe: CFrame = GridMath.GetFootprintCFrame(self._gridPos, w, d, self._rotation, nil, 0)
        self._renderer:UpdatePosition(cframe)
    end
end

return PlacementController
