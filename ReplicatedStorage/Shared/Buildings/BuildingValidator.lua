--[[
    BuildingValidator

    Responsabilidade unica: validar todos os BuildingDefinitions
    contra as regras do schema ANTES de serem registrados.

    Se QUALQUER definicao falhar em QUALQUER regra,
    o registro inteiro e rejeitado e os erros sao retornados.

    Regras:
    1. schemaVersion obrigatorio e >= 1
    2. id unico entre todas as definicoes
    3. id valido (nao vazio, sem espacos)
    4. id nao reservado
    5. category e membro valido do enum
    6. footprint valido (width > 0, depth > 0)
    7. buildCost: keys sao ResourceType validos, values > 0
    8. buildTime > 0
    9. unlockRequirements validos (se presente)
    10. modelId nao vazio
    11. displayName nao vazio
    12. production valido (se presente)
]]

local ResourceType = require(script.Parent.Parent.Enums.ResourceType)
local TechnologyId = require(script.Parent.Parent.Enums.TechnologyId)
local BuildingCategories = require(script.Parent.BuildingCategories)

local BuildingValidator = {}

-- Coletores de valores validos dos enums para comparacao O(1)
local function buildEnumValues(enumTable: { [string]: any }): { [any]: boolean }
    local values: { [any]: boolean } = {}
    for _: string, value: any in enumTable do
        if type(value) == "number" then
            values[value] = true
        end
    end
    return values
end

local VALID_RESOURCES: { [number]: boolean } = buildEnumValues(ResourceType)
local VALID_TECHNOLOGIES: { [number]: boolean } = buildEnumValues(TechnologyId)
local VALID_CATEGORIES: { [number]: boolean } = buildEnumValues(BuildingCategories)

local RESERVED_IDS: { [string]: boolean } = {
    all = true, none = true, new = true, delete = true,
    edit = true, copy = true, paste = true, default = true,
    empty = true, unknown = true, null = true, ["nil"] = true,
}

local function validateId(id: any, errors: { string }): boolean
    if type(id) ~= "string" then
        table.insert(errors, "id must be a string")
        return false
    end
    if #id == 0 then
        table.insert(errors, "id cannot be empty")
        return false
    end
    if id:match("%s") then
        table.insert(errors, string.format("id '%s' contains spaces", id))
        return false
    end
    if RESERVED_IDS[id] then
        table.insert(errors, string.format("id '%s' is reserved", id))
        return false
    end
    return true
end

local function validateSchemaVersion(def: any, errors: { string }): boolean
    if def.schemaVersion == nil then
        table.insert(errors, string.format("'%s': schemaVersion is required", def.id or "unknown"))
        return false
    end
    if type(def.schemaVersion) ~= "number" or def.schemaVersion < 1 then
        table.insert(errors, string.format("'%s': schemaVersion must be >= 1", def.id or "unknown"))
        return false
    end
    return true
end

local function validateCategory(def: any, errors: { string }): boolean
    if def.category == nil then
        table.insert(errors, string.format("'%s': category is required", def.id))
        return false
    end
    if not VALID_CATEGORIES[def.category] then
        table.insert(errors, string.format("'%s': invalid category %s", def.id, tostring(def.category)))
        return false
    end
    return true
end

local function validateFootprint(def: any, errors: { string }): boolean
    if type(def.footprint) ~= "table" then
        table.insert(errors, string.format("'%s': footprint is required", def.id))
        return false
    end
    if type(def.footprint.width) ~= "number" or def.footprint.width <= 0 then
        table.insert(errors, string.format("'%s': footprint.width must be > 0", def.id))
        return false
    end
    if type(def.footprint.depth) ~= "number" or def.footprint.depth <= 0 then
        table.insert(errors, string.format("'%s': footprint.depth must be > 0", def.id))
        return false
    end
    return true
end

local function validateBuildCost(def: any, errors: { string }): boolean
    if type(def.buildCost) ~= "table" then
        table.insert(errors, string.format("'%s': buildCost is required", def.id))
        return false
    end
    for resourceType: any, amount: any in def.buildCost do
        if not VALID_RESOURCES[resourceType] then
            table.insert(errors, string.format("'%s': buildCost invalid resource type %s", def.id, tostring(resourceType)))
            return false
        end
        if type(amount) ~= "number" or amount <= 0 then
            table.insert(errors, string.format("'%s': buildCost amount must be > 0", def.id))
            return false
        end
    end
    return true
end

local function validateBuildTime(def: any, errors: { string }): boolean
    if type(def.buildTime) ~= "number" or def.buildTime <= 0 then
        table.insert(errors, string.format("'%s': buildTime must be > 0", def.id))
        return false
    end
    return true
end

local function validateUnlockRequirements(def: any, errors: { string }): boolean
    local req: any = def.unlockRequirements
    if req == nil then
        return true
    end
    if type(req) ~= "table" then
        table.insert(errors, string.format("'%s': unlockRequirements must be a table", def.id))
        return false
    end
    if req.level ~= nil and (type(req.level) ~= "number" or req.level < 1) then
        table.insert(errors, string.format("'%s': unlockRequirements.level must be >= 1", def.id))
        return false
    end
    if req.technology ~= nil and not VALID_TECHNOLOGIES[req.technology] then
        table.insert(errors, string.format("'%s': unlockRequirements.technology is invalid", def.id))
        return false
    end
    if req.buildings ~= nil then
        if type(req.buildings) ~= "table" then
            table.insert(errors, string.format("'%s': unlockRequirements.buildings must be a table", def.id))
            return false
        end
        for buildingId: any, count: any in req.buildings do
            if type(buildingId) ~= "string" then
                table.insert(errors, string.format("'%s': unlockRequirements.buildings key must be string", def.id))
                return false
            end
            if type(count) ~= "number" or count <= 0 then
                table.insert(errors, string.format("'%s': unlockRequirements.buildings count must be > 0", def.id))
                return false
            end
        end
    end
    return true
end

local function validateProduction(def: any, errors: { string }): boolean
    local prod: any = def.production
    if prod == nil then
        return true
    end
    if type(prod) ~= "table" then
        table.insert(errors, string.format("'%s': production must be a table", def.id))
        return false
    end
    if type(prod.outputs) ~= "table" then
        table.insert(errors, string.format("'%s': production.outputs is required", def.id))
        return false
    end
    for resourceType: any, amount: any in prod.outputs do
        if not VALID_RESOURCES[resourceType] then
            table.insert(errors, string.format("'%s': production.outputs invalid resource type %s", def.id, tostring(resourceType)))
            return false
        end
        if type(amount) ~= "number" or amount <= 0 then
            table.insert(errors, string.format("'%s': production.outputs amount must be > 0", def.id))
            return false
        end
    end
    if type(prod.interval) ~= "number" or prod.interval <= 0 then
        table.insert(errors, string.format("'%s': production.interval must be > 0", def.id))
        return false
    end
    if prod.requiresWorker ~= nil and type(prod.requiresWorker) ~= "boolean" then
        table.insert(errors, string.format("'%s': production.requiresWorker must be boolean", def.id))
        return false
    end
    if prod.startsPaused ~= nil and type(prod.startsPaused) ~= "boolean" then
        table.insert(errors, string.format("'%s': production.startsPaused must be boolean", def.id))
        return false
    end
    return true
end

local function validateStorage(def: any, errors: { string }): boolean
    local storage: any = def.storage
    if storage == nil then
        return true
    end
    if type(storage) ~= "table" then
        table.insert(errors, string.format("'%s': storage must be a table", def.id))
        return false
    end
    for resourceType: any, amount: any in storage do
        if not VALID_RESOURCES[resourceType] then
            table.insert(errors, string.format("'%s': storage invalid resource type %s", def.id, tostring(resourceType)))
            return false
        end
        if type(amount) ~= "number" or amount <= 0 then
            table.insert(errors, string.format("'%s': storage amount must be > 0", def.id))
            return false
        end
    end
    return true
end

local function validateTags(def: any, errors: { string }): boolean
    local tags: any = def.tags
    if tags == nil then
        return true
    end
    if type(tags) ~= "table" then
        table.insert(errors, string.format("'%s': tags must be a table", def.id))
        return false
    end
    for key: any, value: any in tags do
        if type(key) ~= "string" then
            table.insert(errors, string.format("'%s': tags key must be string, got %s", def.id, type(key)))
            return false
        end
        if value ~= true then
            table.insert(errors, string.format("'%s': tags value must be true (set format)", def.id))
            return false
        end
    end
    return true
end

local function validateStrings(def: any, errors: { string }): boolean
    if type(def.displayName) ~= "string" or #def.displayName == 0 then
        table.insert(errors, string.format("'%s': displayName is required", def.id or "unknown"))
        return false
    end
    if type(def.modelId) ~= "string" or #def.modelId == 0 then
        table.insert(errors, string.format("'%s': modelId is required", def.id))
        return false
    end
    return true
end

--- Valida todas as definicoes.
--- @param definitions {any} — lista crua de BuildingDefinitions do Loader
--- @return boolean, {string} — (aprovado, lista_de_erros)
function BuildingValidator.validateAll(definitions: { any }): (boolean, { string })
    local errors: { string } = {}
    local seenIds: { [string]: boolean } = {}

    for index: number, def: any in ipairs(definitions) do
        if type(def) ~= "table" then
            table.insert(errors, string.format("Entry %d: definition must be a table, got %s", index, type(def)))
            continue
        end

        -- Validar id primeiro (precisamos do id para mensagens de erro)
        if type(def.id) ~= "string" or #def.id == 0 then
            table.insert(errors, string.format("Entry %d: invalid or missing id", index))
            continue
        end

        -- id unico
        if seenIds[def.id] then
            table.insert(errors, string.format("Duplicate id '%s'", def.id))
            continue
        end
        seenIds[def.id] = true

        validateId(def.id, errors)
        validateSchemaVersion(def, errors)
        validateCategory(def, errors)
        validateFootprint(def, errors)
        validateBuildCost(def, errors)
        validateBuildTime(def, errors)
        validateUnlockRequirements(def, errors)
        validateProduction(def, errors)
        validateStorage(def, errors)
        validateTags(def, errors)
        validateStrings(def, errors)
    end

    if #errors > 0 then
        return false, errors
    end
    return true, {}
end

return BuildingValidator
