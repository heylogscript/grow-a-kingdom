--[[
    LoggerService

    Sistema centralizado de logging.
    Niveis: Info, Warn, Error.
    No futuro: persistencia de logs em DataStore separada,
    diferentes verbosidades por ambiente (dev/prod),
    e integracao com sistema de analytics.
]]

export type LoggerService = {
    _serviceLocator: any,
}

local LoggerService: LoggerService = {}
LoggerService.__index = LoggerService

local LogLevel = {
    Info = "[INFO]",
    Warn = "[WARN]",
    Error = "[ERROR]",
}

function LoggerService.new(serviceLocator: any): LoggerService
    return setmetatable({
        _serviceLocator = serviceLocator,
    }, LoggerService)
end

function LoggerService:info(message: string, ...: any)
    print(LogLevel.Info, message, ...)
end

function LoggerService:warn(message: string, ...: any)
    warn(LogLevel.Warn, message, ...)
end

function LoggerService:error(message: string, ...: any)
    error(LogLevel.Error .. " " .. message, 2)
end

function LoggerService:debug(message: string, ...: any)
    print("[DEBUG]", message, ...)
end

return LoggerService
