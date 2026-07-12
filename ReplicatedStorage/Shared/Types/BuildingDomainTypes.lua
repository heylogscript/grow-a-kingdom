local BuildingState = require(script.Parent.Parent.Enums.BuildingState)

export type BuildingId = string

export type GridPosition = {
    x: number,
    z: number,
}

export type BuildingData = {
    schemaVersion: number,
    buildingId: BuildingId,
    definitionId: string,
    position: GridPosition,
    rotation: number,
    level: number,
    state: BuildingState.BuildingState,
    createdAt: number,
}

return {}
