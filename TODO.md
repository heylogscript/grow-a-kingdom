# Grow a Kingdom — TODO List

## Legenda
- `[ ]` Pendente
- `[~]` Em andamento
- `[x]` Concluído

---

## Fase 0 — Protótipo (Infraestrutura)

### Feature 1: Project Foundation
- [ ] Estrutura de pastas no Explorer (Roblox)
- [ ] ServiceLocator (DI container)
- [ ] EventBus (pub/sub)
- [ ] LoggerService
- [ ] Types e Enums globais
- [ ] ServerBootstrapper (init pipeline)
- [ ] ClientBootstrapper

### Feature 2: DataStore & Player Session
- [ ] ProfileService (cache + fila + versionamento)
- [ ] DataStoreService (wrapper com retry)
- [ ] PlayerSessionService (join/leave lifecycle)

### Feature 3: EconomyService
- [ ] Config de recursos (Resources.lua)
- [ ] EconomyService (server-authoritative)
- [ ] RemoteCommand para transações
- [ ] UI de resource bar

### Feature 4: BuildingService (1 edifício)
- [ ] Config de edifícios (Buildings.lua)
- [ ] BuildingService (placement + upgrade)
- [ ] Evolução visual (3 estágios)
- [ ] UI de construção

### Feature 5: ProductionService
- [ ] ProductionService (tick rate)
- [ ] Offline production calculation
- [ ] Auto-save integration

---

## Fase 1 — MVP Fechado

### Feature 6: WorkerService
- [ ] Config de workers (Workers.lua)
- [ ] WorkerService + ObjectPool
- [ ] Atribuição a edifícios

### Feature 7: ProgressionService
- [ ] Config de progressão (Progression.lua)
- [ ] ProgressionService (XP, níveis, unlocks)

### Feature 8: TechTreeService
- [ ] Config de tecnologia (TechTree.lua)
- [ ] TechTreeService (research)
- [ ] UI de tech tree

### Feature 9: UI Core
- [ ] HUD completo
- [ ] BuildMenu
- [ ] KingdomMenu
- [ ] Notificações e feedback

---

## Fase 2 — MVP Aberto

- [ ] Balanceamento de economia
- [ ] Anti-exploit básico
- [ ] Testes com jogadores
- [ ] Correções de bugs

---

## Fase 3 — Multiplayer

- [ ] VisitService
- [ ] EventService
- [ ] Permissions system

---

## Fase 4 — Endgame

- [ ] ExpeditionService
- [ ] RaidService
- [ ] DefenseService

---

## Fase 5 — Lançamento

- [ ] ShopService (gamepasses)
- [ ] AchievementService
- [ ] LeaderboardService
- [ ] AnalyticsService
- [ ] AntiExploitService
- [ ] Testes de carga (500+ CCU)
- [ ] Lançamento público
