HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local function roleName(level)
    level = tonumber(level) or 0
    if level >= 100 then return "Developer" end
    local roles = {
        [0] = "Gracz",
        [1] = "Support",
        [2] = "Moderator",
        [3] = "Administrator",
        [4] = "Head Admin"
    }
    return roles[level] or "Admin"
end

local function openFor(player)
    if not isElement(player) or not HRP.Admin or not HRP.Admin.has or not HRP.Admin.has(player, 1) then return end
    local level = HRP.Admin.getLevel and HRP.Admin.getLevel(player) or tonumber(getElementData(player, "hrp:admin:level")) or 0
    triggerClientEvent(player, "HeavyRPG:Admin:open", resourceRoot, {
        level = level,
        role = tostring(getElementData(player, "hrp:admin:role") or roleName(level))
    })
end

addEvent("HeavyRPG:Admin:openRequest", true)
addEventHandler("HeavyRPG:Admin:openRequest", resourceRoot, function()
    openFor(client)
end)
