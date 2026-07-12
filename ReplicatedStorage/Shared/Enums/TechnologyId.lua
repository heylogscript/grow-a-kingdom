--[[
    TechnologyId

    Enumeracao de tecnologias do jogo.
    Usado em unlockRequirements para referenciar
    tecnologias sem strings livres.
]]

export type TechnologyId = number

local TechnologyId: { [string]: TechnologyId } = {
    Farming = 1,
    Mining = 2,
    Metallurgy = 3,
    Architecture = 4,
    Masonry = 5,
    Irrigation = 6,
    MilitaryTactics = 7,
    Alchemy = 8,
    Trade = 9,
    Navigation = 10,
}

return TechnologyId
