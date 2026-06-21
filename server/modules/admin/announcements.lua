HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local MIN_LEVEL = 3
local COOLDOWN_MS = 2500
local lastAnnouncementTick = {}

local function now()
    return HRP.Utils and HRP.Utils.now and HRP.Utils.now() or getRealTime().timestamp
end

local function characterName(player)
    return tostring(getElementData(player, "hrp:character:name") or getPlayerName(player) or "Administrator")
end

local function isAllowed(player)
    return isElement(player) and HRP.Admin and HRP.Admin.has and HRP.Admin.has(player, MIN_LEVEL)
end

local function sanitizeMessage(message)
    message = tostring(message or "")
    message = message:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #message > 180 then message = message:sub(1, 180) end
    return message
end

addEventHandler("HeavyRPG:Admin:action", resourceRoot, function(action, payload)
    if tostring(action or "") ~= "announce" then return end
    if not isAllowed(client) then return end

    local tick = getTickCount()
    if (tick - (lastAnnouncementTick[client] or 0)) < COOLDOWN_MS then return end

    payload = type(payload) == "table" and payload or {}
    local message = sanitizeMessage(payload.message)
    if #message < 3 then return end

    lastAnnouncementTick[client] = tick
    triggerClientEvent(root, "HeavyRPG:Admin:announcement", resourceRoot, {
        message = message,
        admin = characterName(client),
        createdAt = now()
    })
end)

addEventHandler("onPlayerQuit", root, function()
    lastAnnouncementTick[source] = nil
end)
