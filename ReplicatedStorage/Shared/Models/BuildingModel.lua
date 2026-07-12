local BuildingDomainTypes = require(script.Parent.Parent.Types.BuildingDomainTypes)

local BuildingModel = {}

function BuildingModel.new(
    buildingId: string,
    definitionId: string,
    position: BuildingDomainTypes.GridPosition,
    rotation: number?
): BuildingDomainTypes.BuildingData
    return {
        schemaVersion = 1,
        buildingId = buildingId,
        definitionId = definitionId,
        position = position,
        rotation = rotation or 0,
        level = 1,
        state = 1,
        createdAt = os.time(),
    }
end

return BuildingModel
