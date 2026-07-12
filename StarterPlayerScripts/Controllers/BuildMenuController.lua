local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingRegistryModule = require(ReplicatedStorage.Shared.Buildings.BuildingRegistry)
local ResourceType = require(ReplicatedStorage.Shared.Enums.ResourceType)
local PlacementController = require(script.Parent.PlacementController)
local BuildMenuView = require(script.Parent.Parent.UI.BuildMenuView)

export type BuildMenuController = {
    _view: any,
    _placementController: any,
    _connections: { RBXScriptConnection },
}

local BuildMenuController: BuildMenuController = {}
BuildMenuController.__index = BuildMenuController

function BuildMenuController.new(): BuildMenuController
    local self: BuildMenuController = setmetatable({
        _view = BuildMenuView.new(),
        _placementController = nil,
        _connections = {},
    }, BuildMenuController)
    self:_connectInput()
    return self
end

function BuildMenuController:_connectInput()
    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
        if gameProcessed then
            return
        end
        if input.KeyCode == Enum.KeyCode.B then
            self:Toggle()
        end
    end))
end

function BuildMenuController:Toggle()
    if self._view:IsVisible() then
        self._view:Hide()
        return
    end

    if self._placementController and self._placementController:IsActive() then
        return
    end

    local registry = BuildingRegistryModule.new()
    local allDefs = registry:GetAll()
    local defList = {}
    for _, def: any in pairs(allDefs) do
        local costText = ""
        if def.buildCost then
            local parts = {}
            for rt: number, amount: number in pairs(def.buildCost) do
                local name = ResourceType.toString(rt)
                table.insert(parts, name .. " " .. tostring(amount))
            end
            costText = table.concat(parts, "  ")
        end
        if costText == "" then
            costText = "Free"
        end
        table.insert(defList, {
            id = def.id,
            displayName = def.displayName,
            costText = costText,
            footprint = def.footprint or { width = 1, depth = 1 },
        })
    end
    table.sort(defList, function(a, b)
        return a.displayName < b.displayName
    end)

    self._view:Show({
        definitions = defList,
        onBuildingSelected = function(id: string)
            self:_onBuildingSelected(id)
        end,
    })
end

function BuildMenuController:_onBuildingSelected(id: string)
    self._view:Hide()
    if id == "__close__" then
        return
    end
    if not self._placementController then
        self._placementController = PlacementController.new()
    end
    self._placementController:StartPlacement(id)
end

function BuildMenuController:Destroy()
    self._view:Hide()
    for _, conn: RBXScriptConnection in ipairs(self._connections) do
        conn:Disconnect()
    end
    self._connections = {}
end

return BuildMenuController
