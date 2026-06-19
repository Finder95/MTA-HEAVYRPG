HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientHUD = HRP.ClientHUD or {
    visible = false,
    needs = { hunger = 100, thirst = 100, energy = 100, hygiene = 100, stress = 0 },
    money = { cash = 0, bank = 0 },
    sx = 0,
    sy = 0,
    pulse = 0,
    lastSync = 0
}

local HUD = HRP.ClientHUD
local hiddenComponents = { "ammo", "area_name", "armour", "breath", "clock", "health", "money", "radar", "vehicle_name", "weapon" }

local function rgba(color, alpha)
    color = color or { 255, 255, 255 }
    return tocolor(color[1] or 255, color[2] or 255, color[3] or 255, alpha or color[4] or 255)
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

local function drawShadowText(text, x, y, w, h, color, scale, font, ax, ay)
    dxDrawText(text, x + 1, y + 1, w + 1, h + 1, tocolor(0, 0, 0, 210), scale or 1, font or "default-bold", ax or "left", ay or "top", false, false, true)
    dxDrawText(text, x, y, w, h, color, scale or 1, font or "default-bold", ax or "left", ay or "top", false, false, true)
end

local function drawPanel(x, y, w, h, title)
    local cfg = HRP.Config.hud or {}
    local accent = rgba(cfg.accent, 230)
    local bg = cfg.background or { 5, 12, 10, 205 }

    dxDrawRectangle(x, y, w, h, tocolor(bg[1] or 5, bg[2] or 12, bg[3] or 10, bg[4] or 205), true)
    dxDrawLine(x, y, x + w, y, accent, 1, true)
    dxDrawLine(x, y + h, x + w, y + h, accent, 1, true)
    dxDrawLine(x, y, x, y + h, accent, 1, true)
    dxDrawLine(x + w, y, x + w, y + h, accent, 1, true)

    dxDrawRectangle(x + 3, y + 3, w - 6, 18, tocolor(14, 36, 27, 190), true)
    drawShadowText(title, x + 8, y + 4, x + w - 8, y + 20, accent, 0.82, "default-bold")
end

local function drawRetroBar(label, value, x, y, w, h, inverse)
    local cfg = HRP.Config.hud or {}
    value = clamp(value)
    local fill = inverse and (100 - value) or value
    local color = cfg.accent

    if inverse then
        color = value >= 85 and cfg.danger or (value >= 65 and cfg.warning or cfg.accent)
    else
        color = value <= 15 and cfg.danger or (value <= 35 and cfg.warning or cfg.accent)
    end

    dxDrawRectangle(x, y, w, h, tocolor(0, 0, 0, 145), true)
    dxDrawRectangle(x + 1, y + 1, math.max(0, (w - 2) * (fill / 100)), h - 2, rgba(color, 220), true)
    dxDrawLine(x, y, x + w, y, rgba(cfg.accent, 120), 1, true)
    dxDrawLine(x, y + h, x + w, y + h, rgba(cfg.accent, 70), 1, true)

    drawShadowText(label, x, y - 14, x + w, y, rgba(cfg.accent, 230), 0.72, "default-bold")
    drawShadowText(tostring(math.floor(value)) .. "%", x, y - 14, x + w, y, rgba(color, 245), 0.72, "default-bold", "right")
end

local function drawScanlines(x, y, w, h)
    local cfg = HRP.Config.hud or {}
    local alpha = cfg.scanlineAlpha or 25
    for line = y + 2, y + h - 2, 4 do
        dxDrawLine(x + 2, line, x + w - 2, line, tocolor(255, 255, 255, alpha), 1, true)
    end
end

local function getVehicleSpeed()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle then return nil end
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.floor(((vx * vx + vy * vy + vz * vz) ^ 0.5) * 180)
end

local function drawCoreVitals(x, y)
    local cfg = HRP.Config.hud or {}
    local hp = clamp(getElementHealth(localPlayer))
    local armor = clamp(getPedArmor(localPlayer))

    drawPanel(x, y, 285, 152, "HEAVYRPG // VITAL MONITOR")
    drawRetroBar("HP", hp, x + 14, y + 40, 257, 12, false)
    drawRetroBar("ARMOR", armor, x + 14, y + 72, 257, 12, false)
    drawRetroBar("FOOD", HUD.needs.hunger, x + 14, y + 104, 120, 10, false)
    drawRetroBar("WATER", HUD.needs.thirst, x + 151, y + 104, 120, 10, false)
    drawRetroBar("ENERGY", HUD.needs.energy, x + 14, y + 132, 120, 10, false)
    drawRetroBar("STRESS", HUD.needs.stress, x + 151, y + 132, 120, 10, true)
    drawScanlines(x, y, 285, 152)

    if hp <= 20 or HUD.needs.thirst <= 15 or HUD.needs.hunger <= 15 then
        local flash = 90 + math.abs(math.sin(getTickCount() / 220)) * 120
        dxDrawRectangle(x, y, 285, 152, tocolor(255, 0, 0, flash * 0.25), true)
        drawShadowText("CRITICAL", x, y - 22, x + 285, y, rgba(cfg.danger, 230), 0.9, "default-bold", "right")
    end
end

local function drawMoneyPanel(x, y)
    local cfg = HRP.Config.hud or {}
    local speed = getVehicleSpeed()
    local hour, minute = getTime()
    local timeText = string.format("%02d:%02d", hour or 0, minute or 0)

    drawPanel(x, y, 285, speed and 128 or 102, "CITY TERMINAL // FINANCE")
    drawShadowText("CASH", x + 14, y + 36, x + 110, y + 52, rgba(cfg.accent, 210), 0.75, "default-bold")
    drawShadowText(money(HUD.money.cash or getPlayerMoney(localPlayer)), x + 96, y + 34, x + 270, y + 54, tocolor(235, 255, 232, 245), 0.95, "default-bold", "right")

    drawShadowText("BANK", x + 14, y + 62, x + 110, y + 78, rgba(cfg.accent, 210), 0.75, "default-bold")
    drawShadowText(money(HUD.money.bank or 0), x + 96, y + 60, x + 270, y + 80, tocolor(235, 255, 232, 245), 0.95, "default-bold", "right")

    drawShadowText("TIME", x + 14, y + 84, x + 110, y + 100, rgba(cfg.accent, 210), 0.75, "default-bold")
    drawShadowText(timeText, x + 96, y + 82, x + 270, y + 102, rgba(cfg.warning, 245), 0.95, "default-bold", "right")

    if speed then
        drawShadowText("SPEED", x + 14, y + 106, x + 110, y + 122, rgba(cfg.accent, 210), 0.75, "default-bold")
        drawShadowText(tostring(speed) .. " KM/H", x + 96, y + 104, x + 270, y + 124, rgba(cfg.warning, 245), 0.95, "default-bold", "right")
    end

    drawScanlines(x, y, 285, speed and 128 or 102)
end

local function drawMicroStatus(x, y)
    local cfg = HRP.Config.hud or {}
    local ping = getPlayerPing(localPlayer)
    local zone = getZoneName(getElementPosition(localPlayer)) or "LOS SANTOS"
    local last = math.floor((getTickCount() - (HUD.lastSync or 0)) / 1000)

    drawPanel(x, y, 285, 58, "RADIO STATUS")
    drawShadowText(zone, x + 12, y + 28, x + 190, y + 44, rgba(cfg.accent, 235), 0.78, "default-bold")
    drawShadowText("PING " .. tostring(ping) .. " | SYNC " .. tostring(last) .. "s", x + 12, y + 28, x + 270, y + 44, rgba(cfg.warning, 225), 0.72, "default-bold", "right")
    drawScanlines(x, y, 285, 58)
end

local function renderHUD()
    if not HUD.visible or not HRP.Config.hud or HRP.Config.hud.enabled == false then return end
    if isPlayerMapVisible() then return end

    HUD.sx, HUD.sy = guiGetScreenSize()
    local margin = 22
    local rightX = HUD.sx - 285 - margin
    drawCoreVitals(margin, HUD.sy - 174)
    drawMoneyPanel(rightX, margin)
    drawMicroStatus(rightX, margin + 140)
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
    HUD.money.cash = money(payload.cash) and tonumber(payload.cash) or getPlayerMoney(localPlayer)
    HUD.money.bank = tonumber(payload.bank) or HUD.money.bank or 0
    HUD.lastSync = getTickCount()
    setVisible(true)
end)

addEvent("HeavyRPG:Auth:show", true)
addEventHandler("HeavyRPG:Auth:show", resourceRoot, function()
    setVisible(false)
end)

addEvent("HeavyRPG:Character:showCreator", true)
addEventHandler("HeavyRPG:Character:showCreator", resourceRoot, function()
    setVisible(false)
end)

addEvent("HeavyRPG:Character:hideCreator", true)
addEventHandler("HeavyRPG:Character:hideCreator", resourceRoot, function()
    hideDefaultComponents()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    hideDefaultComponents()
end)

addEventHandler("onClientPlayerSpawn", localPlayer, function()
    hideDefaultComponents()
end)
