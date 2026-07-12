--[[
    BuildingCategories

    Enumeracao de categorias de edificios.
    Usada como enum em BuildingDefinition.category.
    Evita strings livres que poderiam causar inconsistencias.
]]

export type BuildingCategory = number

local BuildingCategory: { [string]: BuildingCategory } = {
    Resource = 1,
    Production = 2,
    Housing = 3,
    Storage = 4,
    Military = 5,
    Utility = 6,
    Decor = 7,
    Special = 8,
}

return BuildingCategory
