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

local function uiScale()
    local sx, sy = guiGetScreenSize()
    local scale = math.min(sx / 1600, sy / 900)
    if scale < 0.95 then scale = 0.95 end
    if scale > 1.55 then scale = 1.55 end
    return scale, sx, sy
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
    dxDrawText(text, x + 1, y + 1, w + 1, h + 1, tocolor(0, 0, 0, 185), scale or 1, font or "default-bold", alignX or "left", alignY or "top", false, false, true)
    dxDrawText(text, x, y, w, h, textColor, scale or 1, font or "default-bold", alignX or "left", alignY or "top", false, false, true)
end

local function drawIcon(kind, x, y, size, iconColor)
    local c = iconColor
    local s = size
    local cx = x + s / 2
    local cy = y + s / 2
    local lw = math.max(1, math.floor(s / 12))

    if kind == "health" then
        dxDrawRectangle(cx - s * 0.13, y + s * 0.18, s * 0.26, s * 0.64, c, true)
        dxDrawRectangle(x + s * 0.18, cy - s * 0.13, s * 0.64, s * 0.26, c, true)
        return
    end

    if kind == "armor" then
        dxDrawLine(cx, y + s * 0.10, x + s * 0.80, y + s * 0.26, c, lw, true)
        dxDrawLine(x + s * 0.80, y + s * 0.26, x + s * 0.70, y + s * 0.72, c, lw, true)
        dxDrawLine(x + s * 0.70, y + s * 0.72, cx, y + s * 0.90, c, lw, true)
        dxDrawLine(cx, y + s * 0.90, x + s * 0.30, y + s * 0.72, c, lw, true)
        dxDrawLine(x + s * 0.30, y + s * 0.72, x + s * 0.20, y + s * 0.26, c, lw, true)
        dxDrawLine(x + s * 0.20, y + s * 0.26, cx, y + s * 0.10, c, lw, true)
        return
    end

    if kind == "hunger" then
        dxDrawLine(x + s * 0.28, y + s * 0.16, x + s * 0.28, y + s * 0.84, c, lw, true)
        dxDrawLine(x + s * 0.18, y + s * 0.18, x + s * 0.38, y + s * 0.18, c, lw, true)
        dxDrawLine(x + s * 0.18, y + s * 0.30, x + s * 0.38, y + s * 0.30, c, lw, true)
        dxDrawLine(x + s * 0.64, y + s * 0.16, x + s * 0.64, y + s * 0.84, c, lw, true)
        dxDrawLine(x + s * 0.64, y + s * 0.16, x + s * 0.82, y + s * 0.34, c, lw, true)
        return
    end

    if kind == "thirst" then
        dxDrawLine(cx, y + s * 0.12, x + s * 0.75, y + s * 0.48, c, lw, true)
        dxDrawLine(x + s * 0.75, y + s * 0.48, cx, y + s * 0.88, c, lw, true)
        dxDrawLine(cx, y + s * 0.88, x + s * 0.25, y + s * 0.48, c, lw, true)
        dxDrawLine(x + s * 0.25, y + s * 0.48, cx, y + s * 0.12, c, lw, true)
        return
    end

    if kind == "energy" then
        dxDrawLine(x + s * 0.62, y + s * 0.08, x + s * 0.32, y + s * 0.50, c, lw + 1, true)
        dxDrawLine(x + s * 0.32, y + s * 0.50, x + s * 0.56, y + s * 0.50, c, lw + 1, true)
        dxDrawLine(x + s * 0.56, y + s * 0.50, x + s * 0.38, y + s * 0.92, c, lw + 1, true)
        return
    end

    if kind == "stress" then
        dxDrawLine(x + s * 0.10, cy, x + s * 0.28, cy, c, lw, true)
        dxDrawLine(x + s * 0.28, cy, x + s * 0.38, y + s * 0.26, c, lw, true)
        dxDrawLine(x + s * 0.38, y + s * 0.26, x + s * 0.52, y + s * 0.74, c, lw, true)
        dxDrawLine(x + s * 0.52, y + s * 0.74, x + s * 0.66, y + s * 0.34, c, lw, true)
        dxDrawLine(x + s * 0.66, y + s * 0.34, x + s * 0.82, cy, c, lw, true)
        dxDrawLine(x + s * 0.82, cy, x + s * 0.92, cy, c, lw, true)
        return
    end
end

local function drawStatusBar(kind, label, value, x, y, w, h, barColorName, inverse, scale)
    value = clamp(value)
    local fill = inverse and (100 - value) or value
    local danger = (not inverse and value <= 18) or (inverse and value >= 82)
    local fillColor = danger and color("danger", 235) or color(barColorName, 228)
    local iconSize = 22 * scale
    local barX = x + iconSize + 10 * scale
    local barY = y + 9 * scale
    local labelScale = 0.72 * scale

    drawIcon(kind, x, y + 2 * scale, iconSize, fillColor)
    shadowText(label, barX, y - 3 * scale, barX + w, y + 14 * scale, color("text", 220), labelScale, "default-bold")
    shadowText(tostring(math.floor(value)), barX, y - 3 * scale, barX + w, y + 14 * scale, danger and color("danger", 240) or color("muted", 220), labelScale, "default-bold", "right")

    dxDrawRectangle(barX, barY, w, h, color("barBack", 150), true)
    dxDrawRectangle(barX, barY, math.max(3 * scale, w * (fill / 100)), h, fillColor, true)
    dxDrawRectangle(barX, barY + h - math.max(1, scale), w, math.max(1, scale), tocolor(0, 0, 0, 120), true)
end

local function getVehicleSpeed()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle then return nil end
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.floor(((vx * vx + vy * vy + vz * vz) ^ 0.5) * 180)
end

local function drawStatusCluster(scale, sx, sy)
    local margin = 34 * scale
    local row = 37 * scale
    local barW = 265 * scale
    local barH = 12 * scale
    local x = margin
    local y = sy - margin - row * 6

    drawStatusBar("health", "Zdrowie", getElementHealth(localPlayer), x, y, barW, barH, "health", false, scale)
    drawStatusBar("armor", "Pancerz", getPedArmor(localPlayer), x, y + row, barW, barH, "armor", false, scale)
    drawStatusBar("hunger", "Glod", HUD.needs.hunger, x, y + row * 2, barW, barH, "hunger", false, scale)
    drawStatusBar("thirst", "Pragnienie", HUD.needs.thirst, x, y + row * 3, barW, barH, "thirst", false, scale)
    drawStatusBar("energy", "Energia", HUD.needs.energy, x, y + row * 4, barW, barH, "energy", false, scale)
    drawStatusBar("stress", "Stres", HUD.needs.stress, x, y + row * 5, barW, barH, "stress", true, scale)
end

local function drawMoneyBlock(scale, sx)
    local speed = getVehicleSpeed()
    local hour, minute = getTime()
    local x = sx - 36 * scale
    local y = 28 * scale
    local textScale = 0.86 * scale
    local smallScale = 0.74 * scale
    local lineH = 21 * scale

    shadowText("Gotowka " .. money(HUD.money.cash or getPlayerMoney(localPlayer)), x - 330 * scale, y, x, y + lineH, color("cash", 235), textScale, "default-bold", "right")
    shadowText("Konto " .. money(HUD.money.bank or 0), x - 330 * scale, y + lineH, x, y + lineH * 2, color("text", 220), smallScale, "default-bold", "right")
    shadowText(string.format("%02d:%02d", hour or 0, minute or 0), x - 160 * scale, y + lineH * 2, x, y + lineH * 3, color("muted", 220), smallScale, "default-bold", "right")

    if speed then
        shadowText(tostring(speed) .. " km/h", x - 160 * scale, y + lineH * 3, x, y + lineH * 4, color("text", 220), textScale, "default-bold", "right")
    end
end

local function renderHUD()
    if not HUD.visible or not HRP.Config.hud or HRP.Config.hud.enabled == false then return end
    if isPlayerMapVisible() then return end

    local scale, sx, sy = uiScale()
    HUD.sx, HUD.sy = sx, sy
    drawStatusCluster(scale, sx, sy)
    drawMoneyBlock(scale, sx)
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
