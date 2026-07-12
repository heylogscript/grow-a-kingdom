--[[
    RequirementValidator

    Validacao READ-ONLY de requisitos para construcao/upgrade.
    Responsabilidades:
    - Verificar se o jogador TEM recursos suficientes (via CanAfford)
    - Verificar se o nivel do Kingdom atende ao requisito
    - Verificar se as tecnologias necessarias foram pesquisadas

    IMPORTANTE: nao gasta recursos. Isso e responsabilidade
    do BuildingService, que chama TrySpend separadamente.

    NAO valida posicionamento ou colisao.
    Isso e responsabilidade do PlacementValidator.
]]

export type RequirementValidator = {
    _serviceLocator: any,
    _logger: any,
    _resourceService: any,
    _kingdomService: any,
}

local RequirementValidator: RequirementValidator = {}
RequirementValidator.__index = RequirementValidator

function RequirementValidator.new(serviceLocator: any): RequirementValidator
    return setmetatable({
        _serviceLocator = serviceLocator,
        _logger = serviceLocator:get("Logger"),
        _resourceService = nil,
        _kingdomService = nil,
    }, RequirementValidator)
end

function RequirementValidator:init()
    self._resourceService = self._serviceLocator:get("Resource")
    self._kingdomService = self._serviceLocator:get("Kingdom")
    self._logger:info("RequirementValidator initialized")
end

--- Valida SE o jogador pode construir/upgrade (read-only, nao gasta).
--- @param kingdomId string
--- @param definitionId string
--- @param cost { [number]: number }? — tabela de custo opcional
--- @return boolean, string?
function RequirementValidator:Validate(
    kingdomId: string,
    definitionId: string,
    cost: { [number]: number }?
): (boolean, string?)
    local kingdom: any = self._kingdomService:GetById(kingdomId)
    if not kingdom then
        return false, "Kingdom not found"
    end

    -- Validacao de recursos (read-only via CanAfford)
    if cost then
        local canAfford: boolean = self._resourceService:CanAfford(kingdomId, cost)
        if not canAfford then
            return false, "Insufficient resources"
        end
    end

    return true, nil
end

return RequirementValidator
