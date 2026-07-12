# Grow a Kingdom

An **idle kingdom builder** for Roblox. Construct buildings, automate production, research technologies, and evolve your medieval kingdom from a small plot to a thriving realm.

## Systems

- **Building System** — Place, construct, and upgrade buildings. Each level unlocks new visual stages and production multipliers. Data-driven config for all building types.
- **Resource Economy** — Server-authoritative resource management with production ticks, cost validation, and persistence.
- **Workers** — NPC workers that automate production. Assigned to buildings for resource generation.
- **Production System** — Continuous production loop with offline income calculation on rejoin.
- **Tech Tree** — Research technologies to unlock new buildings, upgrades, and capabilities.
- **Progression** — XP, levels, milestones, and unlocks that gate content.
- **Plot Management** — Grid-based land plots for building placement with collision detection.
- **Multiplayer** — Player visits, global events, expeditions, raids, and defense (post-MVP).
- **Event-Driven Architecture** — EventBus pub/sub for inter-service communication. RemoteCommand framework for all client-server interactions.

## Architecture

| Layer | Role |
|---|---|
| `ServerScriptService/Services/Core` | Infrastructure: Logger, EventBus, DataStore, RemoteCommand, GameConfig |
| `ServerScriptService/Services/Player` | Player session, profile load/save/migration |
| `ServerScriptService/Services/Economy` | Resource balance, transactions, validation |
| `ServerScriptService/Services/Kingdom` | Building construction, production, workers, tech tree |
| `ServerScriptService/Services/Progression` | XP, levels, unlocks |
| `ServerScriptService/Services/Multiplayer` | Visits, global events |
| `ServerScriptService/Managers` | Orchestrators: KingdomManager, NPCManager |
| `ServerScriptService/Systems` | Continuous loops: ProductionSystem, OfflineSystem |
| `ReplicatedStorage/Shared` | Types, enums, config, utilities, remotes, DI |
| `StarterPlayerScripts` | Client: controllers, UI, input handling |

## Tech

- **Language:** Luau
- **Engine:** Roblox
- **Build:** Rojo (`default.project.json`)
- **Pattern:** 3-layer modular architecture (Server → Shared → Client), server-authoritative, event-driven
