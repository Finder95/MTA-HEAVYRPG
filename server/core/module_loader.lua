HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Modules = HRP.Modules or { registry = {}, started = {} }

function HRP.Modules.register(name, module)
    if type(name) ~= "string" or type(module) ~= "table" then
        return false
    end

    module.name = name
    HRP.Modules.registry[name] = module
    return true
end

function HRP.Modules.start(name)
    local module = HRP.Modules.registry[name]
    if not module then
        HRP.Logger.warn("modules", "Brak modulu: " .. tostring(name))
        return false
    end

    if HRP.Modules.started[name] then return true end

    if module.onStart then
        local ok, err = pcall(module.onStart)
        if not ok then
            HRP.Logger.error("modules", "Blad startu modulu " .. name .. ": " .. tostring(err))
            return false
        end
    end

    HRP.Modules.started[name] = true
    HRP.Logger.info("modules", "Uruchomiono modul: " .. name)
    return true
end

function HRP.Modules.startAll()
    for _, name in ipairs(HRP.Config.modules.order or {}) do
        HRP.Modules.start(name)
    end
end
