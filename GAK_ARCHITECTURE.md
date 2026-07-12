# Grow a Kingdom — Documento de Arquitetura

**Versão:** 1.0  
**Autor:** Tech Lead  
**Status:** Aprovado para implementação

---

## Índice

1. [Filosofia da Arquitetura](#1-filosofia-da-arquitetura)
2. [Estrutura do Explorer](#2-estrutura-do-explorer)
3. [Responsabilidade de Cada Pasta](#3-responsabilidade-de-cada-pasta)
4. [Ciclo de Inicialização](#4-ciclo-de-inicialização)
5. [Comunicação Entre Sistemas](#5-comunicação-entre-sistemas)
6. [Estratégia para Expansão Futura](#6-estratégia-para-expansão-futura)
7. [Como Adicionar um Novo Sistema](#7-como-adicionar-um-novo-sistema)
8. [Convenções de Nomenclatura](#8-convenções-de-nomenclatura)
9. [Organização dos Arquivos](#9-organização-dos-arquivos)
10. [Padrões Utilizados](#10-padrões-utilizados)
11. [Diagrama da Arquitetura](#11-diagrama-da-arquitetura)

---

## 1. Filosofia da Arquitetura

### 1.1 Como o Projeto Será Organizado

O projeto é organizado em **três camadas estritas** com direção única de dependência:

```
┌─────────────────────────────────────────────────────────────┐
│                      SERVER LAYER                           │
│            ServerScriptService / ServerStorage              │
│  (autoridade, validação, persistência, lógica de gameplay)  │
└──────────────────────────┬──────────────────────────────────┘
                           │  importa
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      SHARED LAYER                           │
│                   ReplicatedStorage                         │
│  (tipos, config, utilitários, definições remotas, assets)   │
└──────────────────────────┬──────────────────────────────────┘
                           │  importa
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      CLIENT LAYER                           │
│              StarterPlayer / StarterGui / StarterPack       │
│  (UI, input, feedback visual, câmera, efeitos)              │
└─────────────────────────────────────────────────────────────┘
```

**Regra fundamental:** Server importa Shared. Client importa Shared. Shared **nunca** importa Server ou Client. Server **nunca** importa Client. Client **nunca** importa Server.

### 1.2 Por Que Essa Arquitetura Foi Escolhida

A arquitetura em três camadas com direção única de dependência é o padrão da indústria Roblox para jogos de grande escala (adotado por títulos como Adopt Me!, Pet Simulator, Tower Defense Simulator). As alternativas consideradas foram:

| Abordagem | Problema | Por que não escolhemos |
|-----------|----------|------------------------|
| Scripts soltos em serviços do Roblox | Código espalhado, sem estrutura | Inviável para um jogo com 20+ sistemas |
| Tudo em ReplicatedStorage | Execução mista client/server | `IsServer()` em todo lugar — impossível de testar |
| MVC puro | Não se adapta bem ao modelo de rede do Roblox | Roblox não é uma aplicação web; server é autoridade |

A arquitetura escolhida reflete a natureza do Roblox: **server é a fonte da verdade, client é apenas uma janela para o jogo**.

### 1.3 Objetivos da Arquitetura

1. **Server-Authoritative** — Toda decisão de gameplay é validada no servidor
2. **Modularidade total** — Cada sistema é independente, substituível, testável
3. **Zero retrabalho** — Infraestrutura construída antes dos sistemas de gameplay
4. **Expansão por configuração** — Novo conteúdo = novo entry em config, não novo código
5. **Performance previsível** — Object pooling, region streaming, instâncias controladas
6. **Segurança por design** — RemoteCommand framework valida TUDO antes de executar
7. **Testabilidade** — Serviços podem ser mockados via EventBus e Service Locator

### 1.4 Princípios

#### SOLID

| Princípio | Como aplicamos no projeto |
|-----------|--------------------------|
| **S**ingle Responsibility | Cada Service faz exatamente uma coisa. EconomyService só gerencia recursos. BuildingService só gerencia construções. |
| **O**pen/Closed | Sistemas são abertos para extensão (novo building = nova config) e fechados para modificação (código do BuildingService não muda) |
| **L**iskov Substitution | Todos os Services seguem a mesma interface: `new()`, `init()`, `start()`, `stop()` |
| **I**nterface Segregation | Services exportam apenas o necessário. EconomyService expõe `getBalance()`, `canAfford()`, `spend()`, `add()` — não expõe DataStore interno |
| **D**ependency Inversion | Services dependem de abstrações (EventBus, tipos, interfaces) — nunca de implementações concretas de outros Services |

#### Composition Over Inheritance

NPCs, edifícios e entidades são compostos por **módulos** em vez de herdarem de classes base:

```
WorkerNPC = {
    MovementComponent,
    AnimationComponent,
    ProductionComponent,
    InteractionComponent,
}
```

Vantagem: um NPC pode ter qualquer combinação de comportamentos sem herança rígida.

#### Data Driven Design

**Todo conteúdo do jogo é definido em tabelas de configuração.** O código nunca contém valores hardcoded de custos, taxas, durações, ou nomes:

```
-- Config/Buildings.lua
{
    name = "Farm",
    cost = { Gold = 100, Wood = 50 },
    production = { Food = 10 },
    workersRequired = 1,
    levels = {
        { model = "Farm_L1", productionMult = 1.0, visualStage = 1 },
        { model = "Farm_L2", productionMult = 2.0, visualStage = 2 },
        { model = "Farm_L3", productionMult = 4.0, visualStage = 3 },
    },
    unlocksAtLevel = 1,
    techRequired = nil,
}
```

Para adicionar uma nova Fazenda de Nível 4: adiciona um entry em `levels`. Para adicionar um novo edifício: adiciona uma entrada na tabela `Buildings`. **Zero código novo.**

#### Service Oriented Architecture (SOA)

Cada Service é:
- **Autônomo** — roda independentemente, sem estado compartilhado
- **Comunicável** — via EventBus (pub/sub) e RemoteCommand (request/response)
- **Descoberto** — via Service Locator, nunca via import direto
- **Stateless** (idealmente) — estado é mantido em perfis de jogador, não no Service

#### Modular Design

Cada arquivo tem **uma única responsabilidade** e **um único motivo para mudar**. A estrutura de pastas reflete isso: `Services/Economy/` contém apenas o EconomyService e seus tipos associados.

### 1.5 Escalabilidade

A arquitetura escala em três dimensões:

**Conteúdo:** Config-driven design permite adicionar centenas de edifícios, tecnologias, workers sem modificar uma linha de código dos sistemas.

**Equipe:** Cada sistema está em sua própria pasta. Dois devs podem trabalhar em EconomyService e BuildingService simultaneamente sem conflito de merge.

**Performance:** Object pooling + region streaming + instância única otimizada permite que o jogo rode em dispositivos low-end com centenas de edifícios.

### 1.6 Manutenção

- **Logging centralizado:** Cada operação crítica é logada com nível, timestamp e contexto
- **Config externa:** Parâmetros de gameplay são ajustáveis sem publish
- **Feature flags:** Sistemas podem ser ligados/desligados remotamente
- **Migrations:** Dados de jogador têm versão e migração automática

### 1.7 Baixo Acoplamento

Services **nunca** importam outros Services diretamente. Toda comunicação inter-service ocorre via:

1. **EventBus** — para notificações (recurso mudou, construção concluída)
2. **Service Locator** — para chamadas diretas quando necessário (raro, apenas em Managers)

### 1.8 Alta Coesão

Cada módulo contém **tudo o que precisa** para sua responsabilidade e **nada mais**:
- EconomyService contém lógica de economia, seus tipos internos, suas validações
- ProgressionService contém lógica de progressão, cálculo de XP, unlocks

---

## 2. Estrutura do Explorer

```
GaK (Lugar)
│
├── Workspace
│   ├── Terrain
│   ├── Kingdoms
│   │   └── [player_UserId]
│   │       ├── Buildings
│   │       │   ├── [buildingId] (Model)
│   │       │   │   ├── Base (Part)
│   │       │   │   ├── Structure (MeshPart)
│   │       │   │   └── Effects (Folder)
│   │       │   └── ...
│   │       ├── Workers
│   │       │   └── [workerId] (Model)
│   │       └── Props (Folder)
│   ├── NPCs
│   ├── Effects
│   ├── Camera
│   └── ServerScriptService (via atributo)
│
├── ServerScriptService
│   ├── Bootstrap
│   │   ├── ServerBootstrapper (Script)
│   │   └── InitOrder (ModuleScript)
│   ├── Services
│   │   ├── Core
│   │   │   ├── LoggerService (ModuleScript)
│   │   │   ├── EventBusService (ModuleScript)
│   │   │   ├── RemoteCommandService (ModuleScript)
│   │   │   ├── DataStoreService (ModuleScript)
│   │   │   └── GameConfigService (ModuleScript)
│   │   ├── Player
│   │   │   ├── PlayerSessionService (ModuleScript)
│   │   │   └── ProfileService (ModuleScript)
│   │   ├── Economy
│   │   │   └── EconomyService (ModuleScript)
│   │   ├── Kingdom
│   │   │   ├── BuildingService (ModuleScript)
│   │   │   ├── ProductionService (ModuleScript)
│   │   │   ├── WorkerService (ModuleScript)
│   │   │   └── TechTreeService (ModuleScript)
│   │   ├── Progression
│   │   │   └── ProgressionService (ModuleScript)
│   │   ├── Multiplayer
│   │   │   ├── VisitService (ModuleScript)
│   │   │   └── EventService (ModuleScript)
│   │   └── Endgame
│   │       ├── ExpeditionService (ModuleScript)
│   │       ├── RaidService (ModuleScript)
│   │       └── DefenseService (ModuleScript)
│   ├── Managers
│   │   ├── KingdomManager (ModuleScript)
│   │   └── NPCManager (ModuleScript)
│   ├── Systems
│   │   ├── ProductionSystem (ModuleScript)
│   │   └── OfflineSystem (ModuleScript)
│   └── Commands
│       └── AdminCommands (ModuleScript)
│
├── ServerStorage
│   ├── Templates
│   │   ├── Buildings
│   │   ├── Workers
│   │   └── Effects
│   └── Pools
│       └── NPCPool (ObjectValue)
│
├── ReplicatedStorage
│   ├── Shared
│   │   ├── Types (ModuleScript)
│   │   ├── Enums (ModuleScript)
│   │   ├── Config
│   │   │   ├── GameConfig (ModuleScript)
│   │   │   ├── Buildings (ModuleScript)
│   │   │   ├── Resources (ModuleScript)
│   │   │   ├── Workers (ModuleScript)
│   │   │   ├── TechTree (ModuleScript)
│   │   │   └── Progression (ModuleScript)
│   │   ├── Util
│   │   │   ├── MathUtil (ModuleScript)
│   │   │   ├── TableUtil (ModuleScript)
│   │   │   ├── TimeUtil (ModuleScript)
│   │   │   └── InstanceUtil (ModuleScript)
│   │   ├── Remote
│   │   │   ├── RemoteEvents (ModuleScript)
│   │   │   └── RemoteFunctions (ModuleScript)
│   │   └── DI
│   │       └── ServiceLocator (ModuleScript)
│   └── Assets
│       ├── Models
│       ├── Textures
│       ├── Sounds
│       └── Animations
│
├── StarterPlayer
│   └── StarterPlayerScripts
│       ├── Bootstrap
│       │   └── ClientBootstrapper (Script)
│       ├── Controllers
│       │   ├── UIController (ModuleScript)
│       │   ├── CameraController (ModuleScript)
│       │   └── InputController (ModuleScript)
│       ├── UI
│       │   ├── HUD
│       │   │   ├── ResourceBar (ModuleScript)
│       │   │   ├── XPBar (ModuleScript)
│       │   │   └── Notification (ModuleScript)
│       │   ├── Menus
│       │   │   ├── BuildMenu (ModuleScript)
│       │   │   ├── TechTreeMenu (ModuleScript)
│       │   │   ├── KingdomMenu (ModuleScript)
│       │   │   └── VisitMenu (ModuleScript)
│       │   └── Components
│       │       ├── Button (ModuleScript)
│       │       ├── Tooltip (ModuleScript)
│       │       └── ProgressBar (ModuleScript)
│       └── Modules
│           ├── RemoteHandler (ModuleScript)
│           └── EffectManager (ModuleScript)
│
├── StarterGui
│   └── MainUI (ScreenGui)
│       ├── HUD (Frame)
│       ├── BuildMenu (Frame)
│       ├── TechTreeMenu (Frame)
│       └── KingdomMenu (Frame)
│
└── StarterPack
    └── (opcional — tools iniciais)
```

---

## 3. Responsabilidade de Cada Pasta

### 3.1 Workspace

Mundo físico do jogo. Contém apenas instâncias renderizáveis.

| Pasta | Responsabilidade |
|-------|-----------------|
| `Terrain` | Terreno base do jogo |
| `Kingdoms` | Contém todos os reinos dos jogadores ativos. Subpastas por `player_UserId` |
| `Kingdoms/[id]/Buildings` | Modelos 3D dos edifícios do jogador |
| `Kingdoms/[id]/Workers` | Modelos 3D dos NPCs trabalhadores |
| `NPCs` | NPCs não-jogadores (visitantes, event NPCs) |
| `Effects` | Efeitos visuais (partículas, beams) |
| `Camera` | Câmera do jogador atual |

**Regras:**
- NUNCA colocar scripts aqui (exceto Camera via StarterPlayer)
- NUNCA colocar ModuleScripts aqui
- Apenas instâncias visíveis/físicas

### 3.2 ServerScriptService

**Autoridade do jogo.** Todo código que processa lógica de gameplay, valida ações, e toma decisões está aqui.

| Pasta | Responsabilidade |
|-------|-----------------|
| `Bootstrap` | Script de inicialização do servidor. Ordem de carregamento explícita |
| `Services/Core` | Serviços de infraestrutura (Logger, EventBus, DataStore, RemoteCommand, GameConfig) |
| `Services/Player` | Gerenciamento de sessão do jogador e profile DataStore |
| `Services/Economy` | Sistema de recursos: saldo, transações, validação |
| `Services/Kingdom` | Construção, produção, workers e tecnologia |
| `Services/Progression` | XP, níveis, marcos e desbloqueios |
| `Services/Multiplayer` | Visitas entre jogadores e eventos globais |
| `Services/Endgame` | Expedições, raids, defesa (pós-MVP) |
| `Managers` | Orquestradores que coordenam múltiplos Services |
| `Systems` | Loops de processamento contínuo (produção tick, offline calc) |
| `Commands` | Comandos de administração para debug |

**Regras:**
- Services NUNCA importam outros Services diretamente
- Services NUNCA importam código do Client
- Services SEMPRE validam dados recebidos do Client

### 3.3 ServerStorage

**Armazenamento de templates e pools.** Não executável. Apenas armazena modelos e instâncias para clonagem.

| Pasta | Responsabilidade |
|-------|-----------------|
| `Templates/Buildings` | Modelos base de cada edifício (L1, L2, L3) |
| `Templates/Workers` | Modelos base de cada tipo de NPC |
| `Templates/Effects` | Modelos de efeitos (construção, upgrade, coleta) |
| `Pools` | Object pools pré-criadas para reuso de instâncias |

**Regras:**
- NENHUM script aqui
- Apenas modelos, parts, e objetos de dados

### 3.4 ReplicatedStorage

**Ponte entre Server e Client.** Contém apenas código e assets compartilhados.

| Pasta | Responsabilidade |
|-------|-----------------|
| `Shared/Types` | Definições de tipos Luau (`export type`) |
| `Shared/Enums` | Enumerações do jogo (ResourceType, BuildingType, etc.) |
| `Shared/Config` | Tabelas de configuração de gameplay (data driven) |
| `Shared/Util` | Funções utilitárias puras (sem estado, sem side effects) |
| `Shared/Remote` | Definição e criação de RemoteEvents/RemoteFunctions |
| `Shared/DI` | Service Locator (registro e descoberta de serviços) |
| `Assets` | Modelos, texturas, sons, animações |

**Regras:**
- Código AQUI roda tanto no Server quanto no Client
- NUNCA colocar lógica de gameplay aqui
- NUNCA colocar estado mutável aqui
- Apenas tipos, config, utilitários puros, definições

### 3.5 StarterPlayer > StarterPlayerScripts

**Cliente do jogo.** Tudo que roda apenas no computador do jogador.

| Pasta | Responsabilidade |
|-------|-----------------|
| `Bootstrap` | Script de inicialização do cliente |
| `Controllers` | Gerenciadores de input, câmera, UI principal |
| `UI` | Lógica de interface do usuário (HUD, menus, componentes) |
| `Modules` | Utilitários do cliente (RemoteHandler, EffectManager) |

**Regras:**
- NUNCA confiar em dados do cliente para lógica de gameplay
- NUNCA modificar dados de jogo (recursos, propriedades) — apenas exibir
- SEMPRE usar RemoteHandler para comunicar ações ao servidor

### 3.6 StarterGui

**Interface visual.** Contém apenas os objetos de UI (ScreenGui, Frame, TextLabel, etc.).

**Regras:**
- NENHUM script aqui — scripts ficam em StarterPlayerScripts/UI
- Apenas estrutura visual: frames, botões, imagens, textos

### 3.7 StarterPack

Itens iniciais dados ao jogador ao spawnar. Opcional para este projeto.

---

## 4. Ciclo de Inicialização

### 4.1 Inicialização do Servidor

```
[Server Start]
      │
      ▼
┌──────────────────────────────────────────┐
│ 1. ServerBootstrapper.lua executa        │
│    (Script em ServerScriptService)       │
└──────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────┐
│ 2. InitOrder.lua define sequência explícita   │
│    Ordem:                                     │
│    2.1 LoggerService.new()                    │
│    2.2 EventBusService.new()                  │
│    2.3 RemoteCommandService.new()             │
│    2.4 GameConfigService.new()                │
│    2.5 DataStoreService.new()                 │
│    2.6 PlayerSessionService.new()             │
│    2.7 EconomyService.new()                   │
│    2.8 BuildingService.new()                  │
│    2.9 ProductionService.new()                │
│    2.10 WorkerService.new()                   │
│    2.11 ProgressionService.new()              │
│    2.12 TechTreeService.new()                 │
└──────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────┐
│ 3. Para cada Service:                        │
│    service:init(config) → configuração       │
│    service:start() → começa a operar         │
│    Registrar no ServiceLocator               │
└─────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────┐
│ 4. Systems iniciam loops:                    │
│    ProductionSystem:start()                  │
│    OfflineSystem:ready()                     │
└─────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────┐
│ 5. Servidor pronto.                         │
│    EventBus:fire("ServerReady")             │
│    Game.Players.PlayerAdded conectado       │
└─────────────────────────────────────────────┘
```

### 4.2 Jogador Entra no Servidor

```
[Player Join]
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 1. PlayerAdded disparado                         │
│    PlayerSessionService:onPlayerAdded(player)    │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 2. ProfileService:loadProfile(player)            │
│    └── DataStore:GetAsync(playerKey)            │
│    └── Se não existir: criar profile padrão      │
│    └── Se existir: validar versão, migrar se nec.│
│    └── Profile armazenada em cache de memória    │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 3. KingdomManager:loadKingdom(player, profile)   │
│    └── Carregar edifícios do profile             │
│    └── Instanciar modelos no Workspace/Kingdoms  │
│    └── Spawnar workers ativos                    │
│    └── Calcular produção offline                 │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 4. PlayerCharacterAdded (opcional)               │
│    └── Posicionar personagem no reino            │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 5. EventBus:fire("PlayerLoaded", player, profile)│
│    └── EconomyService reage: envia saldo         │
│    └── ProgressionService reage: envia nível     │
│    └── BuildingService reage: envia estado const.│
└──────────────────────────────────────────────────┘
```

### 4.3 Inicialização do Cliente

```
[Cliente Inicia]
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 1. ClientBootstrapper.lua executa                │
│    (Script em StarterPlayerScripts)              │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 2. RemoteHandler:init()                          │
│    └── Conectar RemoteEvents aos handlers locais │
│    └── Registrar callbacks do servidor           │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 3. Controllers:                                  │
│    UIController:init() → preparar UI             │
│    CameraController:init() → configurar câmera   │
│    InputController:init() → registrar inputs     │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 4. UI Carregada (inicialmente oculta)            │
│    └── ResourceBar aguardando dados do servidor  │
│    └── HUD oculto até "PlayerLoaded"             │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 5. Servidor envia "PlayerLoaded" via RemoteEvent │
│    └── UI exibe recursos, nível, edifícios       │
│    └── HUD visível                               │
│    └── Input habilitado                          │
│    └── Gameplay começa                           │
└──────────────────────────────────────────────────┘
```

### 4.4 Loop de Produção (Runtime)

```
[ProductionSystem Tick]
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 1. A cada N segundos (configurável):             │
│    └── Para cada jogador online:                 │
│        ├── Calcular produção por edifício        │
│        ├── Aplicar multiplicadores (workers)     │
│        ├── Aplicar boosts (tech, eventos)        │
│        └── Adicionar recursos ao EconomyService  │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 2. EventBus:fire("ResourcesProduced", player)    │
│    └── EconomyService atualiza saldo em memória  │
│    └── RemoteEvent envia atualização ao cliente  │
│    └── UI atualiza resource bars                 │
└──────────────────────────────────────────────────┘
```

### 4.5 Salvamento (Runtime)

```
[AutoSave Cycle]
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 1. ProfileService:enqueueSave(player)            │
│    └── Adiciona à fila de saves (debounce 30s)  │
│    └── Se fila vazia: agendar próximo save       │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 2. Quando executa:                               │
│    └── Coletar estado atual:                     │
│        ├── EconomyService:getProfile(player)     │
│        ├── BuildingService:getProfile(player)    │
│        ├── ProgressionService:getProfile(player) │
│        └── WorkerService:getProfile(player)      │
│    └── Montar tabela completa de profile         │
│    └── Incrementar DataVersion                   │
│    └── Atualizar lastSaveTimestamp               │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 3. DataStore:SetAsync(playerKey, profile)        │
│    └── Retry com exponential backoff (max 3x)   │
│    └── Se falhar: log de erro, manter em cache   │
│    └── Se sucesso: limpar dirty flag             │
└──────────────────────────────────────────────────┘
```

### 4.6 Jogador Sai

```
[Player Leave]
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 1. PlayerRemoving disparado                      │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 2. PlayerSessionService:onPlayerRemoving(player) │
│    └── Parar sistemas relacionados               │
│    └── Salvar profile imediatamente (flush)      │
│    └── Remover reinos do Workspace               │
│    └── Liberar NPCs da pool                      │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 3. DataStore:SetAsync(playerKey, profile)        │
│    └── Sincrono (BindToClose se server parando)  │
└──────────────────────────────────────────────────┘
      │
      ▼
┌──────────────────────────────────────────────────┐
│ 4. EventBus:fire("PlayerUnloaded", player)       │
│    └── Services limpa dados do jogador           │
│    └── Profile removido do cache de memória     │
└──────────────────────────────────────────────────┘
```

---

## 5. Comunicação Entre Sistemas

### 5.1 Quem Pode Acessar Quem

```
                        ┌──────────┐
                        │  CLIENT  │
                        │ (Starter) │
                        └────┬─────┘
                             │ Apenas via RemoteCommand
                             │ (nunca importa Server)
                             ▼
                     ┌───────────────┐
                     │ RemoteCommand │
                     │  (validação)  │
                     └───────┬───────┘
                             │
                    ┌────────▼────────┐
                    │  SERVER LAYER   │
                    │  (autoridade)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   EventBus      │
                    │  (pub/sub)      │
                    └─────────────────┘

    ┌────────────┐    ┌────────────┐    ┌────────────┐
    │ Service A  │◄───┤ EventBus   ├───►│ Service B  │
    │            │    │ (pub/sub)  │    │            │
    └────────────┘    └────────────┘    └────────────┘

    ┌────────────┐                      ┌────────────┐
    │ Manager X  │──── (importa) ──────►│ Service A  │
    │            │                      │            │
    └────────────┘                      └────────────┘
    (Manager pode importar Service)
    (Service NUNCA importa Manager)

    ┌────────────┐                      ┌────────────┐
    │ Service A  │──── (importa) ──────►│ Shared     │
    │ Service B  │                      │ (Types,    │
    │ Manager X  │                      │  Config,   │
    │ Client     │                      │  Util)     │
    └────────────┘                      └────────────┘
    (TODO mundo pode importar Shared)
```

### 5.2 Regras de Acesso

| Quem | Pode acessar | Não pode acessar |
|------|-------------|------------------|
| **Service** | Shared (types, config, util), ServiceLocator | Outro Service diretamente, Client, ServerStorage |
| **Manager** | Services (diretamente, via ServiceLocator), Shared | Client, ServerStorage |
| **System** | Services (via ServiceLocator), Managers, Shared | Client, ServerStorage |
| **Client Controller** | Shared, RemoteHandler (que chama RemoteCommand) | Services, Managers, Systems |
| **Client UI** | Shared | Services, Managers, Systems, Server |
| **Shared (qualquer módulo)** | NADA de Server/Client | Server, Client (apenas tipos puros) |

### 5.3 Como Evitar Dependências Circulares

**Estratégia 1 — Direção única de dependência**
```
Server → Shared → Client
```
Nunca no sentido oposto. Isso elimina 100% das dependências circulares entre camadas.

**Estratégia 2 — EventBus em vez de import direto**
```
EconomyService ──fogo──► EventBus ──escuta──► BuildingService
```
Em vez de:
```
BuildingService ──importa──► EconomyService ──importa──► BuildingService (CIRCULAR!)
```

**Estratégia 3 — ServiceLocator para chamadas request-response**
```
ProductionSystem ──get("EconomyService")──► EconomyService
```
Em vez de:
```
ProductionSystem ──require(path)──► EconomyService
```

**Estratégia 4 — Managers como camada de orquestração**
Managers podem importar Services, mas Services nunca importam Managers. Isso cria uma hierarquia clara:
```
Systems → Managers → Services → Shared
```

### 5.4 Exemplo de Fluxo: Jogador Constrói um Edifício

```
[Cliente]
  1. Jogador clica "Construir Fazenda" no BuildMenu
  2. UIController valida visualmente (prévia do edifício)
  3. RemoteHandler:send("BuildBuilding", { buildingType = "Farm", position = Vector3 })
         │
         ▼  (via RemoteEvent/RemoteFunction)
[Servidor — RemoteCommandService]
  4. Rate limit check: jogador não excedeu limite de ações/segundo?
  5. Sanitização: buildingType é válido? position é válida?
  6. Autorização: jogador tem nível para desbloquear Farm?
         │
         ▼
[Servidor — EconomyService]
  7. canAfford(player, "Farm") → verifica se tem Gold >= 100, Wood >= 50
  8. Se não: retorna erro "Recursos insuficientes"
  9. Se sim: spend(player, { Gold = 100, Wood = 50 })
         │
         ▼
[Servidor — BuildingService]
  10. build(player, "Farm", position)
  11. Valida: posição não está ocupada? dentro dos limites do reino?
  12. Cria instância do modelo no Workspace/Kingdoms/[id]/Buildings
  13. Registra no perfil do jogador
         │
         ▼
[Servidor — EventBus]
  14. EventBus:fire("BuildingBuilt", player, buildingData)
         │
         ▼
[Servidor — ProductionService] (ouvinte)
  15. Recalcula produção do jogador (nova fazenda = +10 food/tick)
         │
         ▼
[Servidor — RemoteEvent → Cliente]
  16. Atualiza UI: novo saldo de recursos, novo edifício visível
  17. Efeito visual de construção (partículas, animação)
```

---

## 6. Estratégia para Expansão Futura

### 6.1 Expansão de Conteúdo (Data Driven)

Para adicionar um novo edifício ao jogo:

1. Abrir `ReplicatedStorage/Shared/Config/Buildings.lua`
2. Adicionar um entry na tabela de configuração:

```lua
-- Antes de adicionar
-- Depois de adicionar (exemplo conceitual)
{
    name = "Blacksmith",
    cost = { Gold = 500, Wood = 200, Stone = 100 },
    production = { Weapons = 5 },
    workersRequired = 2,
    levels = {
        { model = "Blacksmith_L1", productionMult = 1.0 },
        { model = "Blacksmith_L2", productionMult = 2.5 },
        { model = "Blacksmith_L3", productionMult = 5.0 },
    },
    unlocksAtLevel = 10,
    techRequired = "Metallurgy",
    category = "Production",
}
```

3. Colocar os modelos (`Blacksmith_L1`, `Blacksmith_L2`, `Blacksmith_L3`) em `ServerStorage/Templates/Buildings/`
4. **Nenhuma linha de código nos systems precisa ser alterada.**

Isso se aplica a:
- Edifícios (Buildings.lua)
- Recursos (Resources.lua)
- Trabalhadores (Workers.lua)
- Tecnologias (TechTree.lua)
- Níveis de progressão (Progression.lua)
- Eventos (Events.lua)

### 6.2 Expansão de Sistemas

Para adicionar um novo sistema de gameplay:

1. Criar pasta em `ServerScriptService/Services/[NovoSistema]/`
2. Criar ModuleScript seguindo o padrão de Service (interface `new`, `init`, `start`, `stop`)
3. Adicionar ao `InitOrder.lua` na posição correta
4. Registrar no ServiceLocator
5. Se precisar reagir a eventos, inscrever-se no EventBus
6. Se precisar expor dados ao cliente, criar RemoteEvents em `Shared/Remote/`

### 6.3 Expansão Multiplayer

- **Visitas:** VisitService carrega snapshot do reino do jogador visitado (mesh fundida, sem workers ativos)
- **Eventos globais:** EventService escuta MemoryStore para coordenar entre servidores
- **Guerras:** WarService usa instâncias separadas (se a arquitetura do Roblox permitir) ou simulação baseada em estatísticas

### 6.4 Expansão de Performance

- **LOD:** Edifícios distantes da câmera trocam para modelos low-poly
- **Region Streaming:** Apenas partes dentro do campo de visão são carregadas
- **Worker Pooling:** NPCs são reciclados em vez de destruídos/criados
- **Batch Updates:** Múltiplas mudanças de recursos são enviadas em um único RemoteEvent

---

## 7. Como Adicionar um Novo Sistema

### Guia Passo a Passo

**Exemplo:** Adicionar um sistema de "Achievements"

#### Passo 1: Criar o Service

```
ServerScriptService/Services/
  └── Social/
      └── AchievementService (ModuleScript)
```

#### Passo 2: Seguir a Interface Padrão

```lua
-- Estrutura obrigatória de TODO Service:
local AchievementService = {}
AchievementService.__index = AchievementService

function AchievementService.new(serviceLocator)
    local self = setmetatable({}, AchievementService)
    self.serviceLocator = serviceLocator
    self.logger = serviceLocator:get("Logger")
    self.eventBus = serviceLocator:get("EventBus")
    return self
end

function AchievementService:init()
    -- Configurar listeners do EventBus
    self.eventBus:on("BuildingBuilt", function(player, data)
        self:checkBuildingAchievements(player, data)
    end)
end

function AchievementService:start()
    self.logger:info("AchievementService started")
end

function AchievementService:stop()
    -- Limpeza
end

return AchievementService
```

#### Passo 3: Registrar no ServiceLocator

No Bootstrap/InitOrder.lua, adicionar na ordem correta:
```lua
services.AchievementService = AchievementService.new(serviceLocator)
services.AchievementService:init()
```

#### Passo 4: Configurar Dados

Adicionar config em `ReplicatedStorage/Shared/Config/Achievements.lua`:
```lua
return {
    {
        id = "first_building",
        name = "First Steps",
        condition = { type = "buildings_built", count = 1 },
        rewards = { Gold = 100 },
    },
    {
        id = "millionaire",
        name = "Millionaire",
        condition = { type = "gold_accumulated", amount = 1000000 },
        rewards = { Gems = 50 },
    },
}
```

#### Passo 5: Remotos (se necessário)

Em `Shared/Remote/RemoteEvents.lua`, adicionar:
```lua
remoteEvents.AchievementUnlocked = Instance.new("RemoteEvent")
remoteEvents.AchievementUnlocked.Name = "AchievementUnlocked"
remoteEvents.AchievementUnlocked.Parent = remoteFolder
```

#### Passo 6: UI (se necessário)

Em `StarterPlayer/StarterPlayerScripts/UI/Menus/`:
```
AchievementMenu (ModuleScript)
```

### Checklist para Novo Sistema

- [ ] Segue interface `new → init → start → stop`?
- [ ] Usa EventBus para comunicação, não import direto?
- [ ] Config está em Shared, não hardcoded?
- [ ] RemoteEvents estão definidos em Shared/Remote?
- [ ] Todos os parâmetros de Remote são validados no servidor?
- [ ] Tem rate limit?
- [ ] Salva/restaura estado via ProfileService?
- [ ] Logs implementados?
- [ ] Registrado em InitOrder.lua?

---

## 8. Convenções de Nomenclatura

### 8.1 Pastas

| Padrão | Exemplo | Exceção |
|--------|---------|---------|
| **PascalCase** para pastas de sistema | `Services/`, `Managers/`, `Controllers/` | — |
| **PascalCase** para categorias | `Economy/`, `Kingdom/`, `Multiplayer/` | — |
| **Plural** para pastas de coleção | `Services/`, `Systems/`, `Commands/` | — |
| **Singular** para pastas de entidade única | `Bootstrap/`, `HUD/` | — |
| Letras maiúsculas para pastas técnicas | `Shared/Types`, `Shared/Remote`, `Shared/Config` | — |

### 8.2 Arquivos

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| **Service** | PascalCase + `Service` sufixo | `EconomyService.lua`, `BuildingService.lua` |
| **Manager** | PascalCase + `Manager` sufixo | `KingdomManager.lua` |
| **System** | PascalCase + `System` sufixo | `ProductionSystem.lua` |
| **Controller** | PascalCase + `Controller` sufixo | `UIController.lua` |
| **Config** | PascalCase, plural | `Buildings.lua`, `Resources.lua` |
| **Type** | PascalCase | `Types.lua` |
| **Enum** | PascalCase | `Enums.lua` |
| **Util** | PascalCase + `Util` sufixo | `MathUtil.lua`, `TableUtil.lua` |
| **Remote** | PascalCase | `RemoteEvents.lua`, `RemoteFunctions.lua` |
| **UI Component** | PascalCase | `ResourceBar.lua`, `BuildMenu.lua` |
| **Bootstrapper** | PascalCase | `ServerBootstrapper.lua`, `ClientBootstrapper.lua` |

### 8.3 Variáveis e Funções

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| **Variáveis locais** | camelCase | `local playerData`, `local isReady` |
| **Funções** | camelCase | `function getBalance()`, `function canAfford()` |
| **Parâmetros** | camelCase | `function spend(playerId, cost)` |
| **Propriedades da tabela** | camelCase | `self.playerData`, `self.isInitialized` |
| **Eventos do EventBus** | PascalCase com prefixo on | `onBuildingBuilt`, `onResourceChanged` |
| **Constantes** | UPPER_SNAKE_CASE | `local MAX_OFFLINE_HOURS = 8` |

### 8.4 RemoteEvents/RemoteFunctions

| Padrão | Exemplo |
|--------|---------|
| Nome do RemoteEvent: verbo no Presente + contexto | `BuildingRequest`, `ResourceCollect` |
| Callback no servidor: `on` + Nome do Remote | `onBuildingRequest(player, args)` |
| Fire do cliente: `fire` + Nome do Evento | `fireResourcesUpdated(player, resources)` |

### 8.5 IDs e Identificadores

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| IDs de config | snake_case | `"stone_mine"`, `"woodcutter_hut"` |
| IDs de instância | UUID curto | `"bld_f3a2c1"` (edifício), `"wkr_7b1e9"` (worker) |

---

## 9. Organização dos Arquivos

### 9.1 Cada Arquivo Tem Uma Única Responsabilidade

```
BOM:
  EconomyService.lua → gerencia recursos (APENAS recursos)
  BuildingService.lua → gerencia edifícios (APENAS edifícios)
  ProductionService.lua → gerencia produção (APENAS produção)

RUIM:
  EconomyService.lua → gerencia recursos + produção + workers (3 responsabilidades)
```

### 9.2 Tamanho Máximo de Arquivo

- **Services:** máximo 300 linhas (se passar, extrair lógica para módulos auxiliares)
- **Config:** máximo 200 linhas por arquivo (separar por categoria)
- **Managers:** máximo 200 linhas
- **UI Components:** máximo 150 linhas
- **Utils:** máximo 100 linhas por utilitário

### 9.3 Estrutura Interna de um Service

```lua
-- 1. TIPO DE MODULO
local ModuleName = {}
ModuleName.__index = ModuleName

-- 2. DEPENDENCIAS (imports)
--    Apenas Shared e ServiceLocator
local Types = require(script.Parent.Parent.Shared.Types)
local ServiceLocator = require(script.Parent.Parent.Shared.DI.ServiceLocator)

-- 3. CONSTANTES DO MODULO
local DEFAULT_VALUE = 0
local MAX_RETRY = 3

-- 4. ESTADO INTERNO (self.*)
--    (definido no construtor)

-- 5. CONSTRUTOR
function ModuleName.new(serviceLocator)
    -- ...
end

-- 6. CICLO DE VIDA
function ModuleName:init()
    -- ...
end

function ModuleName:start()
    -- ...
end

function ModuleName:stop()
    -- ...
end

-- 7. MÉTODOS PÚBLICOS
function ModuleName:publicMethod()
    -- ...
end

-- 8. MÉTODOS PRIVADOS
local function privateHelper()
    -- ...
end

-- 9. LISTENERS DE EVENTOS
function ModuleName:onEvent(data)
    -- ...
end

-- 10. EXPORT
return ModuleName
```

### 9.4 Estrutura Interna de um Config

```lua
-- 1. TIPO (documentação das entradas)
-- 2. TABELA DE DADOS
-- 3. VALIDAÇÃO (se aplicável, opcional)
-- 4. EXPORT
return {
    -- dados organizados por categoria
}
```

---

## 10. Padrões Utilizados

### 10.1 Service Locator

**Problema:** Services precisam se comunicar, mas import direto cria acoplamento.

**Solução:** `ServiceLocator` registra cada Service por nome. Qualquer módulo pode solicitar um Service pelo nome.

```lua
-- Registro (Bootstrapper)
ServiceLocator:register("Economy", EconomyService.new(ServiceLocator))

-- Uso (qualquer módulo)
local economy = ServiceLocator:get("Economy")
economy:spend(player, { Gold = 100 })
```

**Onde usar:** Todo Service registra no Bootstrapper. Managers e Systems usam `ServiceLocator:get()` para acessar Services.

**Onde NÃO usar:** Shared modules (Types, Config, Util) nunca usam ServiceLocator.

### 10.2 Event Bus (Pub/Sub)

**Problema:** Services precisam reagir a mudanças em outros Services sem acoplamento.

**Solução:** EventBus centraliza eventos. Services publicam eventos quando mudam de estado. Outros Services se inscrevem para receber notificações.

```lua
-- Publicar
EventBus:fire("ResourceChanged", { player = player, resource = "Gold", value = 500 })

-- Inscrever
EventBus:on("ResourceChanged", function(data)
    -- reagir à mudança
end)
```

**Onde usar:** Toda comunicação inter-service que é "avisar que algo aconteceu".

**Onde NÃO usar:** Chamadas request-response (use ServiceLocator para essas). Chamadas cliente-servidor (use RemoteCommand).

### 10.3 Remote Command (RemoteEvent Framework)

**Problema:** RemoteEvents brutos são inseguros. Cliente pode chamar com qualquer parâmetro.

**Solução:** Todo RemoteEvent passa por um framework que aplica **rate limit** → **sanitização** → **autorização** → **execução**.

```lua
-- Definição
RemoteCommand:register("BuildBuilding", {
    rateLimit = 5, -- max 5 chamadas por segundo
    sanitize = function(args)
        assert(typeof(args.buildingType) == "string")
        assert(typeof(args.position) == "Vector3")
        return args
    end,
    authorize = function(player, args)
        local level = ServiceLocator:get("Progression"):getLevel(player)
        local config = require(Config.Buildings)[args.buildingType]
        return level >= config.unlocksAtLevel
    end,
    execute = function(player, args)
        ServiceLocator:get("Building"):build(player, args.buildingType, args.position)
    end,
})
```

**Onde usar:** TODA comunicação cliente → servidor.

**Onde NÃO usar:** Comunicação servidor → cliente (use RemoteEvent direto, já que servidor é confiável).

### 10.4 Profile Pattern (DataStore)

**Problema:** DataStore do Roblox tem limites restritivos (60 req/min, 4MB/key).

**Solução:** Padrão de profile com cache em memória + fila de saves + versionamento.

```
[Perfil do Jogador]
  ├── _version: number
  ├── _lastSaveTimestamp: number
  ├── _lastLoginTimestamp: number
  ├── economy: { gold, wood, stone, food }
  ├── buildings: { { id, type, level, position }[] }
  ├── workers: { { id, type, assignedTo }[] }
  ├── progression: { level, xp }
  ├── techTree: { researched: string[] }
  └── metadata: { firstLogin, totalPlaytime, ... }
```

**Onde usar:** Todo dado persistente de jogador.

**Onde NÃO usar:** Dados temporários (use memória apenas). Dados globais (use DataStore separado sem profile).

### 10.5 Object Pool

**Problema:** Criar e destruir instâncias Roblox constantemente causa GC pressure e lag.

**Solução:** Pool de instâncias pré-criadas. "Pegar" da pool ativa a instância. "Devolver" à pool a desativa.

```lua
-- Pegar worker da pool
local worker = NPCPool:get()
worker.Parent = Workspace.Kingdoms[playerId].Workers
worker:SetAttribute("Active", true)

-- Devolver worker à pool
NPCPool:return(worker)
worker.Parent = ServerStorage.Pools.NPCPool
worker:SetAttribute("Active", false)
```

**Onde usar:** NPCs, efeitos visuais, partículas, qualquer instância criada/destruída frequentemente.

**Onde NÃO usar:** Instâncias permanentes (edifícios — eles não são destruídos/criados com frequência).

### 10.6 Data Driven Configuration

**Problema:** Valores hardcoded (custos, taxas, durações) exigem publish para qualquer ajuste.

**Solução:** Toda configuração de gameplay em tabelas em `Shared/Config/`. Alterar um valor = alterar a tabela (ou via GameConfig remoto).

```lua
-- Config/Buildings.lua
return {
    Farm = {
        cost = { Gold = 100, Wood = 50 },
        production = { Food = 10 },
        -- ...
    },
    Mine = {
        cost = { Gold = 200, Stone = 100 },
        production = { Stone = 8 },
        -- ...
    },
}
```

**Onde usar:** Tudo que é "conteúdo": edifícios, tecnologias, workers, recursos, níveis, custos, taxas.

**Onde NÃO usar:** Constantes técnicas (timeouts, limites de DataStore, configurações de pool).

### 10.7 Bootstrapper Pattern

**Problema:** Inicialização em ordem aleatória causa erros de dependência não resolvida.

**Solução:** Script único que gerencia toda a inicialização em ordem explícita.

```lua
-- InitOrder.lua
return {
    { name = "Logger", module = "Core/LoggerService" },
    { name = "EventBus", module = "Core/EventBusService" },
    { name = "RemoteCommand", module = "Core/RemoteCommandService" },
    { name = "GameConfig", module = "Core/GameConfigService" },
    { name = "DataStore", module = "Core/DataStoreService" },
    { name = "PlayerSession", module = "Player/PlayerSessionService" },
    -- ...
}
```

**Onde usar:** Único — no ServerBootstrapper e ClientBootstrapper.

**Onde NÃO usar:** Em qualquer outro lugar.

### 10.8 Manager-Service Hierarchy

**Problema:** Services são granulares demais para orquestrar operações complexas.

**Solução:** Managers ficam acima dos Services e coordenam operações multi-service.

```
KingdomManager
  ├── usa EconomyService (para custos)
  ├── usa BuildingService (para construir)
  ├── usa WorkerService (para atribuir workers)
  └── usa ProgressionService (para XP ao construir)
```

**Onde usar:** Operações que envolvem múltiplos Services: construir edifício (custa recurso + cria instância + dá XP).

**Onde NÃO usar:** Operações de um único Service: transferir recursos (só EconomyService).

---

## 11. Diagrama da Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SERVIDOR ROblox                                    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        ServerScriptService                          │    │
│  │                                                                      │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌──────────────────────┐  │    │
│  │  │   Bootstrapper  │  │   InitOrder    │  │   ServerBootstrapper │  │    │
│  │  │   (Script)      │  │   (Module)     │  │   (lógica de init)   │  │    │
│  │  └────────────────┘  └────────────────┘  └──────────────────────┘  │    │
│  │                                                                      │    │
│  │  ┌────────────────────────────────────────────────────────────────┐  │    │
│  │  │                         SERVICES                               │  │    │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │  │    │
│  │  │  │  Core     │ │  Player  │ │ Economy  │ │ Kingdom  │          │  │    │
│  │  │  │ ┌──────┐  │ │ ┌──────┐ │ │ ┌──────┐ │ │ ┌──────┐ │          │  │    │
│  │  │  │ │Logger│  │ │ │Player│ │ │ │Econom│ │ │ │Build │ │          │  │    │
│  │  │  │ │Event │  │ │ │Sess. │ │ │ │ySvc  │ │ │ │ingSvc│ │          │  │    │
│  │  │  │ │Bus   │  │ │ │Profile│ │ │ └──────┘ │ │ │Prod. │ │          │  │    │
│  │  │  │ │Remote│  │ │ └──────┘ │ │           │ │ │Svc   │ │          │  │    │
│  │  │  │ │Cmd   │  │ │          │ │           │ │ │Worker│ │          │  │    │
│  │  │  │ │Data  │  │ │          │ │           │ │ │Svc   │ │          │  │    │
│  │  │  │ │Store │  │ │          │ │           │ │ │Tech  │ │          │  │    │
│  │  │  │ │Game  │  │ │          │ │           │ │ │Tree  │ │          │  │    │
│  │  │  │ │Config│  │ │          │ │           │ │ └──────┘ │          │  │    │
│  │  │  │ └──────┘  │ │          │ │           │ │          │          │  │    │
│  │  │  └──────────┘ │ └──────────┘ └───────────┘ └──────────┘          │  │    │
│  │  │                                 ┌──────────┐ ┌──────────┐        │  │    │
│  │  │  ┌──────────┐ ┌──────────┐      │ Multipl. │ │ Endgame  │        │  │    │
│  │  │  │Progress  │ │ Commands │      │ ┌──────┐ │ │ ┌──────┐ │        │  │    │
│  │  │  │ionSvc    │ │ │Admin   │      │ │Visit │ │ │ │Exped.│ │        │  │    │
│  │  │  └──────────┘ │ │Cmds    │      │ │Event │ │ │ │Raids │ │        │  │    │
│  │  │               │ └──────┘ │      │ └──────┘ │ │ │Def.  │ │        │  │    │
│  │  │               └──────────┘      │          │ │ └──────┘ │        │  │    │
│  │  │                                  └──────────┘ └──────────┘        │  │    │
│  │  └────────────────────────────────────────────────────────────────┘  │    │
│  │                                                                      │    │
│  │  ┌────────────────────┐  ┌────────────────────┐                     │    │
│  │  │     MANAGERS       │  │      SYSTEMS       │                     │    │
│  │  │  ┌──────────────┐  │  │ ┌────────────────┐ │                     │    │
│  │  │  │KingdomManager│  │  │ │ProductionSystem│ │                     │    │
│  │  │  │NPCManager    │  │  │ │OfflineSystem   │ │                     │    │
│  │  │  └──────────────┘  │  │ └────────────────┘ │                     │    │
│  │  └────────────────────┘  └────────────────────┘                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         ServerStorage                               │    │
│  │  ┌────────────────────┐  ┌────────────────────┐                    │    │
│  │  │     Templates      │  │       Pools         │                    │    │
│  │  │  ┌──────────────┐  │  │ ┌────────────────┐ │                    │    │
│  │  │  │Buildings/    │  │  │ │NPCPool         │ │                    │    │
│  │  │  │Workers/      │  │  │ │EffectPool      │ │                    │    │
│  │  │  │Effects/      │  │  │ └────────────────┘ │                    │    │
│  │  │  └──────────────┘  │  └────────────────────┘                    │    │
│  │  └────────────────────┘                                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        ReplicatedStorage                            │    │
│  │  ┌────────────────────┐  ┌────────────────────┐                    │    │
│  │  │      Shared        │  │       Assets        │                    │    │
│  │  │  ┌──────────────┐  │  │  ┌───────────────┐ │                    │    │
│  │  │  │Types.lua     │  │  │  │Models/        │ │                    │    │
│  │  │  │Enums.lua     │  │  │  │Textures/      │ │                    │    │
│  │  │  │Config/       │  │  │  │Sounds/        │ │                    │    │
│  │  │  │  Buildings   │  │  │  │Animations/    │ │                    │    │
│  │  │  │  Resources   │  │  │  └───────────────┘ │                    │    │
│  │  │  │  Workers     │  │  │                     │                    │    │
│  │  │  │  TechTree    │  │  │                     │                    │    │
│  │  │  │  Progression │  │  │                     │                    │    │
│  │  │  │Util/         │  │  │                     │                    │    │
│  │  │  │  MathUtil    │  │  │                     │                    │    │
│  │  │  │  TableUtil   │  │  │                     │                    │    │
│  │  │  │  TimeUtil    │  │  │                     │                    │    │
│  │  │  │Remote/       │  │  │                     │                    │    │
│  │  │  │  RemoteEvents│  │  │                     │                    │    │
│  │  │  │  RemoteFuncs │  │  │                     │                    │    │
│  │  │  │DI/           │  │  │                     │                    │    │
│  │  │  │  ServiceLoc  │  │  │                     │                    │    │
│  │  │  └──────────────┘  │  └─────────────────────┘                    │    │
│  │  └────────────────────┘                                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ Replicação via RemoteEvents/Commands
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CLIENTE (StarterPlayer)                            │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                     StarterPlayerScripts                            │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌──────────────────────┐  │    │
│  │  │   Bootstrapper  │  │  RemoteHandler │  │   EffectManager      │  │    │
│  │  └────────────────┘  └────────────────┘  └──────────────────────┘  │    │
│  │                                                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │                       CONTROLLERS                           │    │    │
│  │  │  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │    │    │
│  │  │  │   UIController  │  │CameraController│  │InputControll│  │    │    │
│  │  │  └────────────────┘  └────────────────┘  └──────────────┘  │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │                         UI                                  │    │    │
│  │  │  ┌────────────────────┐  ┌────────────────────┐            │    │    │
│  │  │  │       HUD          │  │      Menus          │            │    │    │
│  │  │  │  ┌──────────────┐  │  │  ┌──────────────┐  │            │    │    │
│  │  │  │  │ResourceBar   │  │  │  │BuildMenu     │  │            │    │    │
│  │  │  │  │XPBar         │  │  │  │TechTreeMenu  │  │            │    │    │
│  │  │  │  │Notification  │  │  │  │KingdomMenu   │  │            │    │    │
│  │  │  │  └──────────────┘  │  │  │VisitMenu     │  │            │    │    │
│  │  │  └────────────────────┘  │  └──────────────┘  │            │    │    │
│  │  │  ┌────────────────────┐  └────────────────────┘            │    │    │
│  │  │  │    Components      │                                     │    │    │
│  │  │  │  ┌──────────────┐  │                                     │    │    │
│  │  │  │  │Button        │  │                                     │    │    │
│  │  │  │  │Tooltip       │  │                                     │    │    │
│  │  │  │  │ProgressBar   │  │                                     │    │    │
│  │  │  │  └──────────────┘  │                                     │    │    │
│  │  │  └────────────────────┘                                     │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         StarterGui                                  │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │                         MainUI (ScreenGui)                   │    │    │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────┐  │    │    │
│  │  │  │HUD(Frame)  │ │BuildMenu   │ │TechTreeMenu│ │KingdomM  │  │    │    │
│  │  │  └────────────┘ │(Frame)     │ │(Frame)     │ │enu(Frame)│  │    │    │
│  │  │                 └────────────┘ └────────────┘ └──────────┘  │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Workspace (Mundo Físico)                          │
│                                                                              │
│  ┌────────────┐  ┌───────────────────────────────────────────┐             │
│  │  Terrain   │  │               Kingdoms                     │             │
│  │            │  │  ┌──────────────────────────────────────┐  │             │
│  │            │  │  │       [player_UserId]                │  │             │
│  │            │  │  │  ┌────────────┐  ┌────────────┐     │  │             │
│  │            │  │  │  │ Buildings  │  │  Workers   │     │  │             │
│  │            │  │  │  │ ┌──┐ ┌──┐  │  │ ┌──┐ ┌──┐  │     │  │             │
│  │            │  │  │  │ │F │ │M │  │  │ │W1│ │W2│  │     │  │             │
│  │            │  │  │  │ │a │ │i │  │  │ └──┘ └──┘  │     │  │             │
│  │            │  │  │  │ │r │ │n │  │  └────────────┘     │  │             │
│  │            │  │  │  │ │m │ │e │  │  ┌────────────┐     │  │             │
│  │            │  │  │  │ └──┘ └──┘  │  │   Props    │     │  │             │
│  │            │  │  │  └────────────┘  └────────────┘     │  │             │
│  │            │  │  └──────────────────────────────────────┘  │             │
│  │            │  └───────────────────────────────────────────┘             │
│  │            │  ┌──────────┐  ┌──────────┐                               │
│  │            │  │  NPCs    │  │ Effects  │                               │
│  │            │  └──────────┘  └──────────┘                               │
│  └────────────┘  └───────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Diagrama de Fluxo de Dados

```
AÇÃO DO JOGADOR (Cliente)
  │
  ▼
┌──────────────┐
│  Controller   │  (validação visual apenas)
└──────┬───────┘
       │ chamada via RemoteHandler
       ▼
┌──────────────┐
│ RemoteCommand │  (rate limit + sanitize + authorize)
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│  Service A   │────►│   EventBus   │────► Service B, C, D...
│  (executa)   │     └──────────────┘
└──────┬───────┘
       │
       ├──► DataStore (profile save)
       ├──► Workspace (instância visual)
       └──► RemoteEvent → Cliente (atualização UI)
```

### Diagrama de Inicialização

```
TIMELINE DE INICIALIZAÇÃO

Servidor Inicia
  ├── 0.00s │ Logger → EventBus → RemoteCommand → GameConfig → DataStore
  ├── 0.05s │ PlayerSession → Economy → Building → Production → Worker
  ├── 0.10s │ Progression → TechTree
  ├── 0.15s │ Managers: KingdomManager, NPCManager
  ├── 0.20s │ Systems: ProductionSystem, OfflineSystem
  ├── 0.25s │ ✅ SERVER READY — aguardando jogadores
  │
Jogador Entra
  ├── 0.00s │ PlayerAdded → PlayerSession cria sessão
  ├── 0.05s │ ProfileService carrega DataStore
  ├── 0.10s │ KingdomManager carrega reino no Workspace
  ├── 0.15s │ RemoteEvent → Cliente: "PlayerLoaded"
  │
Cliente Inicia (pós-join)
  ├── 0.00s │ ClientBootstrapper → RemoteHandler → Controllers
  ├── 0.05s │ UI carregada (oculta)
  ├── 0.10s │ Recebe "PlayerLoaded" → UI visível
  ├── 0.15s │ ✅ GAMEPLAY START
```

---

**Fim do Documento de Arquitetura.**

Este documento define a fundação técnica do Grow a Kingdom. Qualquer desvio desta arquitetura deve ser revisado e aprovado pelo Tech Lead antes da implementação.
