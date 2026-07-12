export type GridPosition = {
    x: number,
    z: number,
}

type OccupiedCell = {
    x: number,
    z: number,
}

local DEFAULT_CELL_SIZE = 4

local GridMath = {}

function GridMath.WorldToGrid(worldPos: Vector3, cellSize: number?): GridPosition
    local cs: number = cellSize or DEFAULT_CELL_SIZE
    return {
        x = math.floor(worldPos.X / cs) + 1,
        z = math.floor(-worldPos.Z / cs) + 1,
    }
end

function GridMath.GridToWorld(gridPos: GridPosition, cellSize: number?): Vector3
    local cs: number = cellSize or DEFAULT_CELL_SIZE
    return Vector3.new(
        (gridPos.x - 1) * cs + cs / 2,
        0,
        -(gridPos.z - 1) * cs - cs / 2
    )
end

function GridMath.SnapToGrid(worldPos: Vector3, cellSize: number?): Vector3
    local gp: GridPosition = GridMath.WorldToGrid(worldPos, cellSize)
    return GridMath.GridToWorld(gp, cellSize)
end

function GridMath.RotateFootprint(width: number, depth: number, rotation: number): (number, number)
    local rot: number = rotation % 180
    if rot == 90 then
        return depth, width
    end
    return width, depth
end

--- API unica de iteracao de footprint. Retorna todas as celulas ocupadas.
--- @param x number — grid x da celula origem
--- @param z number — grid z da celula origem
--- @param width number — largura em celulas (pre-rotacao)
--- @param depth number — profundidade em celulas (pre-rotacao)
--- @param rotation number — 0, 90, 180, 270
--- @return { OccupiedCell }
function GridMath.GetOccupiedCells(x: number, z: number, width: number, depth: number, rotation: number): { OccupiedCell }
    local fw: number
    local fz: number
    fw, fz = GridMath.RotateFootprint(width, depth, rotation)
    local cells: { OccupiedCell } = {}
    for cx: number = x, x + fw - 1 do
        for cz: number = z, z + fz - 1 do
            table.insert(cells, { x = cx, z = cz })
        end
    end
    return cells
end

function GridMath.GetFootprintCFrame(
    gridPos: GridPosition,
    width: number,
    depth: number,
    rotation: number,
    cellSize: number?,
    yOffset: number?
): CFrame
    local cs: number = cellSize or DEFAULT_CELL_SIZE
    local y: number = yOffset or 0
    local fw: number
    local fz: number
    fw, fz = GridMath.RotateFootprint(width, depth, rotation)

    local centerX: number = ((gridPos.x - 1) + fw / 2) * cs
    local centerZ: number = -((gridPos.z - 1) + fz / 2) * cs
    return CFrame.new(centerX, y, centerZ)
end

function GridMath.GetFootprintSize(width: number, depth: number, rotation: number, cellSize: number?): Vector3
    local cs: number = cellSize or DEFAULT_CELL_SIZE
    local fw: number
    local fz: number
    fw, fz = GridMath.RotateFootprint(width, depth, rotation)
    return Vector3.new(fw * cs, 0.5, fz * cs)
end

return GridMath
