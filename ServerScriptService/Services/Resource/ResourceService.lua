--[[
    ResourceService

    Sistema dono do dominio de recursos do Kingdom.
    UNICA forma oficial de ler ou modificar resources.
    Nenhum outro sistema toca kingdom.resources diretamente.

    Fluxo:
    1. Valida operacao (Kingdom existe? Ready? quantia valida? saldo suficiente?)
    2. Delegua alteracao ao KingdomService:ApplyResourceChanges
    3. Dispara ResourceChanged via EventBus

    SetAmount() e uso INTERNO (save restore, migracao, admin).
    Gameplay deve usar: Add, Remove, TrySpend.
]]

local ResourceTypes = require(game:GetService("ReplicatedStorage").Shared.Types.ResourceTypes)
local ResourceType = require(game:GetService("ReplicatedStorage").Shared.Enums.ResourceType)

-- Reverse lookup O(1) para validacao de resourceType
local VALID_RESOURCE_TYPES: { [number]: boolean } = {}
for _: string, value: any in ResourceType do
    if type(value) == "number" then
        VALID_RESOURCE_TYPES[value] = true
    end
end

export type ResourceService = {
    _serviceLocator: any,
    _logger: any,
    _eventBus: any,
    _kingdomService: any,
}

local ResourceService: ResourceService = {}
ResourceService.__index = ResourceService

function ResourceService.new(serviceLocator: any): ResourceService
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = serviceLocator:get("Logger"),
        _eventBus = serviceLocator:get("EventBus"),
        _kingdomService = serviceLocator:get("Kingdom"),
    }, ResourceService)
end

function ResourceService:init()
    self._logger:info("ResourceService initialized")
end

function ResourceService:start()
    self._logger:info("ResourceService started")
end

-- Valida se o resourceType e um membro valido do enum (O(1))
function ResourceService:_isValidResourceType(resourceType: number): boolean
    return VALID_RESOURCE_TYPES[resourceType] or false
end

-- Monta e dispara evento ResourceChanged
function ResourceService:_fireEvent(kingdomId: string, reason: string, changes: { ResourceTypes.ResourceChange })
    local eventData: ResourceTypes.ResourceChangedEvent = {
        kingdomId = kingdomId,
        reason = reason,
        timestamp = os.time(),
        changes = changes,
        triggeredBy = "ResourceService",
    }
    self._eventBus:fire("ResourceChanged", eventData)
end

-- Cria entrada de change para o evento
function ResourceService:_makeChange(resourceType: number, oldValue: number, newValue: number): ResourceTypes.ResourceChange
    return {
        resourceType = resourceType,
        oldValue = oldValue,
        newValue = newValue,
    }
end

-- Valida se Kingdom existe, esta Ready, e resourceType e valido
-- Retorna (kingdom, sucesso)
function ResourceService:_validateKingdom(kingdomId: string): (any, boolean)
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        self._logger:warn(string.format("Resource operation failed: kingdom not found %s", kingdomId))
        return nil, false
    end
    if kingdom.state ~= "Ready" then
        self._logger:warn(string.format("Resource operation failed: kingdom %s is %s", kingdomId, kingdom.state))
        return nil, false
    end
    return kingdom, true
end

--[[
    APIs Publicas
]]

--- Retorna saldo atual de um recurso (leitura).
--- @return number? — nil se Kingdom inexistente
function ResourceService:GetAmount(kingdomId: string, resourceType: number): number?
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return nil
    end
    return kingdom.resources[resourceType] or 0
end

--- Adiciona recursos a um Kingdom.
--- @param reason string — contexto da operacao (ex: "quest_reward")
function ResourceService:Add(kingdomId: string, resourceType: number, amount: number, reason: string): boolean
    local kingdom: any, ok: boolean = self:_validateKingdom(kingdomId)
    if not ok then
        return false
    end

    if not self:_isValidResourceType(resourceType) then
        self._logger:warn(string.format("Add failed: invalid resource type %d", resourceType))
        return false
    end

    if amount <= 0 then
        self._logger:warn("Add failed: amount must be positive")
        return false
    end

    local oldValue: number = kingdom.resources[resourceType] or 0
    local newValue: number = oldValue + amount

    local applied: boolean = self._kingdomService:ApplyResourceChanges(kingdomId, { [resourceType] = amount })
    if not applied then
        return false
    end

    self:_fireEvent(kingdomId, reason, {
        self:_makeChange(resourceType, oldValue, newValue),
    })

    self._logger:info(string.format("Add %d x %s to %s (%s)", amount, tostring(resourceType), kingdomId, reason))
    return true
end

--- Remove recursos de um Kingdom.
--- Valida saldo suficiente antes de alterar.
function ResourceService:Remove(kingdomId: string, resourceType: number, amount: number, reason: string): boolean
    local kingdom: any, ok: boolean = self:_validateKingdom(kingdomId)
    if not ok then
        return false
    end

    if not self:_isValidResourceType(resourceType) then
        self._logger:warn(string.format("Remove failed: invalid resource type %d", resourceType))
        return false
    end

    if amount <= 0 then
        self._logger:warn("Remove failed: amount must be positive")
        return false
    end

    local oldValue: number = kingdom.resources[resourceType] or 0
    if oldValue < amount then
        self._logger:warn(string.format("Remove failed: insufficient %d (have %d, need %d)", resourceType, oldValue, amount))
        return false
    end

    local newValue: number = oldValue - amount

    local applied: boolean = self._kingdomService:ApplyResourceChanges(kingdomId, { [resourceType] = -amount })
    if not applied then
        return false
    end

    self:_fireEvent(kingdomId, reason, {
        self:_makeChange(resourceType, oldValue, newValue),
    })

    self._logger:info(string.format("Remove %d x %s from %s (%s)", amount, tostring(resourceType), kingdomId, reason))
    return true
end

--- Valida E desconta recursos atomicamente.
--- Se QUALQUER recurso do custo for insuficiente, nada e alterado.
--- @param cost ResourceTypes.CostTable — ex: { [ResourceType.Gold] = 100, [ResourceType.Wood] = 50 }
function ResourceService:TrySpend(kingdomId: string, cost: ResourceTypes.CostTable, reason: string): boolean
    local kingdom: any, ok: boolean = self:_validateKingdom(kingdomId)
    if not ok then
        return false
    end

    -- Fase 1: Validar todo o custo
    local changes: { ResourceTypes.ResourceChange } = {}
    local deltas: { [number]: number } = {}

    for resourceType: number, amount: number in cost do
        if amount <= 0 then
            self._logger:warn("TrySpend failed: cost entry must be positive")
            return false
        end

        local oldValue: number = kingdom.resources[resourceType] or 0
        if oldValue < amount then
            self._logger:warn(
                string.format("TrySpend failed: insufficient %d (have %d, need %d)", resourceType, oldValue, amount)
            )
            return false
        end

        table.insert(changes, self:_makeChange(resourceType, oldValue, oldValue - amount))
        deltas[resourceType] = -amount
    end

    -- Fase 2: Aplicar (so chega aqui se todas as validacoes passaram)
    local applied: boolean = self._kingdomService:ApplyResourceChanges(kingdomId, deltas)
    if not applied then
        return false
    end

    -- Fase 3: Evento unico com todas as mudancas
    self:_fireEvent(kingdomId, reason, changes)

    self._logger:info(string.format("TrySpend %s (%s)", kingdomId, reason))
    return true
end

--- Verifica se Kingdom possui pelo menos `amount` de um recurso.
function ResourceService:Has(kingdomId: string, resourceType: number, amount: number): boolean
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        self._logger:warn("Has failed: kingdom not found", kingdomId)
        return false
    end

    if amount <= 0 then
        return true
    end

    local current: number = kingdom.resources[resourceType] or 0
    return current >= amount
end

--- Verifica se Kingdom possui todos os recursos de um custo.
function ResourceService:CanAfford(kingdomId: string, cost: ResourceTypes.CostTable): boolean
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        self._logger:warn("CanAfford failed: kingdom not found", kingdomId)
        return false
    end

    for resourceType: number, amount: number in cost do
        if amount <= 0 then
            return false
        end
        local current: number = kingdom.resources[resourceType] or 0
        if current < amount then
            return false
        end
    end

    return true
end

--- Retorna copia de todos os recursos de um Kingdom.
--- @return ResourceTypes.Resources? — nil se Kingdom inexistente
function ResourceService:GetAll(kingdomId: string): ResourceTypes.Resources?
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return nil
    end
    return table.clone(kingdom.resources)
end

--[[
    API Interna / Admin
]]

--- Define valor absoluto de um recurso.
--- USO INTERNO: save restore, migracao de dados, comandos admin.
--- Nao valida saldo — pode zerar ou definir qualquer valor >= 0.
function ResourceService:SetAmount(kingdomId: string, resourceType: number, amount: number, reason: string): boolean
    local kingdom: any, ok: boolean = self:_validateKingdom(kingdomId)
    if not ok then
        return false
    end

    if not self:_isValidResourceType(resourceType) then
        self._logger:warn(string.format("SetAmount failed: invalid resource type %d", resourceType))
        return false
    end

    if amount < 0 then
        self._logger:warn("SetAmount failed: amount cannot be negative")
        return false
    end

    local oldValue: number = kingdom.resources[resourceType] or 0
    local delta: number = amount - oldValue

    local applied: boolean = self._kingdomService:ApplyResourceChanges(kingdomId, { [resourceType] = delta })
    if not applied then
        return false
    end

    self:_fireEvent(kingdomId, reason, {
        self:_makeChange(resourceType, oldValue, amount),
    })

    self._logger:info(string.format("SetAmount %s to %d in %s (%s)", tostring(resourceType), amount, kingdomId, reason))
    return true
end

return ResourceService
