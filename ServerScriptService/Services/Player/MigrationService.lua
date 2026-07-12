--[[
    MigrationService

    Responsabilidade unica: transformar dados carregados do DataStore
    para o schema mais recente do jogo.

    Responsabilidades:
    1. Normalize: converter chaves numericas-string de volta para number
       (compensacao por comportamento do DataStore)
    2. Migrate: aplicar migracoes de schema versao por versao

    Fluxo:
    GetAsync → Normalize → Migrate → KingdomService.ImportKingdom

    Adicionar nova migracao:
    1. Incrementar LATEST_SCHEMA_VERSION
    2. Inserir funcao em MIGRATIONS na posicao (versao_antiga)
       ex: MIGRATIONS[2] = function(data) ... data.schemaVersion = 3; return data end
]]

local MigrationService = {}

local LATEST_SCHEMA_VERSION = 1

local MIGRATIONS: { [number]: (any) -> any } = {
    -- Exemplo de migracao v1 → v2:
    -- [1] = function(data: any): any
    --     data.kingdomData.statistics = data.kingdomData.statistics or {}
    --     data.kingdomData.schemaVersion = 2
    --     data.schemaVersion = 2
    --     return data
    -- end,
}

--- Normaliza chaves numericas-string para number.
--- DataStore pode serializar chaves number como string.
--- Ex: { ["1"] = "gold" } → { [1] = "gold" }
--- Recursivo: processa tabelas aninhadas.
function MigrationService.Normalize(data: any): any
    if type(data) ~= "table" then
        return data
    end

    local result: { any } = {}
    for k: any, v: any in data do
        local key: any = k
        if type(k) == "string" then
            local numericKey: number? = tonumber(k)
            if numericKey ~= nil then
                key = numericKey
            end
        end
        result[key] = MigrationService.Normalize(v)
    end
    return result
end

--- Aplica todas as migracoes pendentes ate LATEST_SCHEMA_VERSION.
function MigrationService.Migrate(data: any): any
    local version: number = data.schemaVersion or 1
    while version < LATEST_SCHEMA_VERSION do
        local migrator: ((any) -> any)? = MIGRATIONS[version]
        if migrator then
            data = migrator(data)
        end
        version += 1
    end
    return data
end

function MigrationService.GetLatestVersion(): number
    return LATEST_SCHEMA_VERSION
end

return MigrationService
