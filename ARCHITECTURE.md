# Grow a Kingdom — Architecture Document

Este documento é um atalho para `GAK_ARCHITECTURE.md`, que contém a arquitetura completa.

## Resumo

**3 camadas estritas:** Server (ServerScriptService) → Shared (ReplicatedStorage) → Client (StarterPlayer)

**Direção única de dependência:** Server → Shared → Client (nunca o inverso)

**Princípios:** SOLID, SOA, Data Driven Design, Composition over Inheritance, Event Bus, Service Locator

**Padrões:** Service Locator, Event Bus (pub/sub), RemoteCommand Framework, Profile Pattern (DataStore), Object Pool, Data Driven Config, Bootstrapper, Manager-Service Hierarchy

## Estrutura Raiz

```
ServerScriptService/
  Bootstrap/            — Inicialização do servidor
  Services/Core/        — Logger, EventBus, RemoteCommand, DataStore, GameConfig
  Services/Player/      — PlayerSession, ProfileService
  Services/Economy/     — EconomyService
  Services/Kingdom/     — Building, Production, Worker, TechTree
  Services/Progression/ — ProgressionService
  Services/Multiplayer/ — Visit, Event
  Managers/             — KingdomManager, NPCManager
  Systems/              — ProductionSystem, OfflineSystem
  Commands/             — AdminCommands

ServerStorage/
  Templates/Buildings/  — Modelos de edifícios
  Templates/Workers/    — Modelos de NPCs
  Pools/                — Object pools

ReplicatedStorage/
  Shared/
    Types, Enums        — Definições de tipos
    Config/             — Buildings, Resources, Workers, TechTree, Progression
    Util/               — MathUtil, TableUtil, TimeUtil, InstanceUtil
    Remote/             — RemoteEvents, RemoteFunctions
    DI/                 — ServiceLocator
  Assets/               — Models, Textures, Sounds, Animations

StarterPlayer/
  StarterPlayerScripts/
    Bootstrap/          — ClientBootstrapper
    Controllers/        — UI, Camera, Input
    UI/                 — HUD, Menus, Components
    Modules/            — RemoteHandler, EffectManager

StarterGui/             — Estrutura visual da UI (sem scripts)
```

## Regras de Comunicação

- Services NUNCA importam outros Services diretamente (usam EventBus + ServiceLocator)
- Shared NUNCA importa Server ou Client
- Client NUNCA importa Server
- Todo RemoteEvent passa pelo RemoteCommand framework (rate limit + sanitize + authorize)

Para documentação completa, diagrams, ciclo de inicialização, e expansão futura, ver `GAK_ARCHITECTURE.md`.
