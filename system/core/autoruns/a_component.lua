local component = require("component")
local computer = require("computer")
local event = require("event")

local adding = {}
local primaries = {}

-------------------------------------------------------------------------------

-- This allows writing component.modem.open(123) instead of writing
-- component.getPrimary("modem").open(123), which may be nicer to read.
setmetatable(component, {
    __index = function(_, key)
        return primaries[key] --опционально
    end,
    __pairs = function(self)
        local parent = false
        return function(_, key)
            if parent then
                return next(primaries, key)
            else
                local k, v = next(self, key)
                if not k then
                    parent = true
                    return next(primaries)
                else
                    return k, v
                end
            end
        end
    end
})

function component.get(address, componentType)
    checkArg(1, address, "string")
    checkArg(2, componentType, "string", "nil")
    for c in component.list(componentType, true) do
        if c:sub(1, address:len()) == address then
            return c
        end
    end
    return nil, "no such component"
end

function component.isAvailable(componentType)
    checkArg(1, componentType, "string")
    if not primaries[componentType] and not adding[componentType] then
        -- This is mostly to avoid out of memory errors preventing proxyN
        -- creation cause confusion by trying to create the proxy again,
        -- causing the oom error to be thrown again.
        pcall(component.setPrimary, componentType, component.list(componentType, true)())
    end
    return primaries[componentType] ~= nil
end

function component.isPrimary(address)
    local componentType = component.type(address)
    if componentType then
        if component.isAvailable(componentType) then
            return primaries[componentType].address == address
        end
    end
    return false
end

function component.getPrimary(componentType)
    checkArg(1, componentType, "string")
    assert(component.isAvailable(componentType),
        "no primary '" .. componentType .. "' available")
    return primaries[componentType]
end

function component.setPrimary(componentType, address)
    checkArg(1, componentType, "string")
    checkArg(2, address, "string", "nil")

    if address ~= nil then
        address = component.get(address, componentType)
        assert(address, "no such component")
    end

    local wasAvailable = primaries[componentType]
    if wasAvailable and address == wasAvailable.address then
        return
    end
    local wasAdding = adding[componentType]
    if wasAdding and address == wasAdding.address then
        return
    end
    if wasAdding then
        event.cancel(wasAdding.timer)
    end
    primaries[componentType] = nil
    adding[componentType] = nil

    local primary = address and component.proxy(address) or nil
    if wasAvailable then
        computer.pushSignal("component_unavailable", componentType)
    end
    if primary then
        if wasAvailable or wasAdding then
            adding[componentType] = {
                address = address,
                proxy = primary,
                timer = event.timer(0.1, function()
                    adding[componentType] = nil
                    primaries[componentType] = primary
                    computer.pushSignal("component_available", componentType)
                end)
            }
        else
            primaries[componentType] = primary
            computer.pushSignal("component_available", componentType)
        end
    end
end

function component.isConnected(proxyOrAddress)
    if type(proxyOrAddress) == "table" then
        proxyOrAddress = proxyOrAddress.address
    end
    return not not pcall(component.doc, proxyOrAddress, "")
end

function component.getReal(ctype, gproxy)
    local vcomponent = require("vcomponent")
    for address in component.list(ctype, true) do
        if not vcomponent.isVirtual(address) then
            if gproxy then
                return component.proxy(address)
            else
                return address
            end
        end
    end
end

-------------------------------------------------------------------------------

local function onComponentAdded(_, address, componentType)
    local prev = primaries[componentType] or (adding[componentType] and adding[componentType].proxy)

    if prev then
        -- special handlers -- some components are just better at being primary
        if componentType == "screen" then
            --the primary has no keyboards but we do
            if #prev.getKeyboards() == 0 then
                local first_kb = component.invoke(address, 'getKeyboards')[1]
                if first_kb then
                    -- just in case our kb failed to achieve primary
                    -- possible if existing primary keyboard became primary first without a screen
                    -- then prev (a screen) was added without a keyboard
                    -- and then we attached this screen+kb pair, and our kb fired first - failing to achieve primary
                    -- also, our kb may fire right after this, which is fine
                    pcall(component.setPrimary, "keyboard", first_kb)
                    prev = nil -- nil meaning we should take this new one over the previous
                end
            end
        elseif componentType == "keyboard" then
            -- to reduce signal noise, if this kb is also the prev, we do not need to reset primary
            if address ~= prev.address then
                --keyboards never replace primary keyboards unless the are the only keyboard on the primary screen
                local current_screen = primaries.screen or (adding.screen and adding.screen.proxy)
                if current_screen then
                    prev = address ~= current_screen.getKeyboards()[1]
                end
            end
        end
    end

    if not prev then
        pcall(component.setPrimary, componentType, address)
    end
end

local function onComponentRemoved(_, address, componentType)
    if primaries[componentType] and primaries[componentType].address == address or
        adding[componentType] and adding[componentType].address == address
    then
        local next = component.list(componentType, true)()
        pcall(component.setPrimary, componentType, next)

        if componentType == "screen" and next then
            -- setPrimary already set the proxy (if successful)
            local proxy = (primaries.screen or (adding.screen and adding.screen.proxy))
            if proxy then
                -- if a screen is removed, and the primary keyboard is actually attached to another, non-primary, screen
                -- then the `next` screen, if it has a keyboard, should TAKE priority
                local next_kb = proxy.getKeyboards()[1] -- costly, don't call this method often
                local old_kb = primaries.keyboard or adding.keyboard
                -- if the next screen doesn't have a kb, this operation is without purpose, leave things as they are
                -- if there was no previous kb, use the new one
                if next_kb and (not old_kb or old_kb.address ~= next_kb) then
                    pcall(component.setPrimary, "keyboard", next_kb)
                end
            end
        end
    end
end

event.hyperListen(function (eventType, ...)
    if eventType == "component_added" then
        pcall(onComponentAdded, eventType, ...)
    elseif eventType == "component_removed" then
        pcall(onComponentRemoved, eventType, ...)
    end
end)

for address, ctype in component.list() do
    pcall(onComponentAdded, "component_added", address, ctype)
end
