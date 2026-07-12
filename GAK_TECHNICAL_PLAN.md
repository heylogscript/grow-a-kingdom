# Grow a Kingdom — Documento Técnico de Planejamento

---

## 1. Visão Geral do Jogo

**Grow a Kingdom** é um jogo Roblox de progressão idle com foco em construção, automação e evolução visual de um reino medieval vivo. O jogador começa com um pequeno terreno e alguns recursos básicos, e ao longo do tempo expande seu reino construindo edifícios, desbloqueando trabalhadores NPCs, automatizando produção e desbloqueando tecnologias.

**Gênero:** Idle Builder / Kingdom Management / Multiplayer Social  
**Público-alvo:** Casual a médio (Roblox 8+)  
**Plataforma:** Roblox (PC, Mobile, Console, Tablet)  
**Modelo de negócio:** Grátis para jogar com gamepasses/itens opcionais  
**Tonalidade:** Relaxante, satisfatório, progressão gradual

### Inspirações
- Grow a Garden — Loop de progressão e sensação de crescimento
- Clash of Clans — Evolução visual de construções
- Animal Crossing — Ambiente relaxante e visitas entre jogadores
- Factorio / Satisfactory — Automação de produção
- Cookie Clicker — Loop idle viciante
- Stardew Valley — Crescimento gradual e recompensador

---

## 2. Loop Principal de Gameplay

```
[1] Coletar Recursos
        │
        ▼
[2] Construir / Melhorar Edifícios
        │
        ▼
[3] Desbloquear Trabalhadores (NPCs)
        │
        ▼
[4] Automatizar Produção
        │
        ▼
[5] Expandir o Reino
        │
        ▼
[6] Desbloquear Novas Tecnologias
        │
        ▼
[7] Evoluir Aparência do Reino
        │
        ▼
[8] ──────────→ Repetir (escala maior)
```

Cada ciclo aumenta a complexidade, a taxa de produção e o alcance visual do reino.

---

## 3. Gameplay Secundário

- **Visitas entre jogadores** — Ver reinos de amigos, interagir, deixar recursos
- **Eventos globais** — Temporários com recompensas especiais (festivais, estações)
- **Expedições** (endgame) — Missões PvE cooperativas para recursos raros
- **Raids cooperativas** (endgame) — Chefões e desafios em grupo
- **Defesa do reino** (endgame) — Invasões opcionais com recompensas
- **Guerras entre reinos** (endgame) — PvP opcional e totalmente opt-in

---

## 4. Sistemas Principais

### Foundation (obrigatórios para o MVP)

| Sistema | Responsabilidade |
|---------|-----------------|
| **Economia** | Gerenciar todos os recursos do jogo (gold, madeira, pedra, comida, gems, mana, etc.) |
| **Construção** | Placement, upgrade, remoção e evolução visual de edifícios |
| **Produção** | Geração automatizada de recursos por edifícios e trabalhadores |
| **Trabalhadores** | NPCs que executam tarefas automáticas (coleta, produção, transporte) |
| **Progressão** | XP, níveis, marcos de reino, desbloqueios |
| **Árvore de Tecnologia** | Pesquisas que desbloqueiam upgrades permanentes |
| **DataStore** | Persistência de dados do jogador (salvar/carregar) |
| **Player Session** | Gerenciamento de sessão do jogador (entrada/saída) |
| **UI Core** | HUD principal, menus de construção, inventário |

### Expansion (pós-MVP)

| Sistema | Responsabilidade |
|---------|-----------------|
| **Visitas** | Sistema multiplayer de visitas entre reinos |
| **Eventos Globais** | Eventos temporários gerenciados pelo servidor |
| **Expedições** | Conteúdo PvE de endgame |
| **Raids** | Conteúdo cooperativo de endgame |
| **Defesa** | Eventos de defesa automática |
| **Guerras** | PvP opcional entre reinos |

### Polimento (antes do lançamento público)

| Sistema | Responsabilidade |
|---------|-----------------|
| **Achievements** | Conquistas e colecionáveis |
| **Leaderboard** | Rankings baseados em poder/riqueza |
| **Loja** | Gamepasses, itens, boosts |
| **Analytics** | Telemetria de comportamento do jogador |
| **Anti-Exploit** | Proteção contra.RemoteEvent abuse, memory tampering |

---

## 5. Ordem de Desenvolvimento e Dependências

```
Tier 1 — Fundação (MVP)
─────────────────────────────────
 1. Estrutura do Projeto
    └── Depende de: nada
    └── Libera: todo o resto

 2. PlayerService + DataStoreService
    └── Depende de: Estrutura
    └── Libera: Economy, Progression

 3. EconomyService
    └── Depende de: PlayerService, DataStore
    └── Libera: Building, Production, Workers, Tech

 4. BuildingService
    └── Depende de: Economy, PlayerService
    └── Libera: Production, Workers, Progression

 5. ProductionService
    └── Depende de: Building, Economy
    └── Libera: Workers, Tech

 6. WorkerService
    └── Depende de: Building, Production, Economy
    └── Libera: Automation loop completo

 7. ProgressionService
    └── Depende de: Economy, Building
    └── Libera: TechTree, Unlocks

 8. TechTreeService
    └── Depende de: Progression, Economy, Building
    └── Libera: Endgame systems

 9. UIService (versão final do MVP)
    └── Depende de: todos os acima
    └── Libera: MVP jogável

Tier 2 — Multiplayer & Social (pós-MVP)
─────────────────────────────────
10. VisitService
    └── Depende de: tudo do MVP
    └── Requer: sistema de permissões, instâncias

11. EventService
    └── Depende de: MVP + VisitService

Tier 3 — Endgame
─────────────────────────────────
12. ExpeditionService
13. RaidService
14. DefenseService
15. WarService (opcional)

Tier 4 — Lançamento
─────────────────────────────────
16. AchievementService
17. LeaderboardService
18. ShopService (gamepasses)
19. AnalyticsService
20. AntiExploitService
21. UI Polish final
22. Testes de carga e balanceamento
```

### Dependências Detalhadas

```
EconomyService
  ├── depende de: PlayerService, DataStoreService
  └── usado por: BuildingService, ProductionService, WorkerService, TechService

BuildingService
  ├── depende de: EconomyService
  ├── usado por: ProductionService, WorkerService, ProgressionService

ProductionService
  ├── depende de: BuildingService, WorkerService
  └── usado por: EconomyService

WorkerService
  ├── depende de: BuildingService, EconomyService
  └── usado por: ProductionService

ProgressionService
  ├── depende de: EconomyService, BuildingService
  └── usado por: TechTreeService, BuildingService (unlocks)

TechTreeService
  ├── depende de: ProgressionService, EconomyService, BuildingService
  └── usado por: ProductionService, WorkerService

VisitService
  ├── depende de: BuildingService (renderização do reino)
  └── usado por: EventService
```

---

## 6. Roadmap de Desenvolvimento

### Fase 0 — Protótipo (1–2 semanas)
- Estrutura de pastas e módulos
- Sistema de tipos globais
- PlayerService funcional (entrar/sair)
- DataStoreService básico (save/load)
- EconomyService com 1–2 recursos
- 1 edifício construível
- Produção manual -> automática
- UI mínima

### Fase 1 — MVP Fechado (3–5 semanas)
- BuildingService com 5–10 edifícios
- Evolução visual (3 estágios por edifício)
- WorkerService com 2–3 tipos de NPC
- ProductionService completo
- ProgressionService (níveis 1–50)
- TechTreeService (10–15 tecnologias)
- UIService completo
- Save/Load estável

### Fase 2 — MVP Aberto (6–8 semanas)
- Balanceamento de economia
- Testes com jogadores reais
- Correções de bugs e exploits
- Otimização de performance
- UI polish

### Fase 3 — Multiplayer (9–11 semanas)
- VisitService funcional
- Interações entre jogadores
- EventService básico
- Sistema de amigos

### Fase 4 — Endgame (12–16 semanas)
- ExpeditionService
- RaidService
- DefenseService
- WarService (se viável)

### Fase 5 — Lançamento (17–20 semanas)
- ShopService
- AchievementService
- LeaderboardService
- AnalyticsService
- AntiExploitService
- Testes de carga (500+ CCU simulados)
- Lançamento público

---

## 7. Sistemas Que Podem Ser Adiados

| Sistema | Motivo do Adiamento |
|---------|-------------------|
| WarService (PvP) | Requer balanceamento complexo, não essencial para o core loop |
| RaidService | Endgame, requer base de jogadores ativa |
| ExpeditionService | Endgame, pode ser implementado como eventos primeiro |
| DefenseService | Pode ser substituído por eventos temporários no MVP |
| AchievementService | Não afeta jogabilidade, pode vir em update pós-lançamento |
| LeaderboardService | Baixo impacto no MVP |
| ShopService | Pode ser mínimo no MVP (apenas 1–2 gamepasses) |
| AnalyticsService | Essencial mas pode ser implementado gradualmente |

---

## 8. Sistemas Críticos (devem ser robustos desde o início)

| Sistema | Por que é crítico |
|---------|------------------|
| **DataStoreService** | Perda de dados = perda de jogadores. Deve ter fallback, retry, cache, autosalvamento |
| **EconomyService** | Coração do jogo. Qualquer bug de economia quebra a progressão |
| **BuildingService** | Core gameplay. Placement inválido, duplicação, perda de edifícios são fatais |
| **RemoteEvent Security** | Todo RemoteEvent deve validar autorização, rate-limit, e sanidade dos dados |
| **Save/Load** | Deve salvar automaticamente a cada N minutos + em eventos críticos. Load deve ser resiliente |
| **Player Session** | Deve limpar dados corretamente ao sair. Prevenir duplicação de sessão |

---

## 9. Riscos Técnicos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| **DataStore limits** (60 req/min/player) | Alta | Alto | Cache write-back, debounce, fila de saves, saves em lote |
| **Memory leak com muitas instâncias** | Média | Alto | Object pooling, destruição programada de instâncias não usadas |
| **Exploit de RemoteEvent** | Alta | Alto | Validação no servidor de TODOS os parâmetros, rate-limit por player |
| **Economia desbalanceada** | Alta | Médio | Config-driven, simulações, dados de analytics para ajuste |
| **Server lag com 50+ reinos carregados** | Média | Alto | LOD de edifícios, carregamento sob demanda em visitas |
| **Conflito de saves** (jogador em 2 servidores) | Baixa | Crítico | Heartbeat, lock otimista, timestamp de última sessão |
| **Rollback de recursos** | Média | Crítico | Log de transações, validação de saldo antes de qualquer gasto |
| **Dependência de módulos Roblox instáveis** | Média | Médio | Wrapper próprio para serviços críticos (HttpService, DataStore) |
| **Jogador perder progresso** | Média | Crítico | Salvamento redundante, confirmação visual de save, auto-save frequente |

---

## 10. Estratégia para Escalar o Projeto Futuramente

### Arquitetura Modular
- Cada sistema é um módulo independente em `ReplicatedStorage/Services/`
- Injeção de dependência via `_G` ou `require` explícito com init ordenado
- Possibilidade de extrair subsistemas para `ServerScriptService` ou `ModuleScript` separados

### Expansão de Conteúdo
- Todo conteúdo (edifícios, tecnologias, recursos) deve ser **data-driven** via módulos de configuração
- Adicionar um novo edifício = criar um entry em uma tabela de config, não escrever novo código
- Sistema de "addons" futuros carregados dinamicamente

### Performance
- Streaming de partes do reino baseado em proximidade do jogador
- Pooling de workers NPCs (reuso de instâncias)
- Otimização de malhas (mesclar partes estáticas após construção)
- LOD visual para reinos vizinhos em visitas

### Equipe
- Separação clara entre sistemas permite trabalho paralelo
- 1 dev por sistema sem conflito de merge (cada sistema em sua pasta)
- Documentação de interfaces (tipos Luau) permite contratos claros

### Monetização Futura
- Gamepasses de aceleração (boosts de produção)
- Itens cosméticos (decorações, skins de edifícios)
- Pacotes de recursos iniciais
- Passe de temporada (eventos sazonais)

---

## 11. Proposta de Ordem de Implementação (MVP → Público)

```
SEMANA 1-2
  ├── Estrutura do projeto
  ├── Tipos globais (Luau Types)
  ├── PlayerService
  ├── DataStoreService (save/load)
  └── EconomyService (2-3 recursos)

SEMANA 3-4
  ├── BuildingService (3-5 buildings)
  ├── Evolução visual básica
  └── ProductionService simples

SEMANA 5-6
  ├── WorkerService (2 tipos)
  ├── Automação completa
  └── ProgressionService (níveis 1-30)

SEMANA 7-8
  ├── TechTreeService (10 techs)
  ├── UI Service completo
  └── MVP jogável (teste interno)

SEMANA 9-10
  ├── Balanceamento
  ├── Correção de bugs
  ├── Anti-exploit básico
  └── Teste fechado (10-20 jogadores)

SEMANA 11-12
  ├── VisitService
  └── EventService básico

SEMANA 13-16
  ├── Endgame (expedições, raids)
  ├── ShopService
  └── Achievements / Leaderboards

SEMANA 17-20
  ├── Polish final
  ├── Analytics
  ├── Anti-exploit avançado
  ├── Teste de carga
  └── Lançamento
```

---

**Fim do documento técnico.**

Aguardando sua aprovação para iniciar a **Fase 0 — Protótipo** com a definição da arquitetura de pastas, estrutura de módulos e sistema de tipos.
