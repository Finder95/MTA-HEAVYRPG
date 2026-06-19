HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

math.randomseed(getTickCount() + HRP.Utils.now())

addEventHandler("onResourceStart", resourceRoot, function()
    HRP.Logger.info("boot", "Startuje HeavyRPG " .. tostring(HRP.Config.version))

    if not HRP.DB.connect() then
        HRP.Logger.error("boot", "Resource zatrzymany: brak polaczenia z baza.")
        cancelEvent(true, "HeavyRPG database initialization failed")
        return
    end

    HRP.Modules.startAll()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    HRP.DB.shutdown()
end)
