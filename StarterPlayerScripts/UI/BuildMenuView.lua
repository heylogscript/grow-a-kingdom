local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

export type BuildMenuView = {
    _gui: ScreenGui?,
}

local BuildMenuView: BuildMenuView = {}
BuildMenuView.__index = BuildMenuView

function BuildMenuView.new(): BuildMenuView
    return setmetatable({ _gui = nil }, BuildMenuView)
end

function BuildMenuView:Show(config: { definitions: { any }, onBuildingSelected: (string) -> () }): boolean
    if self._gui then
        return false
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BuildMenuGui"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.new(0, 0, 0)
    bg.BackgroundTransparency = 0.65
    bg.Parent = gui

    local frame = Instance.new("Frame")
    frame.Name = "MenuFrame"
    frame.Size = UDim2.new(0.5, 0, 0.55, 0)
    frame.Position = UDim2.new(0.25, 0, 0.2, 0)
    frame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.85, 0, 0.1, 0)
    title.Position = UDim2.new(0.075, 0, 0.02, 0)
    title.BackgroundTransparency = 1
    title.Text = "Build Menu"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 22
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0.08, 0, 0.08, 0)
    closeBtn.Position = UDim2.new(0.9, 0, 0.02, 0)
    closeBtn.BackgroundColor3 = Color3.new(0.4, 0.1, 0.1)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = frame
    closeBtn.MouseButton1Click:Connect(function()
        config.onBuildingSelected("__close__")
    end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "BuildingList"
    scroll.Size = UDim2.new(0.9, 0, 0.82, 0)
    scroll.Position = UDim2.new(0.05, 0, 0.14, 0)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0, 0, 0, #config.definitions * 80 + 20)
    scroll.Parent = frame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = scroll

    for _, def: any in ipairs(config.definitions) do
        local btn = Instance.new("TextButton")
        btn.Name = def.id
        btn.Size = UDim2.new(1, -8, 0, 72)
        btn.BackgroundColor3 = Color3.new(0.25, 0.25, 0.3)
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.Parent = scroll

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Size = UDim2.new(0.6, 0, 0.45, 0)
        nameLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = def.displayName
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.TextSize = 18
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = btn

        local costLabel = Instance.new("TextLabel")
        costLabel.Name = "Cost"
        costLabel.Size = UDim2.new(0.5, -10, 0.4, 0)
        costLabel.Position = UDim2.new(0.05, 0, 0.5, 0)
        costLabel.BackgroundTransparency = 1
        costLabel.Text = def.costText
        costLabel.TextXAlignment = Enum.TextXAlignment.Left
        costLabel.TextColor3 = Color3.new(0.8, 0.8, 0.3)
        costLabel.TextSize = 13
        costLabel.Font = Enum.Font.Gotham
        costLabel.Parent = btn

        local sizeLabel = Instance.new("TextLabel")
        sizeLabel.Name = "Size"
        sizeLabel.Size = UDim2.new(0.3, 0, 0.45, 0)
        sizeLabel.Position = UDim2.new(0.65, 0, 0.05, 0)
        sizeLabel.BackgroundTransparency = 1
        sizeLabel.Text = string.format("%dx%d", def.footprint.width, def.footprint.depth)
        sizeLabel.TextXAlignment = Enum.TextXAlignment.Right
        sizeLabel.TextColor3 = Color3.new(0.6, 0.6, 0.7)
        sizeLabel.TextSize = 14
        sizeLabel.Font = Enum.Font.Gotham
        sizeLabel.Parent = btn

        btn.MouseButton1Click:Connect(function()
            config.onBuildingSelected(def.id)
        end)
    end

    self._gui = gui
    return true
end

function BuildMenuView:Hide()
    if self._gui then
        self._gui:Destroy()
        self._gui = nil
    end
end

function BuildMenuView:IsVisible(): boolean
    return self._gui ~= nil
end

return BuildMenuView
