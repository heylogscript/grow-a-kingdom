--[[
    BuildingRegistry

    Responsabilidades:
    1. Orquestrar Loader → Validator → Registro
    2. Manter indices congelados de definicoes validas
    3. Fornecer APIs de consulta O(1)

    O registro e TOTALMENTE IMUTAVEL apos inicializacao.
    Qualquer tentativa de modificar os indices em runtime
    resulta em erro.
]]

local BuildingLoader = require(script.Parent.BuildingLoader)
local BuildingValidator = require(script.Parent.BuildingValidator)

export type BuildingRegistry = {
    _byId: { [string]: any },
    _byCategory: { [number]: { [string]: any } },
    _byTag: { [string]: { [string]: any } },
}

local BuildingRegistry: BuildingRegistry = {}
BuildingRegistry.__index = BuildingRegistry

local function freezeTable(t: { [any]: any }): { [any]: any }
    return setmetatable({}, {
        __index = t,
        __newindex = function()
            error("BuildingRegistry is frozen: cannot modify after initialization", 2)
        end,
        __pairs = function()
            return pairs(t)
        end,
    })
end

function BuildingRegistry.new(): BuildingRegistry
    -- Fase 1: Carregar
    local rawDefinitions: { any } = BuildingLoader.loadAll()

    -- Fase 2: Validar
    local valid: boolean, errors: { string } = BuildingValidator.validateAll(rawDefinitions)
    if not valid then
        local message: string = "BuildingRegistry validation failed:\n"
        for _, err: string in ipairs(errors) do
            message ..= "- " .. err .. "\n"
        end
        error(message, 0)
    end

    -- Fase 3: Indexar
    local byId: { [string]: any } = {}
    local byCategory: { [number]: { [string]: any } } = {}
    local byTag: { [string]: { [string]: any } } = {}

    for _, def: any in ipairs(rawDefinitions) do
        byId[def.id] = def

        -- Indice por categoria
        local cat: number = def.category
        if not byCategory[cat] then
            byCategory[cat] = {}
        end
        byCategory[cat][def.id] = def

        -- Indice por tag
        if def.tags then
            for tag: string in def.tags do
                if not byTag[tag] then
                    byTag[tag] = {}
                end
                byTag[tag][def.id] = def
            end
        end
    end

    -- Fase 4: Congelar
    local self_: BuildingRegistry = {
        _byId = freezeTable(byId),
        _byCategory = freezeTable(byCategory),
        _byTag = freezeTable(byTag),
    }

    setmetatable(self_, {
        __index = BuildingRegistry,
        __newindex = function(_, key: string)
            error(string.format("BuildingRegistry is frozen: cannot set field '%s'", key), 2)
        end,
    })

    return self_
end

--- Lookup por id (O(1)).
function BuildingRegistry:GetById(id: string): any?
    return self._byId[id]
end

--- Todos os edificios de uma categoria (O(1)).
function BuildingRegistry:GetByCategory(category: number): { [string]: any }
    return self._byCategory[category] or {}
end

--- Todos os edificios com uma tag (O(1)).
function BuildingRegistry:GetByTag(tag: string): { [string]: any }
    return self._byTag[tag] or {}
end

--- Retorna lookup completo de todos os edificios (imutavel).
function BuildingRegistry:GetAll(): { [string]: any }
    return self._byId
end

--- Quantidade de definicoes registradas.
function BuildingRegistry:Count(): number
    local count: number = 0
    for _: string in pairs(self._byId) do
        count += 1
    end
    return count
end

return BuildingRegistry
