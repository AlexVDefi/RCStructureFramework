local Config = require("RCStructureFramework/Config")
---@class RCStructureFrameworkEventRegistration
local EventRegistration = {}

---@type table<string, { register: fun(), unregister: fun()|nil }>
local wired = {}

---@param key string            -- RCSF_Config.systems key
---@param register fun()        -- binds the system's events (idempotent)
---@param unregister fun()|nil  -- unbinds them (for disable)
---@return nil
function EventRegistration.wire(key, register, unregister)
    wired[key] = { register = register, unregister = unregister }
    if Config.systems[key] ~= false then
        register()
    end
end

---@param key string
---@return boolean
function EventRegistration.enable(key)
    Config.systems[key] = true
    local entry = wired[key]
    if entry and entry.register then
        entry.register()
        return true
    end
    return false
end

---@param key string
---@return boolean
function EventRegistration.disable(key)
    Config.systems[key] = false
    local entry = wired[key]
    if entry and entry.unregister then
        entry.unregister()
        return true
    end
    return false
end

---@param key string
---@return boolean
---@nodiscard
function EventRegistration.isEnabled(key)
    return Config.systems[key] ~= false
end

return EventRegistration
