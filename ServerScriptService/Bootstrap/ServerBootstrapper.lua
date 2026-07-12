--[[
    ServerBootstrapper

    Script principal de inicializacao do servidor.
    Executa automaticamente quando o jogo inicia.
    Fluxo:
    1. Instancia ServiceLocator
    2. Le InitOrder
    3. Para cada entry: require -> new -> register
    4. Para cada entry: init()
    5. Para cada entry: start()
    6. Servidor pronto para jogadores
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceLocatorModule = require(ReplicatedStorage.Shared.DI.ServiceLocator)
local serviceLocator = ServiceLocatorModule.new()

-- Registrar singleton do BuildingRegistry antes dos services
local BuildingRegistryModule = require(ReplicatedStorage.Shared.Buildings.BuildingRegistry)
serviceLocator:register("BuildingRegistry", BuildingRegistryModule.new())

local initOrder = require(script.Parent.InitOrder)
local services: { [string]: any } = {}

-- Fase 1: Instanciar e registrar
for _, entry in initOrder do
    local success: boolean, result: any = pcall(function()
        local module: any = require(entry.path)
        local service: any = module.new(serviceLocator)
        services[entry.name] = service
        serviceLocator:register(entry.name, service)
    end)
    if not success then
        error(string.format("ServerBootstrapper: Failed to create service '%s': %s", entry.name, result))
    end
end

-- Fase 2: Inicializar
for _, entry in initOrder do
    local service: any = services[entry.name]
    if service.init then
        local success: boolean, result: any = pcall(function()
            service:init()
        end)
        if not success then
            error(string.format("ServerBootstrapper: Failed to init service '%s': %s", entry.name, result))
        end
    end
end

-- Fase 3: Iniciar operacao
for _, entry in initOrder do
    local service: any = services[entry.name]
    if service.start then
        local success: boolean, result: any = pcall(function()
            service:start()
        end)
        if not success then
            error(string.format("ServerBootstrapper: Failed to start service '%s': %s", entry.name, result))
        end
    end
end

local logger = serviceLocator:get("Logger")
logger:info("ServerBootstrapper completed")

return nil
