local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GridMath = require(ReplicatedStorage.Shared.Grid.GridMath)

export type PreviewRenderer = {
    _preview: Part?,
    _valid: boolean,
    _currentFW: number,
    _currentFZ: number,
    _cellSize: number,
}

local PreviewRenderer: PreviewRenderer = {}
PreviewRenderer.__index = PreviewRenderer

function PreviewRenderer.new(): PreviewRenderer
    return setmetatable({
        _preview = nil,
        _valid = false,
        _currentFW = 0,
        _currentFZ = 0,
        _cellSize = 4,
    }, PreviewRenderer)
end

--- Cria o preview com as dimensoes do footprint.
--- @param width number — largura em celulas (pre-rotacao)
--- @param depth number — profundidade em celulas (pre-rotacao)
--- @param rotation number — 0, 90, 180, 270
--- @param cellSize number?
function PreviewRenderer:Create(width: number, depth: number, rotation: number, cellSize: number?)
    self:Destroy()

    local cs: number = cellSize or 4
    self._cellSize = cs
    local fw: number
    local fz: number
    fw, fz = GridMath.RotateFootprint(width, depth, rotation)
    self._currentFW = fw
    self._currentFZ = fz

    local size: Vector3 = GridMath.GetFootprintSize(width, depth, rotation, cs)

    local part: Part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Size = size
    part.Transparency = 0.65
    part.Material = Enum.Material.ForceField
    part.Color = Color3.fromRGB(0, 255, 0)
    part.Name = "PlacementPreview"
    part.Parent = workspace

    self._preview = part
    self._valid = true
end

--- Altera a rotacao do preview.
--- Só recria a Part se as dimensoes mudarem (ex: 0→90).
--- Se dimensoes forem iguais (ex: 0→180), apenas atualiza internamente.
--- @param width number — largura original em celulas
--- @param depth number — profundidade original em celulas
--- @param rotation number — 0, 90, 180, 270
function PreviewRenderer:SetRotation(width: number, depth: number, rotation: number)
    local fw: number
    local fz: number
    fw, fz = GridMath.RotateFootprint(width, depth, rotation)

    if fw ~= self._currentFW or fz ~= self._currentFZ then
        local cs: number = self._cellSize
        local size: Vector3 = GridMath.GetFootprintSize(width, depth, rotation, cs)
        if not self._preview then
            self:Create(width, depth, rotation, cs)
            return
        end
        self._preview.Size = size
        self._currentFW = fw
        self._currentFZ = fz
    end
end

function PreviewRenderer:UpdatePosition(cframe: CFrame)
    if not self._preview then
        return
    end
    self._preview.CFrame = cframe
end

function PreviewRenderer:SetValid(valid: boolean)
    if not self._preview then
        return
    end
    self._valid = valid
    self._preview.Color = valid and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
end

function PreviewRenderer:IsValid(): boolean
    return self._valid
end

function PreviewRenderer:Destroy()
    if self._preview then
        self._preview:Destroy()
        self._preview = nil
    end
end

return PreviewRenderer
