--[[
    ProfileService

    UNICA camada que comunica com DataStoreService.
    Nenhum outro modulo pode importar DataStoreService.

    Responsabilidades:
    1. LoadProfile(userId) → carregar do DataStore ou nil
    2. SaveProfile(userId) → persistir snapshot
    3. Autosave() → loop incremental com dirty flag
    4. ShutdownSave() → bindToClose
    5. ReleaseProfile(userId) → liberar referencias
    6. MarkDirty(userId) → gameplay marca para autosave
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local MigrationService = require(script.Parent.MigrationService)

local DATASTORE_NAME = "KingdomData"
local DEFAULT_AUTOSAVE_INTERVAL = 60
local RETRY_ATTEMPTS = 3

export type ProfileService = {
    _serviceLocator: any,
    _logger: any,
    _kingdomService: any,
    _dataStore: any,
    _loadedProfiles: { [number]: boolean },
    _dirtyProfiles: { [number]: boolean },
    _savingLocks: { [number]: boolean },
    _running: boolean,
    _autosaveInterval: number,
}

local ProfileService: ProfileService = {}
ProfileService.__index = ProfileService

-- Helpers internos

local function Retry(fn: () -> any, attempts: number?): (boolean, any)
    attempts = attempts or RETRY_ATTEMPTS
    for i: number = 1, attempts do
        local ok: boolean
        local result: any
        ok, result = pcall(fn)
        if ok then
            return true, result
        end
        if i < attempts then
            task.wait(math.pow(2, i - 1))
        end
    end
    return false, nil
end

local function makeKey(userId: number): string
    return "Kingdom_" .. userId
end

-- Ciclo de vida do service

function ProfileService.new(serviceLocator: any): ProfileService
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = nil,
        _kingdomService = nil,
        _dataStore = nil,
        _loadedProfiles = {},
        _dirtyProfiles = {},
        _savingLocks = {},
        _running = false,
        _autosaveInterval = DEFAULT_AUTOSAVE_INTERVAL,
    }, ProfileService)
end

function ProfileService:init()
    self._logger = self._serviceLocator:get("Logger")
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
    self._logger:info("ProfileService initialized")
end

function ProfileService:start()
    -- Autosave loop
    self._running = true
    task.spawn(function()
        self:_autosaveLoop()
    end)

    -- Shutdown handler
    game:BindToClose(function()
        self:ShutdownSave()
    end)

    self._logger:info("ProfileService started")
end

function ProfileService:stop()
    self._running = false
    self._loadedProfiles = {}
    self._dirtyProfiles = {}
    self._savingLocks = {}
    self._dataStore = nil
    self._logger:info("ProfileService stopped")
end

-- API Publica

--- Carrega perfil do jogador do DataStore.
--- Se ja estiver em cache (rejoin), retorna existente.
--- Se DataStore tiver dados: Normalize → Migrate → ImportKingdom.
--- Se DataStore for nil: retorna nil (primeiro acesso).
--- @param userId number
--- @return any? — KingdomData ou nil
function ProfileService:LoadProfile(userId: number): any?
    -- Ja carregado nesta sessao?
    if self._kingdomService:HasKingdom(userId) then
        return self._kingdomService:GetByPlayer(userId)
    end

    local key: string = makeKey(userId)

    local ok: boolean
    local rawData: any
    ok, rawData = Retry(function()
        return self._dataStore:GetAsync(key)
    end)

    if not ok or rawData == nil then
        return nil
    end

    -- Normalizar chaves numericas
    local normalized: any = MigrationService.Normalize(rawData)

    -- Aplicar migracoes de schema
    local migrated: any = MigrationService.Migrate(normalized)

    local kingdomData: any = migrated.kingdomData
    if not kingdomData then
        self._logger:warn(string.format("LoadProfile: corrupted data for user %d (missing kingdomData)", userId))
        return nil
    end

    local imported: any = self._kingdomService:ImportKingdom(kingdomData)
    if not imported then
        self._logger:warn(string.format("LoadProfile: ImportKingdom failed for user %d", userId))
        return nil
    end

    self._loadedProfiles[userId] = true
    self._dirtyProfiles[userId] = false

    self._logger:info(string.format("Profile loaded for user %d (kingdom %s)", userId, imported.kingdomId))
    return imported
end

--- Salva snapshot do perfil no DataStore.
--- Usa AcquireSaveLock para evitar saves concorrentes.
--- Cria snapshot com table.clone antes de persistir.
--- Limpa dirty flag apenas em caso de sucesso.
--- @param userId number
--- @return boolean
function ProfileService:SaveProfile(userId: number): boolean
    if not self:AcquireSaveLock(userId) then
        self._logger:warn(string.format("SaveProfile: concurrent save rejected for user %d", userId))
        return false
    end

    local kingdom: any = self._kingdomService:GetByPlayer(userId)
    if not kingdom then
        self:ReleaseSaveLock(userId)
        return false
    end

    if kingdom.state ~= "Ready" then
        self:ReleaseSaveLock(userId)
        self._logger:warn(string.format("SaveProfile: kingdom %s is not Ready (state: %s)", kingdom.kingdomId, kingdom.state))
        return false
    end

    -- Snapshot antes de persistir (evita mutacao durante escrita)
    local snapshot: any = table.clone(kingdom)

    local payload: any = {
        schemaVersion = MigrationService.GetLatestVersion(),
        savedAt = os.time(),
        kingdomData = snapshot,
    }

    local key: string = makeKey(userId)
    local ok: boolean = self:_writeProfile(key, payload)

    if ok then
        kingdom.lastSavedAt = os.time()
        self._dirtyProfiles[userId] = false
        self._logger:info(string.format("Profile saved for user %d", userId))
    end

    self:ReleaseSaveLock(userId)
    return ok
end

--- Libera referencias internas do perfil.
--- Chamado apos SaveProfile em PlayerRemoving.
--- @param userId number
function ProfileService:ReleaseProfile(userId: number)
    self._loadedProfiles[userId] = nil
    self._dirtyProfiles[userId] = nil
    self._savingLocks[userId] = nil
end

--- Salva todos os perfis carregados e sujos.
--- Chamado em BindToClose.
--- Fluxo:
--- 1. Parar autosave (nao inicia novos saves)
--- 2. Aguardar saves ativos concluirem
--- 3. Salvar perfis sujos restantes
function ProfileService:ShutdownSave()
    self._logger:info("ShutdownSave: starting")

    -- Parar autosave
    self._running = false

    -- Aguardar saves ativos concluirem (polling com timeout)
    local waitTimeout: number = 30
    while waitTimeout > 0 do
        local hasActiveLocks: boolean = false
        for _: number in self._savingLocks do
            hasActiveLocks = true
            break
        end
        if not hasActiveLocks then
            break
        end
        task.wait(0.5)
        waitTimeout -= 0.5
    end

    if waitTimeout <= 0 then
        self._logger:warn("ShutdownSave: timeout waiting for active saves")
    end

    -- Salvar perfis sujos restantes
    local saved: number = 0
    for userId: number in self._loadedProfiles do
        if self._dirtyProfiles[userId] then
            local ok: boolean = self:SaveProfile(userId)
            if ok then
                saved += 1
            end
        end
    end

    self._loadedProfiles = {}
    self._dirtyProfiles = {}
    self._savingLocks = {}

    self._logger:info(string.format("ShutdownSave: completed (%d profiles saved)", saved))
end

--- Marca perfil como dirty para autosave.
--- Toda alteracao de gameplay relevante deve chamar esta funcao.
--- @param userId number
function ProfileService:MarkDirty(userId: number)
    if self._loadedProfiles[userId] then
        self._dirtyProfiles[userId] = true
    end
end

-- Save Lock

--- Tenta adquirir lock de save para um usuario.
--- @return boolean — true se lock adquirido, false se ja existe
function ProfileService:AcquireSaveLock(userId: number): boolean
    if self._savingLocks[userId] then
        return false
    end
    self._savingLocks[userId] = true
    return true
end

--- Libera lock de save para um usuario.
--- @param userId number
function ProfileService:ReleaseSaveLock(userId: number)
    self._savingLocks[userId] = nil
end

-- Internos

--- Centraliza toda escrita no DataStore.
--- Hoje usa SetAsync.
--- No futuro: trocar internamente para UpdateAsync sem alterar SaveProfile.
--- @param key string
--- @param payload any
--- @return boolean
function ProfileService:_writeProfile(key: string, payload: any): boolean
    local ok: boolean = Retry(function()
        self._dataStore:SetAsync(key, payload)
        return true
    end)
    return ok
end

--- Loop de autosave incremental.
--- Distribui saves entre frames para evitar pico de DataStore.
--- So salva perfis marcados como dirty.
function ProfileService:_autosaveLoop()
    while self._running do
        local userIds: { number } = {}
        for userId: number in self._loadedProfiles do
            table.insert(userIds, userId)
        end

        if #userIds > 0 then
            local intervalPerPlayer: number = math.max(1, self._autosaveInterval / #userIds)
            for _, userId: number in ipairs(userIds) do
                if not self._running then
                    break
                end
                if self._dirtyProfiles[userId] then
                    self:SaveProfile(userId)
                end
                task.wait(intervalPerPlayer)
            end
        else
            task.wait(self._autosaveInterval)
        end
    end
end

return ProfileService
