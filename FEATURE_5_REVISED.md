# Feature 5: Building Definitions — Arquitetura Revisada

**Ajustes aplicados:**
1. BuildingCategory como enum
2. modelName → modelId (AssetRegistry futuro)
3. Production com multiplos outputs + intervalo
4. TechnologyId em vez de string livre
5. upgrades → upgradePath linear
6. tags para buscas
7. schemaVersion
8. Loader / Validator / Registry (3 responsabilidades)
9. Validacao de IDs reservados
10. Congelamento apos validacao

---

## 1. Estrutura de Arquivos

```
ReplicatedStorage/Shared/
  Buildings/
    BuildingLoader.lua              ← escaneia + carrega modulos
    BuildingValidator.lua           ← 10+ regras de validacao
    BuildingRegistry.lua            ← dados congelados + consultas
    BuildingCategories.lua          ← enum de categorias
    Farm.lua                        ← 1 definicao por arquivo
    Mine.lua
    TownHall.lua
    Blacksmith.lua
    ...

  Enums/
    ResourceType.lua                ← ja existe (usado em buildCost)
    TechnologyId.lua                ← NOVO (enum de tecnologias)
```

---

## 2. BuildingDefinition — Schema Revisado

```lua
export type BuildingDefinition = {
    -- Identificacao
    schemaVersion: number,          << NOVO
    id: string,                     -- unico, sem espacos
    displayName: string,
    category: BuildingCategory,     -- enum, nao string

    -- Conteudo
    tags: { string },               << NOVO (ex: { "early_game", "production" })

    -- Terreno
    footprint: {
        width: number,
        depth: number,
    },

    -- Custo e tempo
    buildCost: { [ResourceType]: number },
    buildTime: number,              -- segundos

    -- Desbloqueio
    unlockRequirements: {
        level: number?,
        technology: TechnologyId?,  -- enum, nao string livre
        buildings: { [string]: number }?,  -- { ["farm"] = 2 } precisa de 2 farms
    },

    -- Modelo (logico)
    modelId: string,                -- identificador, nao caminho de asset

    -- Producao (revisado)
    production: {
        outputs: { [ResourceType]: number },
        interval: number,           -- segundos por ciclo
    }?,

    -- Armazenamento
    storage: { [ResourceType]: number }?,

    -- Evolucao (revisado)
    upgradePath: {                  << upgrades substituido
        {
            level: number,
            modelId: string,
            cost: { [ResourceType]: number },
            requirements: {
                level: number?,
                technology: TechnologyId?,
                buildings: { [string]: number }?,
            },
            production: {
                outputs: { [ResourceType]: number },
                interval: number,
            }?,
        },
    }?,
}
```

---

## 3. BuildingCategory — Enum

```lua
-- BuildingCategories.lua
export type BuildingCategory = number
local BuildingCategory = {
    Resource = 1,    -- Farm, Mine, LumberMill
    Production = 2,  -- Blacksmith, Workshop
    Housing = 3,     -- House, Inn
    Storage = 4,     -- Warehouse, Granary
    Military = 5,    -- Barracks, Wall
    Utility = 6,     -- Well, Market
    Decor = 7,       -- Fountain, Statue
    Special = 8,     -- TownHall (unico)
}
```

---

## 4. Exemplo — Farm.lua (Schema Revisado)

```lua
local ResourceType = require(script.Parent.Parent.Enums.ResourceType)
local BuildingCategory = require(script.Parent.BuildingCategories)

return {
    schemaVersion = 1,
    id = "farm",
    displayName = "Farm",
    category = BuildingCategory.Resource,
    tags = { "early_game", "food" },

    footprint = { width = 3, depth = 3 },

    buildCost = {
        [ResourceType.Gold] = 100,
        [ResourceType.Wood] = 50,
    },
    buildTime = 30,

    unlockRequirements = {
        level = 1,
    },

    modelId = "farm_1",

    production = {
        outputs = { [ResourceType.Food] = 10 },
        interval = 60,
    },

    upgradePath = {
        {
            level = 2,
            modelId = "farm_2",
            cost = { [ResourceType.Gold] = 300, [ResourceType.Wood] = 150 },
            requirements = { level = 5 },
            production = {
                outputs = { [ResourceType.Food] = 25 },
                interval = 60,
            },
        },
        {
            level = 3,
            modelId = "farm_3",
            cost = { [ResourceType.Gold] = 800, [ResourceType.Wood] = 400 },
            requirements = { level = 10, technology = TechnologyId.Irrigation },
            production = {
                outputs = { [ResourceType.Food] = 60 },
                interval = 45,
            },
        },
    },
}
```

---

## 5. BuildingLoader — Responsabilidade

Escaneia e carrega todos os modulos da pasta Buildings.

```lua
-- BuildingLoader.lua (em ServerStorage ou ReplicatedStorage)

function BuildingLoader:loadAll(): { BuildingDefinition }
    -- 1. Iterar todos os ModuleScripts em Buildings/ (excluir Loader, Validator, Registry, Categories)
    -- 2. Require cada um
    -- 3. Coletar em uma lista
    -- 4. Retornar lista crua (sem validacao)
end
```

**Auto-descoberta:** Nenhum registro manual. Novo arquivo na pasta = automaticamente carregado.

---

## 6. BuildingValidator — Responsabilidade

Recebe lista crua do Loader, aplica todas as regras.

```lua
-- BuildingValidator.lua

function BuildingValidator:validateAll(
    rawBuildings: { BuildingDefinition },
    validCategories: { string: BuildingCategory },
    validResources: { string: ResourceType },
    validTechnologies: { string: TechnologyId },
): (boolean, { string })
    -- Retorna (aprovado, lista_de_erros)
end
```

### Regras de Validacao

| # | Regra | Como valida |
|---|-------|-------------|
| 1 | `id` unico | Acumula em set, detecta duplicata |
| 2 | `id` nao vazio, sem espacos | `#id > 0` e `id:match("%s") == nil` |
| 3 | `id` nao reservado | `BuildingRegistry.RESERVED_IDS` contem "all", "none", "new", "delete", etc. |
| 4 | `schemaVersion` > 0 | `schemaVersion >= 1` |
| 5 | `category` e membro do enum | `validCategories[category] ~= nil` |
| 6 | `footprint.width > 0`, `footprint.depth > 0` | Ambos inteiros positivos |
| 7 | `buildCost` todos > 0 e resources validos | Cada key em `validResources`, cada value > 0 |
| 8 | `buildTime > 0` | Numero positivo |
| 9 | `unlockRequirements.technology` valido (se presente) | `validTechnologies[tech] ~= nil` |
| 10 | `production.interval > 0` (se presente) | `interval > 0` |
| 11 | `production.outputs` todos > 0 (se presente) | Cada value > 0 |
| 12 | `upgradePath` níveis sao sequenciais (1, 2, 3...) | Indice do array == level |
| 13 | `upgradePath` referencias validas de technology | Mesma validacao que unlockRequirements |
| 14 | `upgradePath` custos validos | Mesma validacao que buildCost |
| 15 | `tags` nao contem duplicatas | Set interno |
| 16 | `modelId` nao vazio | `#modelId > 0` |
| 17 | `displayName` nao vazio | `#displayName > 0` |

**Se QUALQUER regra falhar, o registro inteiro e rejeitado.** Erros sao retornados como lista para debug.

---

## 7. BuildingRegistry — Responsabilidade

Recebe dados ja validados, congela, disponibiliza consultas.

```lua
-- BuildingRegistry.lua (ReplicatedStorage/Shared/Buildings/)

local RESERVED_IDS: { string: boolean } = {
    all = true, none = true, new = true, delete = true,
    edit = true, copy = true, paste = true, default = true,
    empty = true, unknown = true, null = true, nil = true,
}

function BuildingRegistry.new(buildings: { BuildingDefinition }): BuildingRegistry
    -- 1. Indexar por id
    -- 2. Indexar por categoria
    -- 3. CONGELAR (nao pode mais modificar)
end
```

### APIs de Consultas

| API | Retorno | Descricao |
|-----|---------|-----------|
| `GetById(id)` | `BuildingDefinition?` | O(1) lookup |
| `GetByCategory(cat)` | `{BuildingDefinition}` | Todos de uma categoria |
| `GetByIds(ids)` | `{[string]: BuildingDefinition}` | Lookup em lote |
| `GetByTag(tag)` | `{BuildingDefinition}` | Filtro por tag |
| `GetAll()` | `{[string]: BuildingDefinition}` | Todos (congelado/imutavel) |
| `Count()` | `number` | Total registrado |

### Congelamento

```lua
-- Apos o registro:
-- 1. Envolver indices em metatables com __newindex que erro
-- 2. Ou usar table.freeze() se disponivel no Luau
-- 3. Ou criar wrapper readonly

setmetatable(self._byId, { __newindex = function()
    error("BuildingRegistry is frozen: cannot modify after initialization")
end })
```

---

## 8. Fluxo Completo

```
Bootstrapper (ou BuildingRegistry.init)
  │
  ├── 1. BuildingLoader:loadAll()
  │     └── Escaneia Buildings/ (exclui Loader, Validator, Registry, Categories)
  │     └── Retorna { FarmDef, MineDef, TownHallDef, ... }
  │
  ├── 2. BuildingValidator:validateAll(rawBuildings, categories, resources, techs)
  │     └── 17 regras aplicadas em todos
  │     └── Se falhar: log de erros, jogo para (nao inicia sem catalogo valido)
  │
  ├── 3. BuildingRegistry.new(validatedBuildings)
  │     └── Indexa por id + categoria + tag
  │     └── Congela
  │
  └── 4. BuildingRegistry disponivel para:
        ├── BuildingService (futuro)
        ├── UI (BuildMenu)
        └── ProductionService (futuro)
```

---

## 9. Dependencias

```
BuildingLoader       → (nada) — escaneia instancias do Roblox
BuildingValidator    → BuildingCategories, ResourceType, TechnologyId
BuildingRegistry     → (nada) — recebe dados ja validados
Farm.lua             → ResourceType, BuildingCategory
```

Loader e Registry nao importam nada de gameplay. Validator importa apenas enums.

---

## 10. O que NÃO esta incluido

- BuildingService (futuro)
- Spawn de modelos
- AssetRegistry (futuro — mapeia modelId para MeshPart/Model)
- Preview
- UI
- Logica de construcao

---

**Aguardando sua aprovacao para implementar a Feature 5 revisada.**
