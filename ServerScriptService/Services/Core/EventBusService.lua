export type Subscription = {
    Disconnect: () -> (),
}

export type EventBusService = {
    _serviceLocator: any,
    _listeners: { [string]: { (any) -> () } },
}

local EventBusService: EventBusService = {}
EventBusService.__index = EventBusService

function EventBusService.new(serviceLocator: any): EventBusService
    return setmetatable({
        _serviceLocator = serviceLocator,
        _listeners = {},
    }, EventBusService)
end

function EventBusService:init()
    local logger = self._serviceLocator:get("Logger")
    logger:info("EventBusService initialized")
end

function EventBusService:start()
    local logger = self._serviceLocator:get("Logger")
    logger:info("EventBusService started")
end

function EventBusService:on(eventName: string, callback: (any) -> ()): Subscription
    if not self._listeners[eventName] then
        self._listeners[eventName] = {}
    end
    table.insert(self._listeners[eventName], callback)
    return {
        Disconnect = function()
            local listeners: { (any) -> () }? = self._listeners[eventName]
            if not listeners then
                return
            end
            for i: number, cb: (any) -> () in ipairs(listeners) do
                if cb == callback then
                    table.remove(listeners, i)
                    return
                end
            end
        end,
    }
end

function EventBusService:fire(eventName: string, data: any)
    local listeners: { (any) -> () }? = self._listeners[eventName]
    if not listeners then
        return
    end
    for _, callback: (any) -> () in listeners do
        local success: boolean, err: any = pcall(callback, data)
        if not success then
            local logger = self._serviceLocator:get("Logger")
            logger:warn(string.format("EventBus: listener error on '%s': %s", eventName, err))
        end
    end
end

return EventBusService
