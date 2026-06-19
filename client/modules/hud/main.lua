HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientHUD = HRP.ClientHUD or {
    visible = false,
    needs = { hunger = 100, thirst = 100, energy = 100, hygiene = 100, stress = 0 },
    money = { cash = 0, bank = 0 },
    sx = 0,
    sy = 0,
    lastSync = 0
}

local HUD = HRP.ClientHUD
local hiddenComponents = { "ammo", "area_name", "armour", "breath", "clock", "health", "money", "radar", "vehicle_name", "weapon" }

local function color(name, alpha)
    local cfg = HRP.Config.hud or {}
    local value = cfg[name] or { 255, 255, 255 }
    return tocolor(value[1] or 255, value[2] or 255, value[3] or 255, alpha or value[4] or 255)
end

local function clamp(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

local function money(value)
    value = math.floor(tonumber(value) or 0)
    local sign = value < 0 and "-" or ""
    value = math.abs(value)
    local text = tostring(value)
    local out = ""
    while #text > 3 do
        out = "," .. text:sub(-3) .. out
        text = text:sub(1, -4)
    end
    return sign .. "$" .. text .. out
end

local function shadowText(text, x, y, w, h, textColor, scale, font, alignX, alignY)
    dxDrawText(text, x + 1, y + 1, w + 1, h + 1, tocolor(0, 0, 0, 190), scale or 1, font or "default-bold", alignX or "left", alignY or "top", false, false, true)
    dxDrawText(text, x, y, w, h, textColor, scale or 1, font or "default-bold", alignX or "left", alignY or "top", false, false, true)
end

local function drawSoftBar(label, value, x, y, w, h, barColorName, inverse)
    value = clamp(value)
    local fillValue = inverse and (100 - value) or value
    local danger = (not inverse and value <= 18) or (inverse and value >= 82)
    local fillColor = danger and color("danger", 225) or color(barColorName, 218)

    dxDrawRectangle(x, y, w, h, color("barBack", 165), true)
    dxDrawRectangle(x, y, math.max(2, w * (fillValue / 100)), h, fillColor, true)
    dxDrawRectangle(x, y + h - 1, w, 1, tocolor(0, 0, 0, 120), true)

    shadowText(label, x, y - 15, x + w, y, color("muted", 215), 0.68, "default-bold")
    shadowText(tostring(math.floor(value)), x, y - 15, x + w, y, danger and color("danger", 235) or color("text", 220), 0.68, "default-bold", "right")
end

local function getVehicleSpeed()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle then return nil end
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.floor(((vx * vx + vy * vy + vz * vz) ^ 0.5) * 180)
end

local function drawNeedsCluster(x, y)
    local hp = clamp(getElementHealth(localPlayer))
    local armor = clamp(getPedArmor(localPlayer))
    local gap = 25
    local w = 176
    local h = 8

    dxDrawRectangle(x - 10, y - 22, w + 20, 184, color("background", 96), true)
    shadowText("stan postaci", x, y - 19, x + w, y - 4, color("text", 205), 0.72, "default-bold")

    drawSoftBar("zdrowie", hp, x, y + 8, w, h, "health", false)
    drawSoftBar("pancerz", armor, x, y + 8 + gap, w, h, "armor", false)
    drawSoftBar("glod", HUD.needs.hunger, x, y + 8 + gap * 2, w, h, "hunger", false)
    drawSoftBar("pragnienie", HUD.needs.thirst, x, y + 8 + gap * 3, w, h, "thirst", false)
    drawSoftBar("energia", HUD.needs.energy, x, y + 8 + gap * 4, w, h, "energy", false)
    drawSoftBar("stres", HUD.needs.stress, x, y + 8 + gap * 5, w, h, "stress", true)

    if hp <= 20 or HUD.needs.thirst <= 15 or HUD.needs.hunger <= 15 then
        local alpha = 35 + math.abs(math.sin(getTickCount() / 260)) * 55
        dxDrawRectangle(x - 10, y - 22, w + 20, 184, tocolor(120, 0, 0, alpha), true)
    end
end

local function drawMoneyLine(x, y)
    local speed = getVehicleSpeed()
    local hour, minute = getTime()
    local timeText = string.format("%02d:%02d", hour or 0, minute or 0)
    local width = 255
    local line = "gotowka " .. money(HUD.money.cash or getPlayerMoney(localPlayer)) .. "   konto " .. money(HUD.money.bank or 0)

    dxDrawRectangle(x - 10, y - 8, width + 20, speed and 58 or 36, color("background", 86), true)
    shadowText(line, x, y, x + width, y + 16, color("cash", 230), 0.78, "default-bold", "right")
    shadowText(timeText, x, y + 17, x + width, y + 33, color("muted", 220), 0.72, "default-bold", "right")

    if speed then
        shadowText(tostring(speed) .. " km/h", x, y + 36, x + width, y + 52, color("text", 220), 0.78, "default-bold", "right")
    end
end

local function renderHUD()
    if not HUD.visible or not HRP.Config.hud or HRP.Config.hud.enabled == false then return end
    if isPlayerMapVisible() then return end

    HUD.sx, HUD.sy = guiGetScreenSize()
    drawNeedsCluster(26, HUD.sy - 196)
    drawMoneyLine(HUD.sx - 285, 28)
end

local function hideDefaultComponents()
    for _, component in ipairs(hiddenComponents) do
        showPlayerHudComponent(component, false)
    end
end

local function setVisible(state)
    state = state == true
    if HUD.visible == state then return end
    HUD.visible = state

    if state then
        hideDefaultComponents()
        addEventHandler("onClientRender", root, renderHUD)
    else
        removeEventHandler("onClientRender", root, renderHUD)
    end
end

addEvent("HeavyRPG:Survival:sync", true)
addEventHandler("HeavyRPG:Survival:sync", resourceRoot, function(needs)
    needs = type(needs) == "table" and needs or {}
    HUD.needs.hunger = clamp(needs.hunger or HUD.needs.hunger)
    HUD.needs.thirst = clamp(needs.thirst or HUD.needs.thirst)
    HUD.needs.energy = clamp(needs.energy or HUD.needs.energy)
    HUD.needs.hygiene = clamp(needs.hygiene or HUD.needs.hygiene)
    HUD.needs.stress = clamp(needs.stress or HUD.needs.stress)
    HUD.lastSync = getTickCount()
    setVisible(true)
end)

addEvent("HeavyRPG:Bank:sync", true)
addEventHandler("HeavyRPG:Bank:sync", resourceRoot, function(payload)
    payload = type(payload) == "table" and payload or {}
    HUD.money.cash = tonumber(payload.cash) or getPlayerMoney(localPlayer)
    HUD.money.bank = tonumber(payload.bank) or HUD.money.bank or 0
    HUD.lastSync = getTickCount()
    setVisible(true)
end)

addEventHandler("HeavyRPG:Auth:show", resourceRoot, function()
    setVisible(false)
end)

addEventHandler("HeavyRPG:Character:showCreator", resourceRoot, function()
    setVisible(false)
end)

addEventHandler("HeavyRPG:Character:hideCreator", resourceRoot, function()
    hideDefaultComponents()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    hideDefaultComponents()
end)

addEventHandler("onClientPlayerSpawn", localPlayer, function()
    hideDefaultComponents()
end)
