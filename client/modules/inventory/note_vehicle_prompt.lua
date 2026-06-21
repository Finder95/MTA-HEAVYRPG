HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientInventory = HRP.ClientInventory or {}
local Inv = HRP.ClientInventory

local vehicleNote = nil
local renderAttached = false
local keyAttached = false

local colors = {
    panel = { 18, 20, 22, 218 },
    paper = { 231, 212, 154, 248 },
    text = { 242, 236, 219, 255 },
    muted = { 185, 178, 156, 245 },
    border = { 170, 138, 74, 210 }
}

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function scale()
    local sx, sy = guiGetScreenSize()
    local s = math.min(sx / 1920, sy / 1080)
    return clamp(s, 0.86, 1.10), sx, sy
end

local function rgba(name, alpha)
    local c = colors[name] or colors.text
    return tocolor(c[1], c[2], c[3], alpha or c[4] or 255)
end

local function text(value, x, y, w, h, color, size, font, alignX, alignY)
    value = tostring(value or "")
    dxDrawText(value, x + 1, y + 1, w + 1, h + 1, tocolor(0, 0, 0, 180), size or 1, font or "default", alignX or "left", alignY or "top", false, true, true)
    dxDrawText(value, x, y, w, h, color, size or 1, font or "default", alignX or "left", alignY or "top", false, true, true)
end

local function box(x, y, w, h, fill, border)
    dxDrawRectangle(x, y, w, h, fill, true)
    dxDrawRectangle(x, y, w, 1, border, true)
    dxDrawRectangle(x, y + h - 1, w, 1, border, true)
    dxDrawRectangle(x, y, 1, h, border, true)
    dxDrawRectangle(x + w - 1, y, 1, h, border, true)
end

local function isVehicleNote(payload)
    return type(payload) == "table" and tostring(payload.placeType or "") == "vehicle_windshield"
end

local function drawVehicleNotePrompt()
    if not vehicleNote or Inv.visible then return end

    local s, sx, sy = scale()
    local prompt = "E - sprawdz kartke za wycieraczka"
    local w, h = math.max(360 * s, dxGetTextWidth(prompt, 0.78 * s, "default-bold") + 42 * s), 40 * s

    if vehicleNote.x and vehicleNote.y and vehicleNote.z then
        local lx, ly = getScreenFromWorldPosition(vehicleNote.x, vehicleNote.y, vehicleNote.z + 0.35)
        if lx and ly then
            local labelW = 420 * s
            text("Za wycieraczka lezy kartka", lx - labelW / 2, ly - 22 * s, lx + labelW / 2, ly + 6 * s, rgba("paper"), 0.78 * s, "default-bold", "center", "center")
            text("Nacisnij E, aby ja przeczytac", lx - labelW / 2, ly + 2 * s, lx + labelW / 2, ly + 30 * s, rgba("text", 235), 0.66 * s, "default-bold", "center", "center")
        end
    end

    box((sx - w) / 2, sy - 176 * s, w, h, rgba("panel"), rgba("border"))
    text(prompt, (sx - w) / 2, sy - 166 * s, (sx + w) / 2, sy - 136 * s, rgba("text"), 0.78 * s, "default-bold", "center", "center")
end

local function handleVehicleNoteKey(button, press)
    if not press or not vehicleNote or Inv.visible then return end
    if tostring(button or ""):lower() ~= "e" then return end
    triggerServerEvent("HeavyRPG:Inventory:readPlacedNote", resourceRoot, vehicleNote.id)
    cancelEvent()
end

addEvent("HeavyRPG:Inventory:nearPlacedNote", true)
addEventHandler("HeavyRPG:Inventory:nearPlacedNote", resourceRoot, function(state, payload)
    if state and isVehicleNote(payload) then
        vehicleNote = payload
        Inv.nearPlacedNote = nil
    elseif not state then
        vehicleNote = nil
    end
end, false, "low")

addEvent("HeavyRPG:Inventory:placedNotePanel", true)
addEventHandler("HeavyRPG:Inventory:placedNotePanel", resourceRoot, function(payload)
    if isVehicleNote(payload) and Inv.action then
        Inv.action.title = "Kartka za wycieraczka"
    end
end, false, "low")

addEventHandler("onClientResourceStart", resourceRoot, function()
    if not renderAttached then
        addEventHandler("onClientRender", root, drawVehicleNotePrompt)
        renderAttached = true
    end
    if not keyAttached then
        addEventHandler("onClientKey", root, handleVehicleNoteKey)
        keyAttached = true
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if renderAttached then
        removeEventHandler("onClientRender", root, drawVehicleNotePrompt)
        renderAttached = false
    end
    if keyAttached then
        removeEventHandler("onClientKey", root, handleVehicleNoteKey)
        keyAttached = false
    end
    vehicleNote = nil
end)
