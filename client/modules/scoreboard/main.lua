HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientScoreboard = HRP.ClientScoreboard or {
    visible = false,
    rows = {},
    lastRequest = 0,
    sx = 0,
    sy = 0
}

local Scoreboard = HRP.ClientScoreboard

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function uiScale()
    local sx, sy = guiGetScreenSize()
    local scale = math.min(sx / 1920, sy / 1080)
    scale = clamp(scale, 0.88, 1.12)
    Scoreboard.sx, Scoreboard.sy = sx, sy
    return scale, sx, sy
end

local function color(r, g, b, a)
    return tocolor(r or 255, g or 255, b or 255, a or 255)
end

local function text(value, fallback)
    value = tostring(value or fallback or "-")
    value = value:gsub("#%x%x%x%x%x%x", ""):gsub("[%c\r\n]", " ")
    value = value:gsub("%s+", " ")
    if value == "" then return fallback or "-" end
    return value
end

local function shadowText(value, x, y, w, h, textColor, scale, font, alignX, alignY, clip)
    dxDrawText(value, x + 1, y + 1, w + 1, h + 1, color(0, 0, 0, 180), scale, font, alignX, alignY, clip == true, false, true)
    dxDrawText(value, x, y, w, h, textColor, scale, font, alignX, alignY, clip == true, false, true)
end

local function requestRows(force)
    local now = getTickCount()
    if not force and now - Scoreboard.lastRequest < 1200 then return end

    Scoreboard.lastRequest = now
    triggerServerEvent("HeavyRPG:Scoreboard:request", resourceRoot)
end

local function drawRow(row, index, x, y, w, h, scale)
    local isReady = row and row.ready == true
    local rowAlpha = isReady and 152 or 92
    local lineColor = index % 2 == 0 and color(255, 255, 255, 18) or color(255, 255, 255, 10)

    dxDrawRectangle(x, y, w, h, lineColor, true)
    dxDrawRectangle(x, y + h - 1, w, 1, color(255, 255, 255, 18), true)

    local statusColor = isReady and color(190, 157, 87, 235) or color(138, 130, 111, 210)
    dxDrawRectangle(x + 14 * scale, y + 14 * scale, 6 * scale, h - 28 * scale, statusColor, true)

    local character = text(row and row.characterName, "Bez postaci")
    local login = text(row and row.login, "niezalogowany")
    local ping = tostring(math.floor(tonumber(row and row.ping) or 0)) .. " ms"

    shadowText(character, x + 34 * scale, y + 8 * scale, x + w * 0.56, y + h - 8 * scale, color(232, 224, 207, rowAlpha + 80), 0.90 * scale, "default-bold", "left", "center", true)
    shadowText(login, x + w * 0.57, y + 8 * scale, x + w * 0.82, y + h - 8 * scale, color(190, 176, 124, rowAlpha + 45), 0.82 * scale, "default-bold", "left", "center", true)
    shadowText(ping, x + w * 0.84, y + 8 * scale, x + w - 20 * scale, y + h - 8 * scale, color(138, 130, 111, rowAlpha + 50), 0.78 * scale, "default-bold", "right", "center", true)
end

local function renderScoreboard()
    if not Scoreboard.visible then return end
    requestRows(false)

    local scale, sx, sy = uiScale()
    local rows = Scoreboard.rows or {}
    local maxRows = math.min(math.max(#rows, 1), 12)
    local w = math.min(760 * scale, sx - 72 * scale)
    local rowH = 46 * scale
    local headerH = 88 * scale
    local footerH = 28 * scale
    local h = headerH + rowH * maxRows + footerH
    local x = (sx - w) / 2
    local y = math.max(52 * scale, (sy - h) / 2)

    dxDrawRectangle(x - 8 * scale, y - 8 * scale, w + 16 * scale, h + 16 * scale, color(0, 0, 0, 86), true)
    dxDrawRectangle(x, y, w, h, color(13, 12, 10, 224), true)
    dxDrawRectangle(x, y, w, 3 * scale, color(190, 157, 87, 230), true)
    dxDrawRectangle(x, y + headerH - 1, w, 1, color(255, 255, 255, 28), true)

    shadowText("HeavyRPG", x + 22 * scale, y + 16 * scale, x + w - 22 * scale, y + 34 * scale, color(190, 157, 87, 238), 0.72 * scale, "default-bold", "left", "top", true)
    shadowText("Gracze online", x + 22 * scale, y + 34 * scale, x + w - 22 * scale, y + 64 * scale, color(238, 232, 219, 245), 1.24 * scale, "default-bold", "left", "top", true)
    shadowText(tostring(#rows) .. " online", x + 22 * scale, y + 40 * scale, x + w - 22 * scale, y + 64 * scale, color(138, 130, 111, 230), 0.78 * scale, "default-bold", "right", "top", true)

    local labelY = y + 66 * scale
    shadowText("POSTAC", x + 34 * scale, labelY, x + w * 0.56, y + headerH - 8 * scale, color(138, 130, 111, 230), 0.68 * scale, "default-bold", "left", "center", true)
    shadowText("LOGIN", x + w * 0.57, labelY, x + w * 0.82, y + headerH - 8 * scale, color(138, 130, 111, 230), 0.68 * scale, "default-bold", "left", "center", true)
    shadowText("PING", x + w * 0.84, labelY, x + w - 20 * scale, y + headerH - 8 * scale, color(138, 130, 111, 230), 0.68 * scale, "default-bold", "right", "center", true)

    local listY = y + headerH
    if #rows == 0 then
        shadowText("Brak danych graczy.", x + 22 * scale, listY, x + w - 22 * scale, listY + rowH, color(138, 130, 111, 230), 0.90 * scale, "default-bold", "center", "center", true)
    else
        for index = 1, maxRows do
            drawRow(rows[index], index, x, listY + rowH * (index - 1), w, rowH, scale)
        end
    end

    shadowText("TAB - zamknij", x + 22 * scale, y + h - footerH + 6 * scale, x + w - 22 * scale, y + h - 6 * scale, color(138, 130, 111, 210), 0.68 * scale, "default-bold", "right", "center", true)
end

local function setVisible(state)
    state = state == true
    if Scoreboard.visible == state then return end

    Scoreboard.visible = state
    if state then
        requestRows(true)
        addEventHandler("onClientRender", root, renderScoreboard)
    else
        removeEventHandler("onClientRender", root, renderScoreboard)
    end
end

local function handleTabKey(button, press)
    if tostring(button or ""):lower() ~= "tab" then return end
    cancelEvent()
    setVisible(press == true)
end

addEvent("HeavyRPG:Scoreboard:update", true)
addEventHandler("HeavyRPG:Scoreboard:update", resourceRoot, function(rows)
    Scoreboard.rows = type(rows) == "table" and rows or {}
end)

addEventHandler("onClientKey", root, handleTabKey, true, "high+1000")
addEventHandler("onClientResourceStop", resourceRoot, function()
    setVisible(false)
end)
