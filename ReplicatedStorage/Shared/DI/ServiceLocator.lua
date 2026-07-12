--[[
    ServiceLocator

    Container de injecao de dependencia para services.
    Services sao registrados por nome durante o bootstrap.
    Outros sistemas (Managers, Systems) acessam services via get().
    NENHUM service importa outro service diretamente.
]]

export type ServiceLocator = {
    _services: { [string]: any },
}

local ServiceLocator = {}
ServiceLocator.__index = ServiceLocator

function ServiceLocator.new(): ServiceLocator
    return setmetatable({
        _services = {},
    }, ServiceLocator)
end

function ServiceLocator:register(name: string, service: any)
    self._services[name] = service
end

function ServiceLocator:get<T>(name: string): T?
    return self._services[name]
end

function ServiceLocator:has(name: string): boolean
    return self._services[name] ~= nil
end

return ServiceLocator
