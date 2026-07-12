--[[
    PlotModel

    Factory pura para criacao de PlotData.
    Define valores padrao do grid inicial.
]]

local PlotTypes = require(script.Parent.Parent.Types.PlotTypes)

local PlotModel = {}

function PlotModel.new(): PlotTypes.PlotData
    return {
        gridWidth = 10,
        gridDepth = 10,
    }
end

return PlotModel
