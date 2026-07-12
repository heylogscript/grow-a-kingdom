# Grow a Kingdom — Game Design Document

**Nota:** Este documento é derivado de `GAK_TECHNICAL_PLAN.md` e da revisão técnica `GAK_TECH_REVIEW.md`.

---

## Visão Geral

**Grow a Kingdom** é um jogo Roblox de progressão idle com foco em construção, automação e evolução visual de um reino medieval vivo. O jogador começa com um pequeno terreno e recursos básicos, expandindo seu reino construindo edifícios, desbloqueando trabalhadores NPCs, automatizando produção e pesquisando tecnologias.

- **Gênero:** Idle Builder / Kingdom Management / Multiplayer Social
- **Público-alvo:** Casual a médio (Roblox 8+)
- **Tonalidade:** Relaxante, satisfatório, progressão gradual
- **PvP:** Endgame opcional — não é o foco

## Loop Principal

1. Coletar Recursos → 2. Construir/Melhorar Edifícios → 3. Desbloquear Trabalhadores → 4. Automatizar Produção → 5. Expandir Reino → 6. Pesquisar Tecnologias → 7. Evoluir Aparência → (repetir em escala maior)

## Gameplay Secundário

- Visitas entre jogadores
- Eventos globais
- Expedições (endgame PvE)
- Raids cooperativas (endgame)
- Defesa do reino (endgame opcional)
- Guerras entre reinos (endgame opt-in)

## Sistemas Principais

**Foundation (MVP):** Economia, Construção, Produção, Trabalhadores, Progressão, Árvore de Tecnologia, DataStore, Player Session, UI Core

**Expansion (pós-MVP):** Visitas, Eventos Globais, Expedições, Raids, Defesa, Guerras

**Polimento:** Achievements, Leaderboard, Loja, Analytics, Anti-Exploit

## Roadmap

- **Fase 0 (s1-2):** Protótipo — infraestrutura + economia + 1 edifício
- **Fase 1 (s3-5):** MVP fechado — 10 edifícios, workers, tech tree, UI
- **Fase 2 (s6-8):** MVP aberto — balanceamento, testes, anti-exploit
- **Fase 3 (s9-11):** Multiplayer — visitas, eventos
- **Fase 4 (s12-16):** Endgame — expedições, raids, defesa
- **Fase 5 (s17-20):** Lançamento — shop, achievements, analytics, carga

Para detalhes completos, ver `GAK_TECHNICAL_PLAN.md` e `GAK_TECH_REVIEW.md`.
