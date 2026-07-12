--[[
    AssetRegistry

    Service responsavel por gerenciar os assets 3D do jogo.
    Mapeia modelId (ex: "farm_1", "house_1") para instancias
    de Model armazenadas em ReplicatedStorage.Assets.Buildings.

    Responsabilidades:
    1. Escanear a pasta de assets na inicializacao
    2. Indexar modelos por modelId
    3. Fornecer lookups por modelId e definitionId
    4. Clonar modelos para instanciacao em Workspace
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ASSETS_FOLDER = ReplicatedStorage:FindFirstChild("Assets")
local BUILDINGS_FOLDER = ASSETS_FOLDER and ASSETS_FOLDER:FindFirstChild("Buildings")

export type AssetRegistry = {
    _serviceLocator: any,
    _logger: any,
    _buildingRegistry: any,
    _byModelId: { [string]: Model },
    _byDefinitionId: { [string]: string },
}

local AssetRegistry: AssetRegistry = {}
AssetRegistry.__index = AssetRegistry

function AssetRegistry.new(serviceLocator: any): AssetRegistry
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = serviceLocator:get("Logger"),
        _buildingRegistry = nil,
        _byModelId = {},
        _byDefinitionId = {},
    }, AssetRegistry)
end

function AssetRegistry:init()
    self._buildingRegistry = self._serviceLocator:get("BuildingRegistry")
    self:_loadAssets()
    self._logger:info("AssetRegistry initialized")
end

function AssetRegistry:start()
    local count: number = 0
    for _: string in self._byModelId do
        count += 1
    end
    self._logger:info(string.format("AssetRegistry started with %d assets loaded", count))
end

function AssetRegistry:stop()
    self._byModelId = {}
    self._byDefinitionId = {}
    self._logger:info("AssetRegistry stopped")
end

function AssetRegistry:_loadAssets()
    if not BUILDINGS_FOLDER then
        self._logger:warn("AssetRegistry: Assets.Buildings folder not found in ReplicatedStorage")
        return
    end

    for _, child: Instance in ipairs(BUILDINGS_FOLDER:GetChildren()) do
        if child:IsA("Model") then
            local modelId: string = child.Name
            self._byModelId[modelId] = child
        end
    end

    local allDefs = self._buildingRegistry:GetAll()
    for defId: string, def: any in pairs(allDefs) do
        local modelId: string = def.modelId
        if modelId and self._byModelId[modelId] then
            self._byDefinitionId[defId] = modelId
        elseif modelId then
            self._logger:warn(string.format(
                "AssetRegistry: model '%s' not found for definition '%s'", modelId, defId
            ))
        end
    end
end

--- Retorna o Model template associado a um modelId.
--- @param modelId string — ex: "farm_1"
--- @return Model?
function AssetRegistry:GetModel(modelId: string): Model?
    return self._byModelId[modelId]
end

--- Retorna o Model template associado a uma definicao de edificio.
--- @param definitionId string — ex: "farm"
--- @return Model?
function AssetRegistry:GetByDefinitionId(definitionId: string): Model?
    local modelId: string? = self._byDefinitionId[definitionId]
    if not modelId then
        return nil
    end
    return self._byModelId[modelId]
end

--- Clona o Model template para uma nova instancia.
--- @param modelId string — ex: "farm_1"
--- @param parent Instance? — onde parentear (default: nil)
--- @return Model?
function AssetRegistry:Instantiate(modelId: string, parent: Instance?): Model?
    local template: Model? = self._byModelId[modelId]
    if not template then
        return nil
    end
    local clone: Model = template:Clone()
    if parent then
        clone.Parent = parent
    end
    return clone
end

--- Retorna todos os modelos indexados.
--- @return { [string]: Model }
function AssetRegistry:GetAll(): { [string]: Model }
    return self._byModelId
end

--- Retorna o modelId associado a uma definitionId.
--- @param definitionId string
--- @return string?
function AssetRegistry:GetModelId(definitionId: string): string?
    return self._byDefinitionId[definitionId]
end

return AssetRegistry
