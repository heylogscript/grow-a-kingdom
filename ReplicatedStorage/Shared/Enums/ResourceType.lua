--[[
    ResourceType

    Enumeracao de tipos de recurso do jogo.
    Usa numeros em vez de strings para:
    - Seguranca em tempo de compilacao (Luau type checking)
    - Melhor performance em lookups frequentes (hash de numero vs string)
    - Autocomplete em IDEs
]]

export type ResourceType = number

local ResourceType: { [string]: ResourceType } = {
    Gold = 1,
    Wood = 2,
    Stone = 3,
    Food = 4,
    Gems = 5,
}

function ResourceType.toString(resourceType: ResourceType): string
    for name: string, value: ResourceType in ResourceType do
        if value == resourceType then
            return name
        end
    end
    return "Unknown"
end

function ResourceType.fromString(name: string): ResourceType?
    return ResourceType[name]
end

return ResourceType
