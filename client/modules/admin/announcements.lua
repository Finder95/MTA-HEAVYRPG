HeavyRPG = HeavyRPG or {}

local announcement = nil
local DURATION_MS = 8500

local function color(r, g, b, a)
    return tocolor(r, g, b, a or 255)
end

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function drawTextShadow(text, x1, y1, x2, y2, textColor, scale, font, alignX, alignY)
    dxDrawText(text, x1 + 1, y1 + 1, x2 + 1, y2 + 1, color(0, 0, 0, 180), scale, font, alignX, alignY, true, true, true)
    dxDrawText(text, x1, y1, x2, y2, textColor, scale, font, alignX, alignY, true, true, true)
end

local function renderAnnouncement()
    if not announcement then return end

    local age = getTickCount() - announcement.startedAt
    if age >= DURATION_MS then
        announcement = nil
        removeEventHandler("onClientRender", root, renderAnnouncement)
        return
    end

    local sx, sy = guiGetScreenSize()
    local ui = clamp(sy / 1080, 0.78, 1.15)
    local alpha = 255
    if age < 300 then alpha = math.floor(255 * (age / 300)) end
    if age > DURATION_MS - 650 then alpha = math.floor(255 * ((DURATION_MS - age) / 650)) end
    alpha = clamp(alpha, 0, 255)

    local width = math.min(sx * 0.72, 1040 * ui)
    local height = 92 * ui
    local x = (sx - width) / 2
    local y = 42 * ui
    local accent = color(212, 184, 120, alpha)
    local paper = color(28, 27, 24, math.floor(alpha * 0.88))
    local line = color(235, 226, 198, math.floor(alpha * 0.42))

    dxDrawRectangle(x, y, width, height, paper, true)
    dxDrawRectangle(x, y, width, 2 * ui, accent, true)
    dxDrawRectangle(x, y + height - 2 * ui, width, 2 * ui, color(0, 0, 0, math.floor(alpha * 0.35)), true)
    dxDrawLine(x + 18 * ui, y + 30 * ui, x + width - 18 * ui, y + 30 * ui, line, 1, true)

    drawTextShadow("OGLOSZENIE ADMINISTRACJI", x + 22 * ui, y + 7 * ui, x + width - 22 * ui, y + 28 * ui, color(212, 184, 120, alpha), 0.88 * ui, "default-bold", "left", "center")
    drawTextShadow(tostring(announcement.message or ""), x + 22 * ui, y + 34 * ui, x + width - 22 * ui, y + height - 12 * ui, color(244, 239, 224, alpha), 1.02 * ui, "default-bold", "center", "center")
    drawTextShadow("Nadawca: " .. tostring(announcement.admin or "Administracja"), x + width - 300 * ui, y + 7 * ui, x + width - 22 * ui, y + 28 * ui, color(196, 190, 175, math.floor(alpha * 0.9)), 0.72 * ui, "default", "right", "center")
end

addEvent("HeavyRPG:Admin:announcement", true)
addEventHandler("HeavyRPG:Admin:announcement", resourceRoot, function(data)
    data = type(data) == "table" and data or {}
    announcement = {
        message = tostring(data.message or ""),
        admin = tostring(data.admin or "Administracja"),
        startedAt = getTickCount()
    }

    removeEventHandler("onClientRender", root, renderAnnouncement)
    addEventHandler("onClientRender", root, renderAnnouncement)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    removeEventHandler("onClientRender", root, renderAnnouncement)
end)
