# Feature 3: ResourceService — Arquitetura Revisada

**Ajustes aplicados:**
1. KingdomService como gatekeeper de toda alteracao em KingdomData
2. Evento unico ResourceChanged com lista de mudancas + reason + timestamp
3. TrySpend() como API atomica
4. SetAmount() como API interna/admin apenas
5. Removido Transfer() e Clear()
6. Evento enriquecido para UI, analytics e efeitos visuais

---

## 1. Responsabilidades

| Sistema | Responsabilidade |
|---------|-----------------|
| **ResourceService** | Valida regras de recurso (quantidade, saldo, tipo valido). Decide o que alterar. Dispara eventos. |
| **KingdomService** | Aplica a alteracao em KingdomData. Atualiza timestamps. Garante integridade do dado. |
| **EventBus** | Transporta ResourceChanged para outros sistemas (UI, logging, analytics). |
| **Logger** | Registra auditoria de toda operacao. |

**ResourceService NAO toca KingdomData diretamente.** Ele solicita a alteracao ao KingdomService, que executa a modificacao.

---

## 2. Arquivos Envolvidos

| Arquivo | Acao | Responsabilidade |
|---------|------|-----------------|
| `Shared/Types/ResourceTypes.lua` | Novo | `Resources`, `ResourceChange`, `ResourceChangedEvent`, `CostTable` |
| `Shared/Types/EntityTypes.lua` | Modificar | Remove `Resources` (migrado para ResourceTypes) |
| `Shared/Types/KingdomTypes.lua` | Modificar | Importa `Resources` de ResourceTypes |
| `Services/Core/EventBusService.lua` | Novo | Pub/sub com `on()`, `off()`, `fire()` |
| `Services/Resource/ResourceService.lua` | Novo | 7 APIs publicas de recurso |
| `Services/Kingdom/KingdomService.lua` | Modificar | Adiciona `ApplyResourceChanges()` como API interna |
| `Bootstrap/InitOrder.lua` | Modificar | Adiciona EventBus e Resource |

---

## 3. Tipos Novo (Shared/Types/ResourceTypes.lua)

```lua
export type Resources = { [ResourceType]: number }

export type CostTable = { [ResourceType]: number }

export type ResourceChange = {
    resourceType: ResourceType,
    oldValue: number,
    newValue: number,
}

export type ResourceChangedEvent = {
    kingdomId: string,
    reason: string,
    timestamp: number,
    changes: { ResourceChange },
    triggeredBy: string,
}
```

---

## 4. KingdomService — Nova API Interna

```lua
-- Aplica alteracoes validadas ao Kingdom.resources
-- Apenas chamado por ResourceService (sistema dono do dominio)
-- Nao valida regras de negocio — apenas aplica e gerencia estado
function KingdomService:ApplyResourceChanges(
    kingdomId: string,
    changes: { [ResourceType]: number }
): boolean
```

Internamente:
- Verifica se Kingdom existe e state == Ready
- Para cada change: `kingdom.resources[type] = (kingdom.resources[type] or 0) + delta`
- Atualiza `lastSavedAt` para forcar save
- Loga operacao
- Retorna true/false

---

## 5. ResourceService — APIs Publicas

| API | Assinatura | Descricao |
|-----|-----------|-----------|
| `GetAmount` | `(kingdomId, resourceType) -> number?` | Saldo atual (leitura, sem validacao de estado) |
| `Add` | `(kingdomId, resourceType, amount, reason) -> boolean` | Adiciona recursos. reason: string para auditoria |
| `Remove` | `(kingdomId, resourceType, amount, reason) -> boolean` | Remove recursos. Valida saldo. |
| `TrySpend` | `(kingdomId, cost: CostTable, reason) -> boolean` | Atomico: valida tudo + desconta tudo. Retorna false se qualquer recurso for insuficiente. |
| `Has` | `(kingdomId, resourceType, amount) -> boolean` | Verifica se tem pelo menos N |
| `CanAfford` | `(kingdomId, cost: CostTable) -> boolean` | Verifica custo completo sem alterar |
| `GetAll` | `(kingdomId) -> Resources?` | Retorna copia de todos os recursos |
| `SetAmount` | `(kingdomId, resourceType, amount, reason) -> boolean` | **INTERNA/ADMIN.** Define valor absoluto. Apenas para save restore, migracao, comandos admin. |

Nenhuma API retorna nil para operacoes que deveriam ser validas — lancam erro ou retornam false com log.

---

## 6. Fluxo de Execucao

### Add / Remove

```
ResourceService:Add(kingdomId, ResourceType.Gold, 100, "quest_reward")
  │
  ├── KingdomService:GetById(kingdomId) -> KingdomData?
  │     └── Se nil: return false + Logger:warn
  │
  ├── kingdom.state == "Ready"?
  │     └── Se nao: return false + Logger:warn
  │
  ├── resourceType valido? (member do enum)
  │     └── Se nao: return false + Logger:warn
  │
  ├── amount > 0? (Add) / amount > 0 AND saldo >= amount? (Remove)
  │     └── Se nao: return false + Logger:warn
  │
  ├── KingdomService:ApplyResourceChanges(kingdomId, { [type] = delta })
  │     └── Se falso: return false
  │
  ├── EventBus:fire("ResourceChanged", {
  │       kingdomId = kingdomId,
  │       reason = "quest_reward",
  │       timestamp = os.time(),
  │       changes = { { resourceType = ResourceType.Gold, oldValue = 50, newValue = 150 } },
  │       triggeredBy = "ResourceService",
  │   })
  │
  └── Logger:info -> return true
```

### TrySpend (Fluido Unico)

```
ResourceService:TrySpend(kingdomId, { Gold = 100, Wood = 50 }, "build_farm")
  │
  ├── [Validacao 1] Kingdom existe e esta Ready?
  │
  ├── [Validacao 2] Para cada recurso no cost:
  │     ├── resourceType valido?
  │     ├── amount > 0?
  │     └── kingdom.resources[type] >= amount?
  │     └── Se QUALQUER um falhar -> return false (sem alterar nada)
  │
  ├── [Execucao] KingdomService:ApplyResourceChanges(kingdomId, {
  │       [ResourceType.Gold] = -100,
  │       [ResourceType.Wood] = -50,
  │   })
  │
  ├── [Evento unico] EventBus:fire("ResourceChanged", {
  │       kingdomId = kingdomId,
  │       reason = "build_farm",
  │       timestamp = os.time(),
  │       changes = {
  │           { resourceType = ResourceType.Gold, oldValue = 500, newValue = 400 },
  │           { resourceType = ResourceType.Wood, oldValue = 200, newValue = 150 },
  │       },
  │       triggeredBy = "ResourceService",
  │   })
  │
  └── Logger:info -> return true
```

### SetAmount (Uso Interno)

```
ResourceService:SetAmount(kingdomId, ResourceType.Gold, 1000, "admin_restore")
  │
  ├── Apenas chamado por:
  │     ├── ProfileService (restaurar save)
  │     ├── AdminCommands (/setgold)
  │     └── DataStore migration scripts
  │
  ├── Nao valida saldo (pode zerar ou definir qualquer valor)
  ├── Valida: Kingdom existe, amount >= 0, resourceType valido
  ├── KingdomService:ApplyResourceChanges com delta calculado
  └── Evento + Logger
```

---

## 7. Evento ResourceChanged — Estrutura

```lua
{
    kingdomId: string,             -- Reino afetado
    reason: string,                -- Contexto: "build_farm", "quest_reward", "admin_set"
    timestamp: number,             -- os.time()
    changes: {                     -- Lista de alteracoes
        {
            resourceType: ResourceType,  -- Tipo do recurso
            oldValue: number,            -- Valor antes
            newValue: number,            -- Valor depois
        },
    },
    triggeredBy: string,           -- "ResourceService", "AdminCommand"
}
```

**Consumidores futuros:**

| Consumidor | Uso |
|------------|-----|
| **UI** | Atualizar ResourceBar com animacao de delta |
| **Analytics** | Rastrear economia: quanto gold foi gasto em construcao |
| **Achievements** | Detectar "Gaste 1.000.000 de gold" |
| **Effects** | Mostrar particulas de "+100 Gold" |
| **SaveService** | Marcar profile como dirty para proximo save |

---

## 8. Validacoes por API (Tabela Revisada)

| API | Kingdom existe? | State Ready? | amount > 0 | Saldo sufic. | Uso |
|-----|----------------|-------------|------------|--------------|-----|
| `GetAmount` | Sim (retorna nil se nao) | Nao | Nao | Nao | Leitura |
| `Add` | Sim | Sim | Sim | Nao | Gameplay |
| `Remove` | Sim | Sim | Sim | Sim | Gameplay |
| `TrySpend` | Sim | Sim | Sim (no cost) | Sim | Gameplay |
| `Has` | Sim (retorna false) | Nao | Sim | Sim | Consulta |
| `CanAfford` | Sim (retorna false) | Nao | Sim (no cost) | Sim | Consulta |
| `GetAll` | Sim (retorna nil) | Nao | Nao | Nao | Leitura |
| `SetAmount` | Sim | Sim | >= 0 | Nao | Admin/Interno |

---

## 9. Mudancas em Relacao a Proposta Anterior

| Aspecto | Proposta anterior | Proposta revisada |
|---------|------------------|-------------------|
| Quem modifica KingdomData | ResourceService diretamente | KingdomService via ApplyResourceChanges |
| Evento por recurso | Sim, 1 evento por tipo | Unico evento com lista de changes |
| TrySpend | CanAfford + Spend separados | TrySpend atomico (valida + executa) |
| SetAmount | API publica normal | Marcada como interna/admin |
| Transfer / Clear | Incluidas | Removidas (sem caso de uso ainda) |
| Evento basico | { type, old, new } | { kingdomId, reason, timestamp, changes[], triggeredBy } |
| CostTable | Nao definido | `{ [ResourceType]: number }` |

---

## 10. Arquivos Finais

| # | Arquivo | Linhas (estimado) |
|---|---------|-------------------|
| 1 | `Shared/Types/ResourceTypes.lua` | ~30 |
| 2 | `Services/Core/EventBusService.lua` | ~60 |
| 3 | `Services/Resource/ResourceService.lua` | ~200 |
| 4 | `Services/Kingdom/KingdomService.lua` | +15 (ApplyResourceChanges) |
| 5 | `Shared/Types/EntityTypes.lua` | -3 (remove Resources type) |
| 6 | `Shared/Types/KingdomTypes.lua` | +1 (change import) |
| 7 | `Bootstrap/InitOrder.lua` | +2 linhas |

---

**Aguardando sua aprovacao para implementar a Feature 3 revisada.**
