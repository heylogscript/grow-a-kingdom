# Feature 6: Building Domain — Arquitetura Revisada

**Ajustes aplicados:**
1. BuildingRepository removido — BuildingService chama KingdomService direto
2. buildingType -> definitionId (consistente com BuildingRegistry)
3. rotation + schemaVersion em BuildingData
4. BuildingState como enum proprio em Shared/Enums
5. PlacementValidator dividido em PlacementValidator + RequirementValidator
6. BuildingFactory cria apenas estrutura base (state definido pelo Service)
7. ReserveArea antes da persistencia + rollback documentado
8. BuildingChanged adicionado

---

## 1. Tipos — BuildingDomainTypes

```lua
-- ReplicatedStorage/Shared/Types/BuildingDomainTypes.lua

export type BuildingData = {
    buildingId: string,         -- UUID
    definitionId: string,       -- "farm", "mine" (referencia BuildingRegistry)
    level: number,
    state: BuildingState,
    position: { x: number, z: number },
    rotation: number,           -- 0, 90, 180, 270 (futuro: rotacao no grid)
    schemaVersion: number,      -- para migracoes futuras de schema
    createdAt: number,
}
```

## 2. BuildingState — Enum

```lua
-- ReplicatedStorage/Shared/Enums/BuildingState.lua

export type BuildingState = number

local BuildingState = {
    Constructing = 1,   -- sendo construido (timer futuro)
    Active = 2,         -- operacional, produzindo
    Paused = 3,         -- pausado pelo jogador
    Demolished = 4,     -- marcado para remocao
}
```

## 3. BuildingFactory — Factory Pura

```lua
-- ServerScriptService/Services/Building/BuildingFactory.lua

function BuildingFactory.new(definitionId: string, x: number, z: number, rotation: number): BuildingData
    -- Apenas:
    --   Gera UUID (HttpService:GenerateGUID)
    --   Preenche definitionId, position, rotation, schemaVersion, createdAt
    --   NÃO define state (BuildingService define)
    --   NÃO define level (definido pelo BuildingService, padrao 1)
    -- Nenhum require de service. Nenhum side effect.
end
```

## 4. PlacementValidator — Grid + Colisao + Footprint + Rotacao

```lua
-- ServerScriptService/Services/Building/PlacementValidator.lua

function PlacementValidator:validate(kingdomId, definitionId, x, z, rotation)
    -- 1. BuildingDefinition existe? (BuildingRegistry.GetById)
    -- 2. Plot existe? (kingdom.plot ~= nil)
    -- 3. (x, z) dentro dos limites do grid? (PlotService.IsInside)
    -- 4. Area livre? (PlotService.IsAreaFree com footprint do definition)
    -- 5. Rotacao valida? (0, 90, 180, 270)
    -- Retorna (valido, erro?)
end
```

**Nenhum require de ResourceService, KingdomService ou RequirementValidator.**

## 5. RequirementValidator — Recursos + Nivel + Tecnologias + Dependencias

```lua
-- ServerScriptService/Services/Building/RequirementValidator.lua

function RequirementValidator:validate(kingdom, definition)
    -- 1. Kingdom.state == Ready?
    -- 2. kingdom.level >= definition.unlockRequirements.level?
    -- 3. ResourceService.CanAfford(kingdom.kingdomId, definition.buildCost)?
    -- 4. Technology pesquisada? (futuro: TechTreeService)
    -- 5. Buildings dependentes existem? (futuro)
    -- Retorna (valido, erro?)
end
```

**Separado do PlacementValidator porque muda por motivos diferentes:**
- PlacementValidator muda quando o grid muda (tamanho, formato)
- RequirementValidator muda quando requisitos de gameplay mudam

## 6. BuildingService — Fluxo Revisado com Rollback

```
BuildingService:PlaceBuilding(kingdomId, "farm", 10, 5, 0)
  │
  FASE 1 — VALIDAR (zero side effects)
  │
  ├── 1. kingdom = KingdomService:GetById(kingdomId)
  │     └── Se nil → return false, "kingdom_not_found"
  │
  ├── 2. definition = BuildingRegistry:GetById("farm")
  │     └── Se nil → return false, "invalid_building"
  │
  ├── 3. PlacementValidator:validate(kingdomId, "farm", 10, 5, 0)
  │     └── Se invalido → return false, erro
  │
  ├── 4. RequirementValidator:validate(kingdom, definition)
  │     └── Se invalido → return false, erro
  │
  FASE 2 — EXECUTAR (cada etapa com rollback documentado)
  │
  ├── 5. ResourceService:TrySpend(kingdomId, definition.buildCost, "build_farm")
  │     └── Falha inesperada → return false (Fase 1 ja passou, mas seguro)

  │     ROLLBACK SE PROXIMA ETAPA FALHAR:
  │     ├── Se etapa 6 falhar → ResourceService:Add (reembolso do custo)
  │     └── Se etapa 7 falhar → ResourceService:Add + PlotService:ReleaseArea
  │
  ├── 6. PlotService:ReserveArea(kingdomId, 10, 5, 3, 3, buildingId)
  │     └── OccupancyCache transiente (NAO persistido)
  │     └── Se falhar → ROLLBACK: ResourceService:Add (reembolso)

  │     ROLLBACK SE PROXIMA ETAPA FALHAR:
  │     └── Se etapa 7 falhar → PlotService:ReleaseArea + ResourceService:Add
  │
  ├── 7. buildingData = BuildingFactory.new("farm", 10, 5, 0)
  │     buildingData.level = 1
  │     buildingData.state = BuildingState.Constructing
  │     buildingData.buildingId = <UUID gerado pela factory>
  │
  ├── 8. KingdomService:AddBuilding(kingdomId, buildingData)
  │     └── Persiste em kingdom.buildings (fonte unica de verdade)
  │     └── Se falhar →
  │           ROLLBACK:
  │             1. PlotService:ReleaseArea(kingdomId, 10, 5, 3, 3)
  │             2. ResourceService:Add(kingdomId, "build_farm_rollback")
  │           return false, "persist_failed"
  │
  │  ┌─────────────────────────────────────────────────────────────┐
  │  │ APOS ESTE PONTO, BUILDING ESTA PERSISTIDO.                  │
  │  │ Falhas em eventos/logging NAO causam rollback.              │
  │  └─────────────────────────────────────────────────────────────┘
  │
  FASE 3 — NOTIFICAR (falhas apenas logam, sem rollback)
  │
  ├── 9. BuildingEvents:firePlaced(kingdomId, buildingData, definition)
  │
  ├── 10. BuildingEvents:fireChanged(kingdomId, "placed", buildingData.buildingId)
  │       └── NOVO: BuildingChanged para consumidores futuros
  │
  ├── 11. Logger:info("Building placed: farm (10,5) for kingdom ...")
  │
  └── return true, buildingData
```

## 7. Estrategia de Rollback — Tabela Completa

| Etapa | Operacao | Compensacao (rollback) |
|-------|----------|------------------------|
| 5 | `ResourceService:TrySpend` (deduz recursos) | `ResourceService:Add` com reason = "rollback_place_building" |
| 6 | `PlotService:ReserveArea` (ocupa celulas) | `PlotService:ReleaseArea` (cache transiente) |
| 7 | `BuildingFactory.new` (memoria apenas) | Nenhuma — sem side effect |
| 8 | `KingdomService:AddBuilding` (persiste) | `KingdomService:RemoveBuilding` |

### Stack de rollback (ordem inversa):

```
Falha na etapa 8 (AddBuilding):
  Rollback 1: PlotService:ReleaseArea (desfaz etapa 6)
  Rollback 2: ResourceService:Add (desfaz etapa 5)

Falha na etapa 6 (ReserveArea):
  Rollback 1: ResourceService:Add (desfaz etapa 5)

Falha na etapa 5 (TrySpend):
  Nada a desfazer (TrySpend e atomico — se falhou, nada foi gasto)
```

### Consistencia em caso de crash do servidor:

Se o servidor crashar entre as etapas 5 e 8, o estado fica:
- Recursos gastos (etapa 5 concluida)
- Celulas ocupadas no cache transiente (etapa 6) — PERDIDO no crash
- Building NAO persistido (etapa 8 nao concluida)

**Mitigacao:** No load da profile, `PlotService:rebuildOccupancyCache(kingdom)` varre `kingdom.buildings` e reconstroi o cache. Celulas fantasmas somem. Recursos gastos sao considerados perda aceitavel (preferivel a duplicacao).

## 8. BuildingEvents — Eventos do Dominio

```lua
-- ServerScriptService/Services/Building/BuildingEvents.lua

function BuildingEvents:firePlaced(kingdomId, buildingData, definition)
    -- EventBus:fire("BuildingPlaced", { kingdomId, building, definition, timestamp })
end

function BuildingEvents:fireRemoved(kingdomId, buildingId, reason)
    -- EventBus:fire("BuildingRemoved", { kingdomId, buildingId, reason, timestamp })
end

function BuildingEvents:fireChanged(kingdomId, action, buildingId, changes?)
    -- EventBus:fire("BuildingChanged", { kingdomId, action, buildingId, changes, timestamp })
    -- action: "placed" | "removed" | "upgraded" | "state_changed"
    -- changes (opcional): { field: oldValue, field2: oldValue2 }
end
```

**BuildingChanged consolida todos os eventos de mudanca.** Consumidores futuros (UI, Analytics, Achievements) escutam um unico evento.

## 9. KingdomService — Novas APIs

```lua
function KingdomService:AddBuilding(kingdomId: string, buildingData: BuildingDomainTypes.BuildingData): boolean
    -- Valida kingdom existe
    -- kingdom.buildings[buildingData.buildingId] = buildingData
    -- kingdom.lastSavedAt = os.time()
    -- Logger
end

function KingdomService:RemoveBuilding(kingdomId: string, buildingId: string): (boolean, BuildingData?)
    -- Valida kingdom existe e buildingId existe
    -- local removed = kingdom.buildings[buildingId]
    -- kingdom.buildings[buildingId] = nil
    -- lastSavedAt
    -- return true, removed
end
```

## 10. Atualizacao em EntityTypes

O `BuildingData` antigo em `EntityTypes.lua` sera substituido pelo novo tipo do `BuildingDomainTypes.lua`:

```lua
-- ANTES:
export type BuildingData = {
    buildingId: string,
    buildingType: string,
    level: number,
    position: Vector3,
    createdAt: number,
}

-- DEPOIS (removido de EntityTypes, movido para BuildingDomainTypes):
-- EntityTypes referencia BuildingDomainTypes.BuildingData
-- ou simplesmente nao tem mais BuildingData (cada dominio tem seus tipos)
```

Melhor: **EntityTypes nao deve mais ter BuildingData.** Cada dominio define seus proprios tipos. `KingdomTypes.lua` importa de `BuildingDomainTypes` diretamente.

## 11. Arquivos

| Arquivo | Acao | Linhas (est.) |
|---------|------|---------------|
| `Shared/Enums/BuildingState.lua` | NOVO | ~15 |
| `Shared/Types/BuildingDomainTypes.lua` | NOVO | ~30 |
| `Shared/Types/EntityTypes.lua` | MODIFICAR | -5 (remove BuildingData) |
| `Shared/Types/KingdomTypes.lua` | MODIFICAR | +1 (import BuildingDomainTypes) |
| `Services/Building/BuildingFactory.lua` | NOVO | ~25 |
| `Services/Building/PlacementValidator.lua` | NOVO | ~50 |
| `Services/Building/RequirementValidator.lua` | NOVO | ~50 |
| `Services/Building/BuildingEvents.lua` | NOVO | ~60 |
| `Services/Building/BuildingService.lua` | NOVO | ~120 |
| `Services/Kingdom/KingdomService.lua` | MODIFICAR | +30 (AddBuilding + RemoveBuilding) |
| `Bootstrap/InitOrder.lua` | MODIFICAR | +1 (Building) |

---

**Aguardando sua aprovacao para implementar a Feature 6 revisada.**
