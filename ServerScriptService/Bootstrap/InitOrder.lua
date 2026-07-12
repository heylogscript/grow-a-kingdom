--[[
    InitOrder

    Define a ordem explicita de inicializacao dos Services.
    Cada entrada contem:
    - name: nome usado no ServiceLocator
    - path: caminho relativo do ModuleScript (a partir de ServerScriptService)

    A ordem importa: Logger deve vir primeiro para que outros services
    possam logar durante sua inicializacao.
]]

return {
    { name = "Logger", path = script.Parent.Parent.Services.Core.LoggerService },
    { name = "EventBus", path = script.Parent.Parent.Services.Core.EventBusService },
    { name = "Kingdom", path = script.Parent.Parent.Services.Kingdom.KingdomService },
    { name = "ProfileService", path = script.Parent.Parent.Services.Player.ProfileService },
    { name = "Resource", path = script.Parent.Parent.Services.Resource.ResourceService },
    { name = "AssetRegistry", path = script.Parent.Parent.Services.Assets.AssetRegistry },
    { name = "Workers", path = script.Parent.Parent.Services.Workers.WorkerService },
    { name = "Production", path = script.Parent.Parent.Services.Production.ProductionService },
    { name = "Plot", path = script.Parent.Parent.Services.Plot.PlotService },
    { name = "PlacementValidator", path = script.Parent.Parent.Services.Building.PlacementValidator },
    { name = "RequirementValidator", path = script.Parent.Parent.Services.Building.RequirementValidator },
    { name = "BuildingEvents", path = script.Parent.Parent.Services.Building.BuildingEvents },
    { name = "Building", path = script.Parent.Parent.Services.Building.BuildingService },
    { name = "PlacementHandler", path = script.Parent.Parent.Services.Building.PlacementHandler },
    { name = "ConstructionVisualizer", path = script.Parent.Parent.Services.Building.ConstructionVisualizer },
    { name = "ConstructionTimer", path = script.Parent.Parent.Services.Building.ConstructionTimer },
    { name = "PlayerJoinHandler", path = script.Parent.Parent.Services.Player.PlayerJoinHandler },
}
