export type BuildingState = number

local BuildingState: { [string]: BuildingState } = {
    Constructing = 1,
    Active = 2,
    Demolished = 3,
}

return BuildingState
