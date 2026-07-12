# Grow a Kingdom — Revisão Técnica Crítica

**Revisor:** Principal Engineer  
**Documento revisado:** GAK_TECHNICAL_PLAN.md  
**Status:** ❌ Necessita alterações antes de qualquer implementação

---

## Nota Geral: 5.5 / 10

O documento descreve **o que** construir, mas não **como** construir de forma robusta. É um bom documento de game design, mas insuficiente como documento técnico de engenharia. A arquitetura proposta tem falhas estruturais que garantirão retrabalho significativo se seguidas literalmente.

---

## Problemas Encontrados

### 1. Ausência de Separação Client/Server/Shared

**Problema:**  
O documento trata todos os sistemas como "Services" sem definir onde cada um executa. Não há distinção entre código de servidor, cliente e compartilhado. Serviços como `EconomyService` e `BuildingService` são mencionados como módulos em `ReplicatedStorage`, mas não especificam se executam no servidor, no cliente, ou ambos.

**Impacto futuro:**  
- Services acabarão com `if RunService:IsServer()` espalhados — o anti-pattern mais comum do Roblox
- Lógica de validação (server-side) misturada com lógica de display (client-side)
- Código impossível de testar e debuggar
- Cada módulo terá responsabilidades duplas e acoplamento cognitivo alto

**Solução:**  
Arquitetura em 3 camadas estritas:
- **Server Layer** (`ServerScriptService`): Toda lógica de autoridade — validação de economia, save/load, spawn de NPCs, processamento de produção
- **Shared Layer** (`ReplicatedStorage`): Tipos, configurações, utilitários, definições de eventos remotos — NADA de lógica executável
- **Client Layer** (`StarterPlayerScripts`): UI, input, feedback visual, câmera, efeitos

Relação: Server → Shared → Client (direção única, sem dependência reversa)

**Por que é melhor:**  
Cada módulo tem UMA responsabilidade em UM contexto de execução. Elimina conditionals de `IsServer` em módulos compartilhados. Permite testar server e client isoladamente.

---

### 2. Acoplamento Rígido Entre Serviços

**Problema:**  
O documento lista dependências como `BuildingService depende de EconomyService`, mas não define **como** um service se comunica com outro. A abordagem implícita é `ServiceA:CallMethod()` diretamente em `ServiceB`. Isso cria acoplamento direto entre módulos.

**Impacto futuro:**  
- Services se importam mutuamente, criando dependências circulares
- Substituir ou modificar um service quebra todos que o importam
- Impossível mockar services para testes
- Ordem de carregamento vira um problema frágil

**Solução:**  
Implementar **Event Bus** para comunicação inter-service:
- Cada service dispara eventos quando seu estado muda (`EconomyService:onResourceChanged(playerId, resource, value)`)
- Services que precisam reagir a mudanças se inscrevem nos eventos relevantes
- NENHUM service importa diretamente outro — todos importam apenas o EventBus

Para chamadas request-response (não eventos), usar um **Service Locator** com injeção de dependência no Bootstrapper.

**Por que é melhor:**  
- Services são independentes e testáveis isoladamente
- Ordem de carregamento não importa (eventos são registrados, não chamados diretamente)
- Novo service pode ser adicionado sem modificar os existentes (Open/Closed Principle)

---

### 3. Gerenciamento de Instâncias Inexistente

**Problema:**  
O documento fala em "construir edifícios" e "workers NPCs" mas não define como essas **instâncias Roblox** serão gerenciadas. Cada edifício = várias partes (fundação, paredes, telhado, decorações). Um reino médio pode ter 100+ edifícios com centenas de partes.

**Impacto futuro:**  
- Cada parte criada com `Instance.new()` consome memória e um `Handle` no Roblox
- Milhares de partes = crash em Mobile/Tablet com ~500MB de limite
- Workers NPCs criados e destruídos constantemente causam garbage collection pressure
- Update de propriedades em massa causa lag de replicação

**Solução:**  
- **Object Pooling** para workers: pool de instâncias reutilizáveis de NPCs. Quando um worker é "contratado", uma instância da pool é ativada. Quando "demitido", é desativada e volta à pool.
- **MeshPart + UnionOperation** para edifícios: após a construção, fundir partes estáticas em uma única MeshPart reduz contagem de instâncias em ~80%
- **Attributes** em vez de `IntValue`/`StringValue` filhos: usar `Instance:SetAttribute()` para dados runtime em partes — reduz instâncias filler em 50%+
- **Region Streaming**: apenas carregar partes dentro do campo de visão do jogador

**Por que é melhor:**  
- Memória previsível e controlada. Object pooling elimina alocação/desalocação constante
- Mobile/Console jogável com reinos grandes (centenas de edifícios)
- Menos instâncias = menos replicação = menos lag multiplayer

---

### 4. DataStore Sem Padrão Industrial

**Problema:**  
O documento menciona "DataStore" genericamente sem especificar **o padrão de profile** usado pela indústria Roblox. Não menciona limites de 4MB por key, 60 requests/min/player, nem estratégia de fila de saves.

**Impacto futuro:**  
- Saves concorrentes estouram o limite de requests do DataStore
- Perda de dados em crash do servidor (save não frequente o suficiente)
- Dados corrompidos impossíveis de recuperar (sem versionamento)
- Jogador carregar save de servidor A enquanto servidor B ainda está salvando

**Solução:**  
Implementar o **Profile Pattern** padrão da indústria (usado em jogos como adopt me!, pet simulator, etc.):
- **1 key por jogador**: `player_UserId` com toda a profile em uma única entry JSON
- **Cache em memória**: ao carregar, profile fica em memória. Todas as operações modificam a cópia em memória
- **Auto-save queue**: fila de saves com debounce de 30-60s. Modificações frequentes (coleta de recursos) não disparam save a cada vez
- **BindToClose**: salvar na saída do jogador E no shutdown do servidor
- **Versionamento**: campo `_version` na profile para migração automática de schema
- **Lock otimista**: timestamp da última modificação para detectar conflitos entre servidores
- **Compressão**: para profiles grandes, compressão + split se > 4MB

**Por que é melhor:**  
- Respeita os limites do DataStore (60 req/min/player) — fila de saves garante no máximo 2-3 saves por minuto
- Dados nunca perdidos: cache em memória + save frequente + save no disconnect
- Schema evolution: versão permite migrar dados sem quebrar saves existentes

---

### 5. RemoteEvents Sem Framework de Segurança

**Problema:**  
O documento menciona "RemoteEvent Security" de forma genérica, sem definir um framework real de validação. Não especifica rate limiting, sanitização de parâmetros, autorização, nem padrão de requisição.

**Impacto futuro:**  
- Cliente explorado pode chamar RemoteEvents arbitrários (duplicar recursos, construir fora dos limites, spawnar NPCs infinitos)
- Speedhack: cliente envia "coletei recursos" a cada frame
- Economia quebrada = jogadores perdem interesse = jogo morto

**Solução:**  
Framework de **RemoteCommand** que cada RemoteEvent deve seguir:
```lua
-- Padrão obrigatório para TODO RemoteEvent:
1. Rate Limit: máximo N chamadas por segundo por jogador (configurável por ação)
2. Sanitização: tipo, range, ownership checks em TODO parâmetro
3. Autorização: jogador TEM permissão para fazer esta ação? (tem nível? tem recurso? tem o prédio?)
4. Server-Authoritative: servidor é a única fonte da verdade. Cliente apenas "sugere" ações
5. Idempotência: mesma requisição não pode ser processada duas vezes (debounce por ação)
```

Além disso:
- **TODOS** os cálculos de produção, coleta e economia são feitos no servidor
- Cliente nunca "tem" recursos — ele apenas exibe o que o servidor enviou
- Qualquer disparidade entre servidor e cliente é corrigida automaticamente (server reconciliation)

**Por que é melhor:**  
- Mesmo com cliente modificado, servidor rejeita operações inválidas
- Rate limit previne automação/scripting malicioso
- Server-authoritative significa que economia é sempre consistente
- Padrão replicável para TODO RemoteEvent — segurança consistente em todo o jogo

---

### 6. Inexistência de Sistema de Live Service

**Problema:**  
O documento não menciona feature flags, config remota, migração de dados ou toggles de emergência. O jogo será lançado como um bloco monolítico.

**Impacto futuro:**  
- Toda atualização requer publish no Roblox (15-30min de aprovação)
- Se uma feature quebra produção, não há como desligá-la sem publish
- Impossível fazer A/B testing ou rollout gradual
- Mudar o custo de um edifício requer publish (em vez de alterar um valor remoto)

**Solução:**  
Infraestrutura de Live Service:
- **GameConfig** módulo carregado via HttpService de um raw GitHub JSON ou MemoryStore na inicialização do servidor
- **FeatureFlags** no GameConfig: `{ expeditionsEnabled: false, warEnabled: false, doubleProductionEvent: true }`
- **Override por jogador**: player flag no DataStore permite ativar features seletivamente (beta testers)
- **Comando admin runtime**: `/reloadconfig` recarrega configuração sem reiniciar servidor
- **Schema migration**: campo `DataVersion` na profile do jogador. Ao carregar, se versão < atual, executa scripts de migração

**Por que é melhor:**  
- Desliga feature quebrada em segundos sem publish
- Rollout gradual de features (5% → 25% → 100% dos jogadores)
- Ajuste de balancing sem publish (custo de ouro de um edifício é um valor no config remoto)
- Migração segura de dados sem perder progresso de jogadores

---

### 7. Ausência de Sistema de Logging e Debug

**Problema:**  
O documento não menciona logging, monitoring ou ferramentas de debug. Não há plano para diagnosticar problemas em produção.

**Impacto futuro:**  
- Bugs acontecem em produção e não há como saber o que ocorreu
- Jogadores reportam "perdi meus recursos" e não há log para investigar
- Economia quebrada passa despercebida por dias

**Solução:**  
Sistema de **Logger** centralizado com níveis:
- `Logger:Info(player, action, data)` — transações normais
- `Logger:Warn(player, action, data)` — comportamento suspeito, rate limit接近
- `Logger:Error(player, action, data)` — erro de execução, validação falhou

Logs enviados para uma **DataStore de Log** (uma key separada, não na profile do jogador) ou via **HttpService** para endpoint externo.

Admin panel in-game:
- `/inspect playerName` — ver profile completa, recursos, edifícios
- `/give playerName resource amount` — comando de admin para debug
- `/simulate hours` — avançar produção X horas para testar balancing

**Por que é melhor:**  
- Investigar bugs de produção sem modificar código
- Detectar padrões de exploit (muitos rate limits do mesmo jogador)
- Audit trail de economia (quem gastou o quê e quando)
- Debugging rápido sem precisar reproduzir o bug localmente

---

### 8. Ordem de Desenvolvimento Ignora Infraestrutura

**Problema:**  
A ordem proposta começa com "estrutura do projeto" mas depois pula direto para sistemas de gameplay sem construir a infraestrutura necessária: DataStore pattern, RemoteEvent framework, Logger, Bootstrapper.

**Impacto futuro:**  
- Sistemas de gameplay são construídos sem foundation sólida
- Quando segurança/data/logging são adicionados depois, exigem refatoração de tudo
- Retrabalho massivo (estimar ~40% do código reescrito)

**Solução:**  
Nova ordem que prioriza infraestrutura primeiro:

```
TIER 0 — Infraestrutura (fundação)
  1. Bootstrapper + Init Pipeline (ordem de carregamento)
  2. LoggerService
  3. EventBus
  4. RemoteCommand Framework (RemoteEvents tipados e seguros)
  5. DataStore Profile Pattern (ProfileService ou implementação própria)
  6. GameConfig (config remota + feature flags)

TIER 1 — Core Systems (com infra robusta)
  7. PlayerSessionService (profile loading/unloading)
  8. EconomyService (servidor autoritativo, validação em cada transação)
  9. BuildingService + ObjectPool
  10. ProductionService

TIER 2 — Gameplay
  11. WorkerService + NPC Pooling
  12. ProgressionService
  13. TechTreeService
  14. UIService

TIER 3 — Multiplayer
  15. VisitService + LOD rendering

TIER 4 — Endgame
  16. Expedition/Raid/Defense Services

TIER 5 — Live Ops
  17. ShopService
  18. AnalyticsService
  19. AntiExploit avançado
```

**Por que é melhor:**  
- Infraestrutura construída UMA vez e usada por todos os sistemas
- Zero retrabalho: sistemas de gameplay são construídos SOBRE a fundação, não antes dela
- Segurança e logging presentes desde o primeiro dia
- DataStore resiliente antes de qualquer dado ser salvo

---

### 9. Performance de Multiplayer (Visitas) Subestimada

**Problema:**  
"VisitService" é descrito como um sistema simples. Na realidade, visitar o reino de outro jogador requer carregar potencialmente centenas de peças de outro servidor/instância. Isso é um dos maiores desafios técnicos do Roblox.

**Impacto futuro:**  
- Servidor lagando ao carregar reinos de visitantes
- Memória estourando com 10 jogadores visitando reinos diferentes
- Experiência ruim: tempo de carregamento longo, FPS baixo durante visita

**Solução:**  
- **Snapshot-based visits**: ao visitar, servidor envia uma **versão simplificada** do reino (MeshParts fundidas, sem NPCs ativos, texturas de baixa resolução)
- **LOD por distância**: quanto mais longe da câmera, menos detalhes renderizados
- **Timeout de visita**: visita dura no máximo X minutos para liberar recursos
- **Instância separada**: idealmente, visitas ocorrem em uma light instance separada (se a arquitetura do Roblox permitir) ou via streaming controlado

**Por que é melhor:**  
- Visitante não precisa carregar 500 partes de um reino — apenas um snapshot otimizado
- Performance do servidor principal não é afetada por visitas
- Player pode visitar vários reinos em uma sessão sem memory leak

---

### 10. Economia e Progressão Sem Tratamento de Dados Offline

**Problema:**  
O documento menciona produção idle e automação, mas não especifica como lidar com **tempo offline**. Se o jogador produz recursos enquanto está offline, por quanto tempo? Como calcular? Como evitar abuso (entrar, coletar, sair, repetir)?

**Impacto futuro:**  
- Jogadores entram a cada 5 minutos para coletar recursos (grind excessivo)
- OU tempo offline infinito = jogador volta com recursos infinitos (quebra economia)
- Sistema de "aceleração" (gemas para acelerar produção) precisa saber quanto tempo falta

**Solução:**  
- **Offline production cap**: máximo de 8h de produção acumulada (sleep mechanic)
- **Calculado no login**: ao entrar, servidor calcula `(os.time() - lastLogoutTime) * productionRate`, capped pelo max offline
- **LastLogoutTime** salvo no DataStore
- **Boosters**: itens que aumentam offline cap ou multiplicam produção offline
- **UI mostrando**: "Você ficou offline por 6h. Coletou 12.000 de ouro!"

**Por que é melhor:**  
- Economia previsível: jogador não acumula 30 dias de produção offline
- Incentiva login diário sem punir quem não pode jogar todo dia
- Base para monetização (boosters de produção offline)

---

## Resumo de Alterações Obrigatórias Antes de Escrever Código

| # | Alteração | Prioridade |
|---|-----------|------------|
| 1 | Definir arquitetura em 3 camadas estritas (Server/Shared/Client) | 🔴 Crítica |
| 2 | Implementar EventBus + Service Locator (acoplamento zero entre services) | 🔴 Crítica |
| 3 | Profile Pattern para DataStore (cache + fila + versionamento) | 🔴 Crítica |
| 4 | RemoteCommand Framework (rate limit + sanitização + server-authoritative) | 🔴 Crítica |
| 5 | Bootstrapper com ordem de init explícita | 🔴 Crítica |
| 6 | GameConfig + FeatureFlags (live service) | 🟡 Alta |
| 7 | Logger centralizado com níveis e audit trail | 🟡 Alta |
| 8 | Object Pooling para NPCs + Otimização de instâncias | 🟡 Alta |
| 9 | Sistema de offline production com cap e cálculo | 🟡 Alta |
| 10 | Snapshot-based Visit System com LOD | 🟢 Média |

---

## Nova Ordem de Implementação Proposta

```
SEMANA 1 — Fundação
  ├── Estrutura de pastas (ServerScriptService / ReplicatedStorage / StarterPlayerScripts)
  ├── Bootstrapper + Init Pipeline
  ├── LoggerService
  ├── EventBus
  └── RemoteCommand Framework

SEMANA 2 — Persistência
  ├── DataStore Profile Pattern (cache, fila, versionamento)
  ├── GameConfig (config remota)
  └── PlayerSessionService (load/unload profiles)

SEMANA 3-4 — Core Systems
  ├── EconomyService (server-authoritative, validação, logging)
  ├── ObjectPool (reuso de instâncias)
  └── BuildingService (placement, upgrade, visual evolution)

SEMANA 5 — Produção e Automação
  ├── ProductionService (cálculo server-side)
  ├── Offline production system
  └── WorkerService + ObjectPool de NPCs

SEMANA 6 — Progressão
  ├── ProgressionService
  └── TechTreeService

SEMANA 7-8 — UI e Polimento MVP
  ├── UIService (HUD, construção, inventário)
  ├── Testes internos
  └── Ajustes de balancing

SEMANA 9-10 — Multiplayer
  ├── VisitService (snapshot + LOD)
  └── Permissions system

SEMANA 11-14 — Endgame
  ├── ExpeditionService
  ├── RaidService
  ├── DefenseService
  └── WarService (opcional)

SEMANA 15-18 — Live Ops
  ├── ShopService
  ├── AnalyticsService
  ├── AntiExploitService
  ├── Feature flags finais
  └── Testes de carga (500+ CCU)

SEMANA 19-20 — Lançamento
  ├── UI Polish
  ├── Testes finais
  └── Lançamento público
```

**Diferença principal da ordem original:**  
- Original pula direto para gameplay (semana 1-2). Esta revisão gasta as primeiras 2 semanas inteiras construindo infraestrutura que **todo o resto do jogo vai usar**. Isso adiciona 1 semana ao cronograma total, mas elimina ~40% de retrabalho que aconteceria na abordagem original.

---

**Fim da revisão.**

Aguardando sua decisão sobre quais alterações implementar antes de prosseguir.
