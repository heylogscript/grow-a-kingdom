# Feature 2: Kingdom Domain — Arquitetura Revisada

**Base:** Revisão crítica da proposta original
**Objetivo:** Corrigir pontos fracos antes da implementação

---

## 1. KingdomModel — Apenas Dados, Zero Lógica

Problema original: KingdomModel com construtor, validação, getters e setters. Modelo de dados não deve ter comportamento.

Solução revisada: **KingdomModel é uma factory pura**. Ela apenas gera uma tabela KingdomData válida com valores padrão. Sem métodos, sem validação, sem getters.

```
KingdomModel.lua
  - new(ownerUserId, displayName) -> KingdomData
  - (nenhum outro método público)
```

A validação pertence ao **KingdomService**, não ao modelo. Single Responsibility: modelo = estrutura de dados; service = regras de negócio.

---

## 2. Resources — Enums como Chave

Problema original: `resources = { Wood = 0, Stone = 0 }` — strings soltas, sujeitas a typos.

Solução revisada: `ResourceType` enum em `Enums.lua`. Resources é uma tabela indexada pelo enum.

```lua
export type Resources = { [ResourceType]: number }
```

Por que enums são melhores que strings:

| Aspecto | String key | Enum key |
|---------|-----------|----------|
| Segurança | "woOd" passa despercebido | Erro de compilação se digitar errado |
| Autocomplete | Nenhum | IDE completa ResourceType. |
| Refatoração | String oculta — grep manual | Renomear muda todas as referências |
| Performance | Hash de string toda vez | Enum é número — lookup mais rápido |

Para DataStore, funções `ResourceType.toString()` e `ResourceType.fromString()` resolvem a serialização.

---

## 3. Buildings — IDs Únicos, Não Nomes

Problema original: `buildings = { Farm = { ... } }` — só permite UM edifício de cada tipo.

Solução revisada: Buildings é um **mapa de UUID -> BuildingData**. Permite múltiplas Farms (Farm #1, Farm #2, Farm #3) cada uma com seu próprio UUID.

```lua
export type BuildingData = {
    buildingId: string,       -- UUID unico (ex: "bld_a1b2c3")
    buildingType: string,     -- "Farm", "Mine", etc. (referencia Config)
    level: number,            -- nivel atual
    position: Vector3,        -- posicao no mundo
    createdAt: number,        -- timestamp
}

-- No KingdomData:
buildings: { [string]: BuildingData }
```

Buscas:
- `kingdom.buildings[buildingId]` -> O(1) lookup
- Quantos do tipo Farm? `filter(buildings, b => b.buildingType == "Farm")` -> O(n) mas raro

---

## 4. Workers — Mesma Estratégia dos Buildings

```lua
export type WorkerData = {
    workerId: string,               -- UUID unico (ex: "wkr_x9y8z7")
    workerType: string,             -- "Peasant", "Builder", etc.
    assignedToBuildingId: string?,  -- nil se nao atribuido
    hiredAt: number,
}

-- No KingdomData:
workers: { [string]: WorkerData }
```

---

## 5. Technologies — O(1) Lookup, Não Lista

Problema original: `technologies = { "Metallurgy", "Agriculture" }` — lista de strings. Checar se tech foi pesquisada: `table.find(techList, techId)` que é O(n).

Solução revisada: **Mapa de techId -> estado**. O(1) para consulta, O(1) para inserção.

```lua
export type TechState = {
    techId: string,
    researched: boolean,
    researchedAt: number?,
}

-- No KingdomData:
technologies: { [string]: TechState }
```

Comparação:

| Operacao | Lista | Mapa |
|----------|-------|------|
| "Ja pesquisou Metallurgy?" | table.find -> O(n) | techs["metallurgy"].researched -> O(1) |
| Adicionar pesquisa | table.insert -> O(1) | techs["metallurgy"] = {...} -> O(1) |
| Remover pesquisa | table.remove -> O(n) | techs["metallurgy"] = nil -> O(1) |

Produção verifica techs a cada tick — O(1) é obrigatório.

---

## 6. Versionamento — Migração Futura

Adicionar três campos estruturais para live-service:

```lua
export type KingdomData = {
    -- Identificacao
    kingdomId: string,
    ownerUserId: number,
    displayName: string,

    -- Core
    level: number,
    state: KingdomState,

    -- Timestamps
    createdAt: number,           -- criacao do reino
    lastLoadedAt: number,        -- ultimo login
    lastSavedAt: number,         -- ultimo save bem-sucedido

    -- Versionamento (CRITICO para live-service)
    version: number,              -- schema version (DataStore migration)
    metadata: { [string]: any },  -- chave-valor flexivel (flags, preferencias)
    statistics: { [string]: number }, -- contadores (totalGoldEarned, etc.)

    -- Dominios
    resources: { [ResourceType]: number },
    buildings: { [string]: BuildingData },
    workers: { [string]: WorkerData },
    technologies: { [string]: TechState },
}
```

**version** — Permite migracao automatica de saves antigos. Quando mudamos o schema, incrementamos a versao. No load, se `version < currentVersion`, rodamos scripts de migracao.

```
Save v1 -> resources = { Gold = 0, Wood = 0 }
Save v2 -> resources = { Gold = 0, Wood = 0, Stone = 0 }
Migration v1 -> v2: resources[Stone] = 0
```

**metadata** — Dados que nao merecem seu proprio campo: feature flags, preferencias de UI, flags de tutorial.

**statistics** — Achievements, leaderboards e analytics futuros. Acumular desde o inicio evita backfill quando AchievementService for implementado.

---

## 7. KingdomService — APIs Publicas

Nenhuma logica interna ainda. Apenas contratos:

| API | Entrada | Saida | Responsabilidade |
|-----|---------|-------|-----------------|
| CreateKingdom | ownerUserId, displayName | KingdomData | Gera ID unico, cria KingdomData, adiciona ao cache |
| DestroyKingdom | kingdomId | boolean | Remove do cache, limpa referencias |
| GetByPlayer | userId | KingdomData? | Busca no cache secundario (userId -> kingdomId -> dados) |
| GetById | kingdomId | KingdomData? | Busca no cache primario (kingdomId -> dados) |
| HasKingdom | userId | boolean | Atalho para GetByPlayer(userId) ~= nil |
| GetAll | - | { [string]: KingdomData } | Retorna todo o cache primario |
| Count | - | number | Quantos reinos ativos no servidor |

Nenhuma chama DataStore ainda — apenas cache em memoria.

---

## 8. Cache — Dois Indices, Zero Iteracao

Problema original: Uma tabela `kingdoms = { [kingdomId] = data }`. Para buscar por player: iterava ate achar ownerUserId.

Solucao revisada: Cache com **indice primario** (kingdomId) e **indice secundario** (playerId). Ambos O(1).

```lua
local cache = {
    byId = {} as { [string]: KingdomData },       -- kingdomId -> dados
    byPlayer = {} as { [number]: string },         -- userId -> kingdomId
}
```

Buscas:
- GetById(id) -> cache.byId[id] -> **O(1)**
- GetByPlayer(userId) -> cache.byPlayer[userId] -> kingdomId -> cache.byId[kingdomId] -> **O(1)**
- HasKingdom(userId) -> cache.byPlayer[userId] ~= nil -> **O(1)**
- GetAll() -> cache.byId -> **O(1)**

Manutencao:
- CreateKingdom: `cache.byId[kingdomId] = data; cache.byPlayer[userId] = kingdomId`
- DestroyKingdom: `cache.byId[kingdomId] = nil; cache.byPlayer[ownerUserId] = nil`

Com 50 jogadores, iterar e rapido. Com 5000 (eventos globais, visitas), iterar trava o servidor.

---

## 9. Estado do Kingdom — Loading, Ready, Saving, Closing

Cada Kingdom tera um **estado interno** que controla seu lifecycle:

```lua
export type KingdomState = "Loading" | "Ready" | "Saving" | "Closing"
```

| Estado | Quando ocorre | O que SaveService deve fazer |
|--------|--------------|------------------------------|
| Loading | Player entrou, dados sendo carregados | NAO salvar (dados incompletos) |
| Ready | Load concluido, Kingdom operacional | Pode salvar normalmente |
| Saving | Save em andamento | Nao iniciar outro save |
| Closing | Player saindo, cleanup em andamento | Salvar ultima vez, depois ignorar |

Importancia: sem estados, SaveService pode salvar um Kingdom ainda carregando (dados parciais -> corrupcao) ou salvar duas vezes simultaneamente (DataStore conflict).

Transicoes validas:
```
Loading -> Ready   (load concluido)
Ready -> Saving     (save iniciado)
Saving -> Ready     (save concluido)
Ready -> Closing    (player saindo)
Saving -> Closing   (player saiu durante save)
```

---

## 10. Resumo de Mudancas da Revisao

| Aspecto | Proposta original | Proposta revisada |
|---------|------------------|-------------------|
| KingdomModel | Construtor + getters/setters | Factory pura, apenas new() -> KingdomData |
| Resources | String keys ("Wood") | Enum keys (ResourceType.Wood) |
| Buildings | Indexado por nome (Farm = ...) | Indexado por UUID (bld_a1 = ...) |
| Workers | Indexado por nome | Indexado por UUID |
| Technologies | Lista de strings | Mapa O(1) |
| Cache | Tabela unica | Indices duplos (byId + byPlayer) |
| Estado | Inexistente | Loading, Ready, Saving, Closing |
| Versionamento | Inexistente | version, metadata, statistics |
| KingdomService APIs | 3 APIs | 7 APIs |

---

## 11. Arquivos Revisados

| Arquivo | Mudanca |
|---------|---------|
| Shared/Types.lua | Adicionar KingdomData, KingdomState, BuildingData, WorkerData, TechState, Resources |
| Shared/Enums.lua | Adicionar ResourceType com membros |
| Shared/Models/KingdomModel.lua | Factory: apenas KingdomModel.new(userId, name) -> KingdomData |
| Services/Kingdom/KingdomService.lua | 7 APIs publicas + cache duplo + geracao de UUID |
| Bootstrap/InitOrder.lua | Registrar KingdomService |
| Bootstrap/ServerBootstrapper.lua | Init e start do KingdomService |

---

**Aguardando sua aprovacao para implementar a Feature 2 revisada.**
