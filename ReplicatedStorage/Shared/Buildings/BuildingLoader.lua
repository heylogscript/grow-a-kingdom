--[[
    BuildingLoader

    Responsabilidade unica: descobrir e carregar todos os
    BuildingDefinitions da pasta Buildings/.

    Auto-descoberta: qualquer ModuleScript adicionado a pasta
    (exceto os modulos do sistema) e automaticamente carregado.
    Nenhum registro manual necessario.

    Exclui automaticamente: BuildingLoader, BuildingValidator,
    BuildingRegistry, BuildingCategories.
]]

local SYSTEM_MODULES: { [string]: boolean } = {
    BuildingLoader = true,
    BuildingValidator = true,
    BuildingRegistry = true,
    BuildingCategories = true,
}

local BuildingLoader = {}

function BuildingLoader.loadAll(): { any }
    local definitions: { any } = {}
    local folder: Instance = script.Parent

    for _, child: Instance in ipairs(folder:GetChildren()) do
        if not child:IsA("ModuleScript") then
            continue
        end
        if SYSTEM_MODULES[child.Name] then
            continue
        end

        local success: boolean, result: any = pcall(require, child)
        if not success then
            warn(string.format("BuildingLoader: failed to load '%s': %s", child.Name, result))
            continue
        end

        table.insert(definitions, result)
    end

    return definitions
end

return BuildingLoader
