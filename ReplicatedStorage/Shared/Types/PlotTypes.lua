--[[
    PlotTypes

    Tipos do sistema de terreno (Plot).
    Plot armazena apenas as dimensoes do grid.
    A ocupacao e derivada de kingdom.buildings
    e mantida em cache transiente no PlotService.
]]

export type PlotData = {
    gridWidth: number,
    gridDepth: number,
}

return {}
