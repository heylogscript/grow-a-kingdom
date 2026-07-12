--[[
    KingdomService

    Service central de gerenciamento de reinos.
    Cada jogador possui exatamente um Kingdom.
    Kingdom existe independentemente do Player.
    Todo o estado do jogo pertence ao Kingdom.

    KingdomData e a FONTE UNICA DE VERDADE.
    Nenhum sistema modifica campos de KingdomData diretamente.
    Todas as alteracoes passam por este service.

    Cache:
    - byId: indice primario por kingdomId (O(1))
    - byPlayer: indice secundario por userId (O(1))

    Estados do Kingdom:
    - Loading: dados sendo carregados (proibe saves)
    - Ready: operacional
    - Saving: save em andamento (proibe saves concorrentes)
    - Closing: cleanup em andamento
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KingdomModel = require(ReplicatedStorage.Shared.Models.KingdomModel)
local KingdomTypes = require(ReplicatedStorage.Shared.Types.KingdomTypes)
local ResourceType = require(ReplicatedStorage.Shared.Enums.ResourceType)

export type KingdomService = {
    _serviceLocator: any,
    _logger: any,
    _cache: {
        byId: { [string]: KingdomTypes.KingdomData },
        byPlayer: { [number]: string },
    },
    _count: number,
}

local KingdomService: KingdomService = {}
KingdomService.__index = KingdomService

type KState = KingdomTypes.KingdomState
local VALID_TRANSITIONS: { [KState]: { [KState]: boolean } } = {
    Loading = { Ready = true },
    Ready = { Saving = true, Closing = true },
    Saving = { Ready = true, Closing = true },
    Closing = {},
}

function KingdomService.new(serviceLocator: any): KingdomService
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = serviceLocator:get("Logger"),
        _cache = {
            byId = {},
            byPlayer = {},
        },
        _count = 0,
    }, KingdomService)
end

function KingdomService:init()
    self._logger:info("KingdomService initialized")
end

function KingdomService:start()
    self._logger:info("KingdomService started")
end

function KingdomService:stop()
    self._cache.byId = {}
    self._cache.byPlayer = {}
    self._count = 0
    self._logger:info("KingdomService stopped")
end

--- Cria um novo Kingdom para o jogador.
--- Gera UUID unico, cria KingdomData com valores padrao, adiciona ao cache.
function KingdomService:CreateKingdom(ownerUserId: number, displayName: string): KingdomTypes.KingdomData
    if self:_hasByPlayer(ownerUserId) then
        self._logger:warn("CreateKingdom failed: user already has a kingdom", ownerUserId)
        error("Player already has a kingdom")
    end

    local kingdom: KingdomTypes.KingdomData = KingdomModel.new(ownerUserId, displayName)
    self._cache.byId[kingdom.kingdomId] = kingdom
    self._cache.byPlayer[ownerUserId] = kingdom.kingdomId
    self._count += 1

    self._logger:info(string.format("Kingdom created for user %d: %s", ownerUserId, kingdom.kingdomId))
    return kingdom
end

--- Importa KingdomData salvo no cache do KingdomService.
--- Nao gera novo GUID — usa o existente nos dados.
--- Valida campos obrigatorios antes de importar.
--- Se qualquer campo obrigatorio estiver ausente, retorna nil.
--- Seta estado para Ready.
---
--- @param data any — KingdomData validado pelo MigrationService
--- @return KingdomTypes.KingdomData? — nil se validacao falhar
function KingdomService:ImportKingdom(data: any): KingdomTypes.KingdomData?
    -- Validacao de campos obrigatorios
    if type(data.kingdomId) ~= "string" or #data.kingdomId == 0 then
        self._logger:warn("ImportKingdom failed: invalid kingdomId")
        return nil
    end
    if type(data.ownerUserId) ~= "number" then
        self._logger:warn("ImportKingdom failed: invalid ownerUserId")
        return nil
    end
    if type(data.displayName) ~= "string" or #data.displayName == 0 then
        self._logger:warn("ImportKingdom failed: invalid displayName")
        return nil
    end
    if type(data.level) ~= "number" or data.level < 1 then
        self._logger:warn("ImportKingdom failed: invalid level")
        return nil
    end
    if type(data.schemaVersion) ~= "number" or data.schemaVersion < 1 then
        self._logger:warn("ImportKingdom failed: invalid schemaVersion")
        return nil
    end
    if type(data.resources) ~= "table" then
        self._logger:warn("ImportKingdom failed: invalid resources")
        return nil
    end
    if type(data.buildings) ~= "table" then
        self._logger:warn("ImportKingdom failed: invalid buildings")
        return nil
    end
    if type(data.workers) ~= "table" then
        self._logger:warn("ImportKingdom failed: invalid workers")
        return nil
    end

    -- Preencher defaults para campos opcionais
    data.metadata = data.metadata or {}
    data.statistics = data.statistics or {}
    data.technologies = data.technologies or {}

    -- Garantir que todos os resource types tenham valor
    for _: string, rt: number in ResourceType do
        if type(rt) == "number" and data.resources[rt] == nil then
            data.resources[rt] = 0
        end
    end

    -- Estado inicial: Loading, sera Ready apos importacao completa
    data.state = "Loading"
    data.lastLoadedAt = os.time()
    data.lastSavedAt = data.lastSavedAt or os.time()

    -- Verificar se ja existe no cache (reimport)
    if self._cache.byId[data.kingdomId] then
        self._logger:warn(string.format("ImportKingdom failed: kingdom %s already in cache", data.kingdomId))
        return nil
    end
    if self._cache.byPlayer[data.ownerUserId] then
        self._logger:warn(string.format("ImportKingdom failed: user %d already has a kingdom", data.ownerUserId))
        return nil
    end

    -- Inserir no cache
    self._cache.byId[data.kingdomId] = data
    self._cache.byPlayer[data.ownerUserId] = data.kingdomId
    self._count += 1

    -- Transicionar para Ready
    data.state = "Ready"

    self._logger:info(string.format("Kingdom imported for user %d: %s", data.ownerUserId, data.kingdomId))
    return data
end

--- Remove um Kingdom do cache.
--- Nao toca Workspace (futuro: BuildingManager fara cleanup visual).
function KingdomService:DestroyKingdom(kingdomId: string): boolean
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        self._logger:warn("DestroyKingdom failed: kingdom not found", kingdomId)
        return false
    end

    self:SetState(kingdomId, "Closing")
    self._cache.byPlayer[kingdom.ownerUserId] = nil
    self._cache.byId[kingdomId] = nil
    self._count -= 1

    self._logger:info(string.format("Kingdom destroyed: %s", kingdomId))
    return true
end

--- Busca Kingdom pelo Player.UserId.
--- O(1) via cache secundario.
function KingdomService:GetByPlayer(userId: number): KingdomTypes.KingdomData?
    local kingdomId: string? = self._cache.byPlayer[userId]
    if not kingdomId then
        return nil
    end
    return self._cache.byId[kingdomId]
end

--- Busca Kingdom pelo ID unico.
--- O(1) via cache primario.
function KingdomService:GetById(kingdomId: string): KingdomTypes.KingdomData?
    return self._cache.byId[kingdomId]
end

--- Verifica se jogador possui Kingdom (O(1)).
function KingdomService:HasKingdom(userId: number): boolean
    return self._cache.byPlayer[userId] ~= nil
end

--- Retorna copia superficial de todos os Kingdoms ativos.
--- Uso: admin commands, eventos globais, debug.
function KingdomService:GetAll(): { [string]: KingdomTypes.KingdomData }
    return table.clone(self._cache.byId)
end

--- Quantidade de Kingdoms ativos no servidor (O(1)).
function KingdomService:Count(): number
    return self._count
end

--- Transiciona o estado de um Kingdom.
--- Valida a transicao para prevenir:
--- - Save durante load (dados parciais -> corrupcao)
--- - Saves concorrentes (DataStore conflict)
--- - Operacoes durante closing (cleanup interrompido)
function KingdomService:SetState(kingdomId: string, newState: KingdomTypes.KingdomState): boolean
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        self._logger:warn("SetState failed: kingdom not found", kingdomId)
        return false
    end

    local currentState: KingdomTypes.KingdomState = kingdom.state
    local allowed: { [KingdomTypes.KingdomState]: boolean }? = VALID_TRANSITIONS[currentState]

    if not allowed or not allowed[newState] then
        self._logger:warn(
            string.format("Invalid state transition: %s -> %s for kingdom %s", currentState, newState, kingdomId)
        )
        return false
    end

    kingdom.state = newState
    self._logger:info(string.format("Kingdom %s state: %s -> %s", kingdomId, currentState, newState))
    return true
end

-- Cache interno

function KingdomService:_hasByPlayer(userId: number): boolean
    return self._cache.byPlayer[userId] ~= nil
end

--- Aplica alteracoes validadas aos recursos de um Kingdom.
--- Atomico: VALIDA todos antes de aplicar QUALQUER um.
---
--- INTERNAL API — Apenas ResourceService (domain owner) pode chamar.
--- Nao chamar diretamente de outros services.
---
--- @param kingdomId string — ID do reino
--- @param changes { [number]: number } — mapa de resourceType -> delta (positivo ou negativo)
--- @return boolean — sucesso da operacao
function KingdomService:ApplyResourceChanges(kingdomId: string, changes: { [number]: number }): boolean
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        self._logger:warn("ApplyResourceChanges failed: kingdom not found", kingdomId)
        return false
    end

    -- Fase 1: Validar todos antes de aplicar qualquer um
    for resourceType: number, delta: number in changes do
        local current: number = kingdom.resources[resourceType] or 0
        if current + delta < 0 then
            self._logger:warn(
                string.format("ApplyResourceChanges rejected: resource %d would go below 0 for kingdom %s", resourceType, kingdomId)
            )
            return false
        end
    end

    -- Fase 2: Aplicar todos (so chega aqui se passou na validacao)
    for resourceType: number, delta: number in changes do
        kingdom.resources[resourceType] = (kingdom.resources[resourceType] or 0) + delta
    end

    kingdom.lastSavedAt = os.time()
    return true
end

--- Adiciona um edificio ao Kingdom.
---
--- INTERNAL API — Apenas BuildingService (domain owner) pode chamar.
---
--- @param kingdomId string
--- @param building any — BuildingData (type erasure para evitar import cycle)
--- @return boolean
function KingdomService:AddBuilding(kingdomId: string, building: any): boolean
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        self._logger:warn("AddBuilding failed: kingdom not found", kingdomId)
        return false
    end
    if kingdom.buildings[building.buildingId] then
        self._logger:warn("AddBuilding failed: duplicate buildingId", building.buildingId)
        return false
    end
    kingdom.buildings[building.buildingId] = building
    kingdom.lastSavedAt = os.time()
    self._logger:info(string.format("Building %s added to kingdom %s", building.buildingId, kingdomId))
    return true
end

--- Remove um edificio do Kingdom.
---
--- INTERNAL API — Apenas BuildingService (domain owner) pode chamar.
---
--- @param kingdomId string
--- @param buildingId string
--- @return boolean
function KingdomService:RemoveBuilding(kingdomId: string, buildingId: string): boolean
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        self._logger:warn("RemoveBuilding failed: kingdom not found", kingdomId)
        return false
    end
    if not kingdom.buildings[buildingId] then
        self._logger:warn("RemoveBuilding failed: building not found", buildingId)
        return false
    end
    kingdom.buildings[buildingId] = nil
    kingdom.lastSavedAt = os.time()
    self._logger:info(string.format("Building %s removed from kingdom %s", buildingId, kingdomId))
    return true
end

--- Busca um edificio especifico pelo ID.
--- @param kingdomId string
--- @param buildingId string
--- @return any? — BuildingData ou nil
function KingdomService:GetBuilding(kingdomId: string, buildingId: string): any?
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        return nil
    end
    return kingdom.buildings[buildingId]
end

--- Retorna todos os edificios de um Kingdom.
--- @param kingdomId string
--- @return { [string]: any }?
function KingdomService:GetBuildings(kingdomId: string): { [string]: any }?
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        return nil
    end
    return kingdom.buildings
end

-- Workers

--- Adiciona um worker ao Kingdom.
--- @param kingdomId string
--- @param worker EntityTypes.WorkerData
--- @return boolean
function KingdomService:AddWorker(kingdomId: string, worker: any): boolean
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        self._logger:warn("AddWorker failed: kingdom not found", kingdomId)
        return false
    end
    if kingdom.workers[worker.workerId] then
        self._logger:warn("AddWorker failed: duplicate workerId", worker.workerId)
        return false
    end
    kingdom.workers[worker.workerId] = worker
    kingdom.lastSavedAt = os.time()
    return true
end

--- Remove um worker do Kingdom.
--- @param kingdomId string
--- @param workerId string
--- @return boolean
function KingdomService:RemoveWorker(kingdomId: string, workerId: string): boolean
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        self._logger:warn("RemoveWorker failed: kingdom not found", kingdomId)
        return false
    end
    if not kingdom.workers[workerId] then
        self._logger:warn("RemoveWorker failed: worker not found", workerId)
        return false
    end
    kingdom.workers[workerId] = nil
    kingdom.lastSavedAt = os.time()
    return true
end

--- Define (ou sobrescreve) o PlotData de um Kingdom.
---
--- INTERNAL API — Apenas PlotService (domain owner) pode chamar.
---
--- @param kingdomId string
--- @param plotData PlotTypes.PlotData
--- @return boolean
function KingdomService:SetPlotData(kingdomId: string, plotData: any): boolean
    local kingdom: KingdomTypes.KingdomData? = self._cache.byId[kingdomId]
    if not kingdom then
        self._logger:warn("SetPlotData failed: kingdom not found", kingdomId)
        return false
    end
    kingdom.plot = plotData
    kingdom.lastSavedAt = os.time()
    self._logger:info(string.format("Plot set for kingdom %s: %dx%d", kingdomId, plotData.gridWidth, plotData.gridDepth))
    return true
end

return KingdomService
