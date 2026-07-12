--[[
    PlayerJoinHandler

    Configura o estado inicial de um novo jogador.
    Executado quando o jogador entra no servidor.

    Fluxo:
    1. ProfileService.LoadProfile
       a. Se dados existem: ImportKingdom → skip criacao
       b. Se nil (primeira visita): CreateKingdom
    2. Criar Plot
    3. Conceder recursos iniciais
    4. Contratar workers iniciais

    Nao posiciona edificios — o jogador escolhe
    o que construir pelo BuildMenu.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ResourceType = require(ReplicatedStorage.Shared.Enums.ResourceType)

export type PlayerJoinHandler = {
    _serviceLocator: any,
    _logger: any,
    _kingdomService: any,
    _plotService: any,
    _resourceService: any,
    _workerService: any,
    _profileService: any,
}

local PlayerJoinHandler: PlayerJoinHandler = {}
PlayerJoinHandler.__index = PlayerJoinHandler

local STARTER_GOLD = 500
local STARTER_WOOD = 200
local INITIAL_WORKER_COUNT = 2

function PlayerJoinHandler.new(serviceLocator: any): PlayerJoinHandler
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = nil,
        _kingdomService = nil,
        _plotService = nil,
        _resourceService = nil,
        _workerService = nil,
        _profileService = nil,
    }, PlayerJoinHandler)
end

function PlayerJoinHandler:init()
    self._logger = self._serviceLocator:get("Logger")
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._plotService = self._serviceLocator:get("Plot")
    self._resourceService = self._serviceLocator:get("Resource")
    self._workerService = self._serviceLocator:get("Workers")
    self._profileService = self._serviceLocator:get("ProfileService")
    self._logger:info("PlayerJoinHandler initialized")
end

function PlayerJoinHandler:start()
    local function setupPlayer(player: Player)
        -- Tentar carregar perfil existente (rejoin ou restored)
        local loaded: any = self._profileService:LoadProfile(player.UserId)
        if loaded then
            self._logger:info(string.format("Player %s profile loaded (kingdom %s)", player.Name, loaded.kingdomId))
            return
        end

        -- Primeiro acesso: criar kingdom fresh
        local ok: boolean
        local result: any

        ok, result = pcall(function()
            local kingdom: any = self._kingdomService:CreateKingdom(player.UserId, player.Name .. "'s Kingdom")
            self._kingdomService:SetState(kingdom.kingdomId, "Ready")
            self._plotService:CreatePlot(kingdom.kingdomId)

            self._resourceService:Add(kingdom.kingdomId, ResourceType.Gold, STARTER_GOLD, "starting_gift")
            self._resourceService:Add(kingdom.kingdomId, ResourceType.Wood, STARTER_WOOD, "starting_gift")

            for _: number = 1, INITIAL_WORKER_COUNT do
                self._workerService:HireWorker(kingdom.kingdomId, "builder")
            end

            self._logger:info(string.format("Player %s setup complete (kingdom %s)", player.Name, kingdom.kingdomId))
        end)

        if not ok then
            self._logger:error(string.format("Failed to setup player %s: %s", player.Name, tostring(result)))
        end
    end

    for _, player: Player in Players:GetPlayers() do
        task.spawn(setupPlayer, player)
    end

    Players.PlayerAdded:Connect(setupPlayer)

    self._logger:info("PlayerJoinHandler started")
end

function PlayerJoinHandler:stop()
    self._logger:info("PlayerJoinHandler stopped")
end

return PlayerJoinHandler
