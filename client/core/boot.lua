HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

addEventHandler("onClientResourceStart", resourceRoot, function()
    HRP.Browser.init(function()
        HRP.Browser.setVisible(true)
        HRP.Browser.emit("auth:boot", { serverName = HRP.Config.name })
        HRP.ClientAuth.ready()
    end)
end)
