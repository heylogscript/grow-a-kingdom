--[[
    AssetTypes

    Tipos do sistema de AssetRegistry.
    Define a estrutura dos assets carregados
    e indices de consulta.
]]

export type AssetEntry = {
    modelId: string,
    model: Model,
    definitionId: string?,
}

export type AssetMap = { [string]: Model }

return {}
