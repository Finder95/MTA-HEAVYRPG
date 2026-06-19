HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientHUD = HRP.ClientHUD or {
    visible = false,
    needs = { hunger = 100, thirst = 100, energy = 100, hygiene = 100, stress = 0 },
    money = { cash = 0, bank = 0 },
    sx = 0,
    sy = 0,
    lastSync = 0,
    textures = {}
}

local HUD = HRP.ClientHUD
local hiddenComponents = { "ammo", "area_name", "armour", "breath", "clock", "health", "money", "radar", "vehicle_name", "weapon" }
local texturePaths = {
    health = "assets/hud/health.png",
    armor = "assets/hud/armor.png",
    hunger = "assets/hud/hunger.png",
    thirst = "assets/hud/thirst.png",
    energy = "assets/hud/energy.png",
    hygiene = "assets/hud/hygiene.png",
    stress = "assets/hud/stress.png"
}

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
    local scale = math.min(sx / 1920, sy / 1080)
    if scale < 0.90 then scale = 0.90 end
    if scale > 1.18 then scale = 1.18 end
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

local function loadTextures()
    for name, path in pairs(texturePaths) do
        if not HUD.textures[name] or not isElement(HUD.textures[name]) then
            HUD.textures[name] = dxCreateTexture(path, "argb", true, "clamp")
        end
    end
end

local function destroyTextures()
    for name, texture in pairs(HUD.textures or {}) do
        if isElement(texture) then destroyElement(texture) end
        HUD.textures[name] = nil
    end
end

local function drawIcon(kind, x, y, size, iconColor)
    local texture = HUD.textures and HUD.textures[kind]
    if texture and isElement(texture) then
        dxDrawImage(x, y, size, size, texture, 0, 0, 0, iconColor, true)
        return
    end

    dxDrawRectangle(x + size * 0.32, y + size * 0.32, size * 0.36, size * 0.36, iconColor, true)
end

local function drawStatusBar(kind, label, value, x, y, w, h, barColorName, inverse, scale)
    value = clamp(value)
    local fill = inverse and (100 - value) or value
    local danger = (not inverse and value <= 18) or (inverse and value >= 82)
    local fillColor = danger and color("danger", 235) or color(barColorName, 228)
    local iconSize = 20 * scale
    local barX = x + iconSize + 9 * scale
    local barY = y + 10 * scale
    local labelScale = 0.66 * scale

    drawIcon(kind, x, y + 3 * scale, iconSize, fillColor)
    shadowText(label, barX, y - 2 * scale, barX + w, y + 15 * scale, color("text", 218), labelScale, "default-bold")
    shadowText(tostring(math.floor(value)), barX, y - 2 * scale, barX + w, y + 15 * scale, danger and color("danger", 240) or color("muted", 220), labelScale, "default-bold", "right")

    dxDrawRectangle(barX, barY, w, h, color("barBack", 142), true)
    dxDrawRectangle(barX, barY, math.max(3 * scale, w * (fill / 100)), h, fillColor, true)
    dxDrawRectangle(barX, barY + h - math.max(1, scale), w, math.max(1, scale), tocolor(0, 0, 0, 115), true)
end

local function getVehicleSpeed()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle then return nil end
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.floor(((vx * vx + vy * vy + vz * vz) ^ 0.5) * 180)
end

local function drawStatusCluster(scale, sx)
    local margin = 34 * scale
    local row = 30 * scale
    local barW = 220 * scale
    local barH = 9 * scale
    local iconSize = 20 * scale
    local totalW = iconSize + 9 * scale + barW
    local x = sx - margin - totalW
    local y = 102 * scale

    drawStatusBar("health", "Zdrowie", getElementHealth(localPlayer), x, y, barW, barH, "health", false, scale)
    drawStatusBar("armor", "Pancerz", getPedArmor(localPlayer), x, y + row, barW, barH, "armor", false, scale)
    drawStatusBar("hunger", "Glod", HUD.needs.hunger, x, y + row * 2, barW, barH, "hunger", false, scale)
    drawStatusBar("thirst", "Pragnienie", HUD.needs.thirst, x, y + row * 3, barW, barH, "thirst", false, scale)
    drawStatusBar("energy", "Energia", HUD.needs.energy, x, y + row * 4, barW, barH, "energy", false, scale)
    drawStatusBar("hygiene", "Higiena", HUD.needs.hygiene, x, y + row * 5, barW, barH, "hygiene", false, scale)
    drawStatusBar("stress", "Stres", HUD.needs.stress, x, y + row * 6, barW, barH, "stress", true, scale)
end

local function drawMoneyBlock(scale, sx)
    local speed = getVehicleSpeed()
    local hour, minute = getTime()
    local x = sx - 34 * scale
    local y = 24 * scale
    local textScale = 0.76 * scale
    local smallScale = 0.66 * scale
    local lineH = 18 * scale

    shadowText("Gotowka " .. money(HUD.money.cash or getPlayerMoney(localPlayer)), x - 300 * scale, y, x, y + lineH, color("cash", 235), textScale, "default-bold", "right")
    shadowText("Konto " .. money(HUD.money.bank or 0), x - 300 * scale, y + lineH, x, y + lineH * 2, color("text", 220), smallScale, "default-bold", "right")
    shadowText(string.format("%02d:%02d", hour or 0, minute or 0), x - 150 * scale, y + lineH * 2, x, y + lineH * 3, color("muted", 220), smallScale, "default-bold", "right")

    if speed then
        shadowText(tostring(speed) .. " km/h", x - 150 * scale, y + lineH * 3, x, y + lineH * 4, color("text", 220), textScale, "default-bold", "right")
    end
end

local function renderHUD()
    if not HUD.visible or not HRP.Config.hud or HRP.Config.hud.enabled == false then return end
    if isPlayerMapVisible() then return end

    local scale, sx, sy = uiScale()
    HUD.sx, HUD.sy = sx, sy
    drawMoneyBlock(scale, sx)
    drawStatusCluster(scale, sx)
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
        loadTextures()
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
    loadTextures()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    destroyTextures()
end)

addEventHandler("onClientPlayerSpawn", localPlayer, function()
    hideDefaultComponents()
end)
