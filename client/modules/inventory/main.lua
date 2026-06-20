HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientInventory = HRP.ClientInventory or {
    visible = false,
    items = {},
    categories = {},
    selected = 1,
    scroll = 0,
    category = "all",
    currentWeight = 0,
    maxWeight = 35,
    sx = 0,
    sy = 0,
    x = 0,
    y = 0,
    w = 860,
    h = 560,
    rowH = 26
}

local Inv = HRP.ClientInventory
local clickAttached = false
local fallbackCategories = { all = "Wszystko", documents = "Dokumenty", consumable = "Jedzenie", medical = "Medyczne", utility = "Uzytkowe", illegal = "Nielegalne", misc = "Inne" }

local function cfg() return HRP.Config.inventory or {} end
local function clamp(v, minV, maxV) v = tonumber(v) or minV or 0 if v < minV then return minV end if v > maxV then return maxV end return v end
local function weightText(v) return string.format("%.2f kg", tonumber(v) or 0) end

local function uiScale()
    local sx, sy = guiGetScreenSize()
    local scale = math.min(sx / 1920, sy / 1080)
    if scale < 0.86 then scale = 0.86 end
    if scale > 1.16 then scale = 1.16 end
    return scale, sx, sy
end

local function color(name, alpha)
    local value = ((cfg().palette or {})[name]) or { 220, 210, 190 }
    return tocolor(value[1] or 255, value[2] or 255, value[3] or 255, alpha or value[4] or 255)
end

local function shadowText(text, x, y, w, h, textColor, scale, font, alignX, alignY, clip, wordBreak)
    dxDrawText(tostring(text or ""), x + 1, y + 1, w + 1, h + 1, tocolor(0, 0, 0, 190), scale or 1, font or "default", alignX or "left", alignY or "top", clip == true, wordBreak == true, true)
    dxDrawText(tostring(text or ""), x, y, w, h, textColor, scale or 1, font or "default", alignX or "left", alignY or "top", clip == true, wordBreak == true, true)
end

local function panelRect(x, y, w, h, fill, border)
    dxDrawRectangle(x, y, w, h, fill, true)
    dxDrawRectangle(x, y, w, 1, border, true)
    dxDrawRectangle(x, y + h - 1, w, 1, border, true)
    dxDrawRectangle(x, y, 1, h, border, true)
    dxDrawRectangle(x + w - 1, y, 1, h, border, true)
end

local function rebuildBounds()
    local scale, sx, sy = uiScale()
    Inv.sx, Inv.sy = sx, sy
    Inv.w = math.floor(clamp(860 * scale, 720, sx - 48))
    Inv.h = math.floor(clamp(560 * scale, 480, sy - 48))
    Inv.x = math.floor((sx - Inv.w) / 2)
    Inv.y = math.floor((sy - Inv.h) / 2)
    Inv.rowH = math.floor(26 * scale)
    return scale
end

local function categoryLabel(id)
    for _, category in ipairs(Inv.categories or {}) do
        if tostring(category.id or "") == tostring(id) then return tostring(category.label or fallbackCategories[id] or id) end
    end
    return fallbackCategories[id] or tostring(id)
end

local function categoryOrder()
    local out, seen = { "all" }, { all = true }
    for _, category in ipairs(Inv.categories or {}) do
        local id = tostring(category.id or category)
        if not seen[id] then out[#out + 1], seen[id] = id, true end
    end
    for _, item in ipairs(Inv.items or {}) do
        local id = tostring(item.category or "misc")
        if not seen[id] then out[#out + 1], seen[id] = id, true end
    end
    return out
end

local function filteredItems()
    local list = {}
    for _, item in ipairs(Inv.items or {}) do
        if Inv.category == "all" or item.category == Inv.category then list[#list + 1] = item end
    end
    return list
end

local function maxVisibleRows()
    local scale = uiScale()
    return math.max(5, math.floor((Inv.h - 188 * scale) / Inv.rowH))
end

local function normalizeSelection(list)
    list = list or filteredItems()
    local rows = maxVisibleRows()
    local maxScroll = math.max(0, #list - rows)
    if #list == 0 then Inv.selected, Inv.scroll = 1, 0 return end
    Inv.selected = clamp(Inv.selected, 1, #list)
    Inv.scroll = clamp(Inv.scroll, 0, maxScroll)
    if Inv.selected < Inv.scroll + 1 then Inv.scroll = math.max(0, Inv.selected - 1) end
    if Inv.selected > Inv.scroll + rows then Inv.scroll = math.max(0, Inv.selected - rows) end
end

local function selectedItem()
    local list = filteredItems()
    normalizeSelection(list)
    return list[Inv.selected], list
end

local function drawWeightBar(x, y, w, h)
    local ratio = 0
    if (Inv.maxWeight or 0) > 0 then ratio = clamp((Inv.currentWeight or 0) / Inv.maxWeight, 0, 1) end
    dxDrawRectangle(x, y, w, h, color("barBack", 165), true)
    dxDrawRectangle(x, y, math.max(2, w * ratio), h, ratio > 0.92 and color("danger", 235) or color("accent", 220), true)
    dxDrawRectangle(x, y + h - 1, w, 1, tocolor(0, 0, 0, 160), true)
end

local function drawCategories(scale)
    local x, y, h = Inv.x + 18 * scale, Inv.y + 70 * scale, 25 * scale
    for _, id in ipairs(categoryOrder()) do
        local label = categoryLabel(id)
        local w = math.max(82 * scale, dxGetTextWidth(label, 0.72 * scale, "default-bold") + 18 * scale)
        local active = Inv.category == id
        dxDrawRectangle(x, y, w, h, active and color("rowActive", 210) or color("row", 112), true)
        shadowText(label, x, y + 4 * scale, x + w, y + h, active and color("text", 245) or color("muted", 220), 0.72 * scale, "default-bold", "center")
        x = x + w + 6 * scale
    end
end

local function drawList(scale, list)
    local x, y, w = Inv.x + 18 * scale, Inv.y + 108 * scale, Inv.w * 0.58
    local headerH, rows = 24 * scale, maxVisibleRows()
    panelRect(x, y, w, Inv.rowH * rows + headerH + 2, color("panel", 186), color("line", 165))
    shadowText("PRZEDMIOT", x + 10 * scale, y + 5 * scale, x + w, y + headerH, color("muted", 230), 0.68 * scale, "default-bold")
    shadowText("IL.", x + w - 142 * scale, y + 5 * scale, x + w - 98 * scale, y + headerH, color("muted", 230), 0.68 * scale, "default-bold", "right")
    shadowText("WAGA", x + w - 92 * scale, y + 5 * scale, x + w - 18 * scale, y + headerH, color("muted", 230), 0.68 * scale, "default-bold", "right")

    for row = 1, rows do
        local index = Inv.scroll + row
        local item = list[index]
        local rowY = y + headerH + (row - 1) * Inv.rowH
        dxDrawRectangle(x + 1, rowY, w - 2, Inv.rowH - 1, index == Inv.selected and color("rowActive", 210) or ((row % 2 == 0) and color("rowAlt", 92) or color("row", 75)), true)
        if item then
            local qColor = (tonumber(item.quality) or 100) <= 25 and color("danger", 230) or color("text", 230)
            shadowText(item.label, x + 10 * scale, rowY + 5 * scale, x + w - 152 * scale, rowY + Inv.rowH, color("text", 235), 0.72 * scale, "default-bold", "left", "top", true)
            shadowText("x" .. tostring(item.quantity or 1), x + w - 142 * scale, rowY + 5 * scale, x + w - 98 * scale, rowY + Inv.rowH, qColor, 0.72 * scale, "default-bold", "right")
            shadowText(weightText(item.totalWeight), x + w - 94 * scale, rowY + 5 * scale, x + w - 18 * scale, rowY + Inv.rowH, color("muted", 230), 0.72 * scale, "default-bold", "right")
        end
    end
    if #list == 0 then shadowText("Brak przedmiotow w tej kategorii.", x, y + headerH + 40 * scale, x + w, y + headerH + 80 * scale, color("muted", 230), 0.82 * scale, "default-bold", "center", "center") end
end

local function drawDetails(scale, item)
    local x, y = Inv.x + Inv.w * 0.62, Inv.y + 108 * scale
    local w, h = Inv.w - (x - Inv.x) - 18 * scale, Inv.h - 178 * scale
    panelRect(x, y, w, h, color("panel", 176), color("line", 165))
    if not item then shadowText("Wybierz przedmiot", x + 18 * scale, y + 26 * scale, x + w - 18 * scale, y + 70 * scale, color("muted", 230), 0.9 * scale, "default-bold", "center", "center") return end

    shadowText(item.label, x + 18 * scale, y + 16 * scale, x + w - 18 * scale, y + 42 * scale, color("text", 245), 0.94 * scale, "default-bold", "left", "top", true)
    shadowText(categoryLabel(item.category), x + 18 * scale, y + 44 * scale, x + w - 18 * scale, y + 65 * scale, color("accent", 230), 0.7 * scale, "default-bold")

    local yy = y + 82 * scale
    local rows = { { "Ilosc", "x" .. tostring(item.quantity or 1) }, { "Waga", weightText(item.totalWeight) .. " / " .. weightText(item.weight or 0) .. " szt." }, { "Jakosc", tostring(item.quality or 100) .. "%" }, { "Stan", tostring(item.state or "normal") }, { "UID", "#" .. tostring(item.uid or "-") } }
    for _, row in ipairs(rows) do
        shadowText(row[1], x + 18 * scale, yy, x + 112 * scale, yy + 20 * scale, color("muted", 220), 0.7 * scale, "default-bold")
        shadowText(row[2], x + 112 * scale, yy, x + w - 18 * scale, yy + 20 * scale, color("text", 232), 0.7 * scale, "default-bold", "right")
        yy = yy + 24 * scale
    end

    yy = yy + 10 * scale
    shadowText("OPIS", x + 18 * scale, yy, x + w - 18 * scale, yy + 20 * scale, color("muted", 230), 0.68 * scale, "default-bold")
    shadowText(item.description or "Brak opisu.", x + 18 * scale, yy + 24 * scale, x + w - 18 * scale, y + h - 96 * scale, color("text", 225), 0.72 * scale, "default", "left", "top", true, true)

    local actionY = y + h - 72 * scale
    shadowText("ENTER", x + 18 * scale, actionY, x + 88 * scale, actionY + 22 * scale, item.usable and color("accent", 220) or color("muted", 150), 0.72 * scale, "default-bold")
    shadowText(item.usable and "Uzyj" or "Brak akcji", x + 90 * scale, actionY, x + w - 18 * scale, actionY + 22 * scale, color("text", 220), 0.72 * scale, "default-bold")
    shadowText("BACKSPACE", x + 18 * scale, actionY + 26 * scale, x + 118 * scale, actionY + 48 * scale, color("danger", 220), 0.72 * scale, "default-bold")
    shadowText("Wyrzuc 1 szt.", x + 120 * scale, actionY + 26 * scale, x + w - 18 * scale, actionY + 48 * scale, color("text", 220), 0.72 * scale, "default-bold")
end

local function renderInventory()
    if not Inv.visible or isPlayerMapVisible() then return end
    local scale = rebuildBounds()
    local item, list = selectedItem()
    dxDrawRectangle(0, 0, Inv.sx, Inv.sy, tocolor(0, 0, 0, 88), true)
    panelRect(Inv.x, Inv.y, Inv.w, Inv.h, color("background", 224), color("line", 210))
    shadowText("EKWIPUNEK POSTACI", Inv.x + 18 * scale, Inv.y + 16 * scale, Inv.x + Inv.w, Inv.y + 42 * scale, color("text", 245), 1.0 * scale, "default-bold")
    shadowText("tekstowy system RP", Inv.x + 18 * scale, Inv.y + 40 * scale, Inv.x + Inv.w, Inv.y + 62 * scale, color("muted", 220), 0.68 * scale, "default-bold")
    local weightX, weightY = Inv.x + Inv.w - 260 * scale, Inv.y + 24 * scale
    shadowText(weightText(Inv.currentWeight) .. " / " .. weightText(Inv.maxWeight), weightX, weightY - 18 * scale, Inv.x + Inv.w - 18 * scale, weightY, color("text", 232), 0.72 * scale, "default-bold", "right")
    drawWeightBar(weightX, weightY + 4 * scale, 240 * scale, 8 * scale)
    drawCategories(scale)
    drawList(scale, list)
    drawDetails(scale, item)
    shadowText("I / ESC - zamknij    TAB - kategoria    ENTER - uzyj    BACKSPACE - wyrzuc 1    DEL - wyrzuc stos", Inv.x + 18 * scale, Inv.y + Inv.h - 48 * scale, Inv.x + Inv.w - 18 * scale, Inv.y + Inv.h - 24 * scale, color("muted", 225), 0.68 * scale, "default-bold", "center")
end

local function requestSync() triggerServerEvent("HeavyRPG:Inventory:request", resourceRoot) end

function Inv.handleClick(button, state, absX, absY)
    if not Inv.visible or button ~= "left" or state ~= "down" then return end
    local scale = uiScale()
    local list = filteredItems()
    local listX, listY, listW = Inv.x + 18 * scale, Inv.y + 108 * scale, Inv.w * 0.58
    local headerH, rows = 24 * scale, maxVisibleRows()
    if absX >= listX and absX <= listX + listW and absY >= listY + headerH and absY <= listY + headerH + rows * Inv.rowH then
        local index = Inv.scroll + math.floor((absY - listY - headerH) / Inv.rowH) + 1
        if list[index] then Inv.selected = index end
    end
end

local function setVisible(state)
    state = state == true
    if Inv.visible == state then return end
    Inv.visible = state
    showCursor(state)
    if state then
        rebuildBounds()
        requestSync()
        addEventHandler("onClientRender", root, renderInventory)
        if not clickAttached then addEventHandler("onClientClick", root, Inv.handleClick) clickAttached = true end
    else
        removeEventHandler("onClientRender", root, renderInventory)
        if clickAttached then removeEventHandler("onClientClick", root, Inv.handleClick) clickAttached = false end
    end
end

local function canToggle()
    if isChatBoxInputActive and isChatBoxInputActive() then return false end
    if isConsoleActive and isConsoleActive() then return false end
    if isMainMenuActive and isMainMenuActive() then return false end
    return true
end

local function nextCategory()
    local cats, current = categoryOrder(), 1
    for index, id in ipairs(cats) do if id == Inv.category then current = index break end end
    current = current + 1
    if current > #cats then current = 1 end
    Inv.category, Inv.selected, Inv.scroll = cats[current], 1, 0
end

local function moveSelection(offset)
    local list = filteredItems()
    if #list == 0 then return end
    Inv.selected = clamp(Inv.selected + offset, 1, #list)
    normalizeSelection(list)
end

local function selectedAction(action)
    local item = selectedItem()
    if not item then return end
    if action == "use" and item.usable then triggerServerEvent("HeavyRPG:Inventory:use", resourceRoot, item.uid) end
    if action == "drop_one" then triggerServerEvent("HeavyRPG:Inventory:drop", resourceRoot, item.uid, 1) end
    if action == "drop_stack" then triggerServerEvent("HeavyRPG:Inventory:drop", resourceRoot, item.uid, item.quantity or 1) end
end

local function handleKey(button, press)
    if not press then return end
    button = tostring(button or ""):lower()

    if button == tostring(cfg().key or "i") then
        if not canToggle() then return end
        setVisible(not Inv.visible)
        cancelEvent()
        return
    end

    if not Inv.visible then return end
    if button == "escape" then setVisible(false) cancelEvent()
    elseif button == "arrow_u" then moveSelection(-1) cancelEvent()
    elseif button == "arrow_d" then moveSelection(1) cancelEvent()
    elseif button == "mouse_wheel_up" then moveSelection(-3) cancelEvent()
    elseif button == "mouse_wheel_down" then moveSelection(3) cancelEvent()
    elseif button == "tab" then nextCategory() cancelEvent()
    elseif button == "enter" then selectedAction("use") cancelEvent()
    elseif button == "backspace" then selectedAction("drop_one") cancelEvent()
    elseif button == "delete" then selectedAction("drop_stack") cancelEvent() end
end

addEvent("HeavyRPG:Inventory:sync", true)
addEventHandler("HeavyRPG:Inventory:sync", resourceRoot, function(payload)
    payload = type(payload) == "table" and payload or {}
    Inv.items = type(payload.items) == "table" and payload.items or {}
    Inv.categories = type(payload.categories) == "table" and payload.categories or {}
    Inv.currentWeight = tonumber(payload.currentWeight) or 0
    Inv.maxWeight = tonumber(payload.maxWeight) or 35
    normalizeSelection(filteredItems())
end)

addEvent("HeavyRPG:Inventory:open", true)
addEventHandler("HeavyRPG:Inventory:open", resourceRoot, function() setVisible(true) end)
addEventHandler("HeavyRPG:Auth:show", resourceRoot, function() setVisible(false) end)
addEventHandler("HeavyRPG:Character:showCreator", resourceRoot, function() setVisible(false) end)
addEventHandler("onClientResourceStart", resourceRoot, function() addEventHandler("onClientKey", root, handleKey) end)
addEventHandler("onClientResourceStop", resourceRoot, function() removeEventHandler("onClientKey", root, handleKey) setVisible(false) end)
