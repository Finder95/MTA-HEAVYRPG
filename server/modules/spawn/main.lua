HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local module = {}

local function spawnAuthenticatedPlayer(player, account)
    local cfg = HRP.Config.auth.spawn
    spawnPlayer(player, cfg.x, cfg.y, cfg.z, cfg.rotation, cfg.skin, cfg.interior, cfg.dimension)
    setPlayerMoney(player, tonumber(account.cash) or cfg.startingMoney or 500)
    fadeCamera(player, true, 1.0)
    setCameraTarget(player, player)
    setElementFrozen(player, false)
end

function module.onStart()
    addEventHandler("HeavyRPG:Auth:onPlayerLoggedIn", resourceRoot, function(player, account)
        if isElement(player) then
            spawnAuthenticatedPlayer(player, account or {})
        end
    end)
end

HRP.Modules.register("spawn", module)
