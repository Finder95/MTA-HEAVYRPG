HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local module = {}

local function spawnCharacter(player, character)
    local cfg = HRP.Config.auth.spawn
    character = character or {}

    local x = tonumber(character.x) or cfg.x
    local y = tonumber(character.y) or cfg.y
    local z = tonumber(character.z) or cfg.z
    local rotation = tonumber(character.rotation) or cfg.rotation
    local skin = tonumber(character.skin) or cfg.skin
    local interior = tonumber(character.interior) or cfg.interior
    local dimension = tonumber(character.dimension) or cfg.dimension

    spawnPlayer(player, x, y, z, rotation, skin, interior, dimension)
    setPlayerMoney(player, tonumber(character.cash) or cfg.startingMoney or 500)
    fadeCamera(player, true, 1.0)
    setCameraTarget(player, player)
    setElementFrozen(player, false)
end

function module.onStart()
    addEventHandler("HeavyRPG:Character:onPlayerReady", resourceRoot, function(player, character)
        if isElement(player) then
            spawnCharacter(player, character or {})
        end
    end)
end

HRP.Modules.register("spawn", module)
