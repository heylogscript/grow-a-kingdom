local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingModel = require(ReplicatedStorage.Shared.Models.BuildingModel)
local BuildingDomainTypes = require(ReplicatedStorage.Shared.Types.BuildingDomainTypes)

export type BuildingFactory = {}

local BuildingFactory: BuildingFactory = {}
BuildingFactory.__index = BuildingFactory

function BuildingFactory.new(): BuildingFactory
    return setmetatable({}, BuildingFactory)
end

function BuildingFactory:Create(
    definitionId: string,
    position: BuildingDomainTypes.GridPosition,
    rotation: number?,
    buildingIdOverride: string?
): BuildingDomainTypes.BuildingData
    local buildingId: string = buildingIdOverride or HttpService:GenerateGUID(false)
    return BuildingModel.new(buildingId, definitionId, position, rotation)
end

return BuildingFactory
