HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientInventory = HRP.ClientInventory or {
    visible = false,
    blocked = true,
    items = {},
    categories = {},
    categoryBounds = {},
    actionBounds = {},
    selected = 1,
    scroll = 0,
    category = "all",
    currentWeight = 0,
    maxWeight = 35,
    nearDrop = nil,
    action = nil,
    editing = false,
    editText = "",
    sx = 0,
    sy = 0,
    x = 0,
    y = 0,
    w = 980,
    h = 620,
    rowH = 30
}

local Inv = HRP.ClientInventory
local clickAttached = false
local overlayAttached = false
local characterAttached = false
local fallbackCategories = { all = "Wszystko", money = "Gotowka", documents = "Dokumenty", consumable = "Jedzenie", medical = "Medyczne", utility = "Uzytkowe", illegal = "Nielegalne", misc = "Inne" }
local utilityItems = { cash = true, id_card = true, phone = true, notebook = true, lockpick = true }

local modern = {
    backdrop = { 8, 10, 12, 118 },
    background = { 18, 20, 22, 238 },
    panel = { 25, 28, 30, 226 },
    panelSoft = { 31, 35, 38, 210 },
    row = { 33, 37, 40, 144 },
    rowAlt = { 29, 32, 35, 132 },
    rowActive = { 79, 92, 93, 230 },
    line = { 86, 99, 99, 185 },
    text = { 232, 229, 219 },
    muted = { 154, 158, 154 },
    accent = { 183, 158, 96 },
    action = { 78, 105, 104 },
    danger = { 178, 72, 64 },
    barBack = { 10, 12, 13, 210 }
}

local function cfg() return HRP.Config.inventory or {} end
local function clamp(v, minV, maxV) v = tonumber(v) or minV or 0 if v < minV then return minV end if v > maxV then return maxV end return v end
local function weightText(v) return string.format("%.2f kg", tonumber(v) or 0) end
local function moneyText(v) return "$" .. tostring(math.floor(tonumber(v) or 0)) end

local function uiScale()
    local sx, sy = guiGetScreenSize()
    local scale = math.min(sx / 1920, sy / 1080)
    if scale < 0.86 then scale = 0.86 end
    if scale > 1.10 then scale = 1.10 end
    return scale, sx, sy
end

local function color(name, alpha)
    local value = modern[name] or ((cfg().palette or {})[name]) or modern.text
    return tocolor(value[1] or 255, value[2] or 255, value[3] or 255, alpha or value[4] or 255)
end

local function shadowText(text, x, y, w, h, textColor, scale, font, alignX, alignY, clip, wordBreak)
    dxDrawText(tostring(text or ""), x + 1, y + 1, w + 1, h + 1, tocolor(0, 0, 0, 170), scale or 1, font or "default", alignX or "left", alignY or "top", clip == true, wordBreak == true, true)
    dxDrawText(tostring(text or ""), x, y, w, h, textColor, scale or 1, font or "default", alignX or "left", alignY or "top", clip == true, wordBreak == true, true)
end

local function box(x, y, w, h, fill, border)
    dxDrawRectangle(x, y, w, h, fill, true)
    dxDrawRectangle(x, y, w, 1, border, true)
    dxDrawRectangle(x, y + h - 1, w, 1, border, true)
    dxDrawRectangle(x, y, 1, h, border, true)
    dxDrawRectangle(x + w - 1, y, 1, h, border, true)
end

local function rebuildBounds()
    local scale, sx, sy = uiScale()
    Inv.sx, Inv.sy = sx, sy
    Inv.w = math.floor(clamp(980 * scale, 820, sx - 64))
    Inv.h = math.floor(clamp(620 * scale, 520, sy - 64))
    Inv.x = math.floor((sx - Inv.w) / 2)
    Inv.y = math.floor((sy - Inv.h) / 2)
    Inv.rowH = math.floor(30 * scale)
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
    return math.max(6, math.floor((Inv.h - 210 * scale) / Inv.rowH))
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

local function closeAction()
    Inv.action = nil
    Inv.editing = false
    Inv.editText = ""
    Inv.actionBounds = {}
end

local function makeActionForItem(item)
    if not item then return nil end
    if item.itemId == "cash" then
        return {
            title = "Gotowka w kieszeni",
            item = item,
            lines = { "Przy sobie: " .. moneyText(item.quantity), "Zarzadzaj gotowka bez wychodzenia z ekwipunku." },
            actions = {
                { id = "cash_deposit_all", label = "Wplac calosc do banku" },
                { id = "cash_deposit", label = "Wplac $100", amount = 100 },
                { id = "cash_withdraw", label = "Wyplac $100", amount = 100 },
                { id = "cash_withdraw", label = "Wyplac $500", amount = 500 }
            }
        }
    end

    if item.itemId == "notebook" then
        local note = item.metadata and item.metadata.note or ""
        return {
            title = "Notes postaci",
            item = item,
            lines = { "Edytuj notatke ponizej. ENTER zapisuje, ESC wraca." },
            editor = true,
            text = tostring(note or ""),
            actions = {
                { id = "notebook_edit", label = "Edytuj notatke" },
                { id = "notebook_save", label = "Zapisz notatke" }
            }
        }
    end

    if item.itemId == "phone" then
        return {
            title = "Telefon komorkowy",
            item = item,
            lines = { "Stan: wlaczony", "Numer: nieprzypisany", "Gotowe miejsce pod kontakty, SMS, ogloszenia i aplikacje RP." },
            actions = { { id = "noop", label = "Modul telefonu wkrotce" } }
        }
    end

    if item.itemId == "id_card" then
        return {
            title = "Dowod osobisty",
            item = item,
            lines = { "Dokument postaci. Mozesz go okazac osobom w poblizu." },
            actions = { { id = "server_use", label = "Okaz dokument w poblizu" } }
        }
    end

    if item.itemId == "lockpick" then
        return {
            title = "Wytrych",
            item = item,
            lines = { "Narzedzie pod system drzwi, pojazdow i wlaman.", "Obecnie brak celu uzycia w zasiegu." },
            actions = { { id = "noop", label = "Brak celu" } }
        }
    end

    return nil
end

local function drawWeightBar(x, y, w, h)
    local ratio = 0
    if (Inv.maxWeight or 0) > 0 then ratio = clamp((Inv.currentWeight or 0) / Inv.maxWeight, 0, 1) end
    dxDrawRectangle(x, y, w, h, color("barBack", 210), true)
    dxDrawRectangle(x, y, math.max(2, w * ratio), h, ratio > 0.92 and color("danger", 235) or color("accent", 235), true)
end

local function drawCategories(scale)
    Inv.categoryBounds = {}
    local x, y, h = Inv.x + 22 * scale, Inv.y + 76 * scale, 30 * scale
    local maxX = Inv.x + Inv.w - 22 * scale
    for _, id in ipairs(categoryOrder()) do
        local label = categoryLabel(id)
        local w = math.max(88 * scale, dxGetTextWidth(label, 0.70 * scale, "default-bold") + 22 * scale)
        if x + w > maxX then break end
        local active = Inv.category == id
        dxDrawRectangle(x, y, w, h, active and color("action", 220) or color("panelSoft", 178), true)
        dxDrawRectangle(x, y + h - 2, w, 2, active and color("accent", 240) or color("line", 120), true)
        shadowText(label, x, y + 8 * scale, x + w, y + h, active and color("text", 245) or color("muted", 225), 0.70 * scale, "default-bold", "center")
        Inv.categoryBounds[#Inv.categoryBounds + 1] = { id = id, x = x, y = y, w = w, h = h }
        x = x + w + 7 * scale
    end
end

local function drawList(scale, list)
    local x, y, w = Inv.x + 22 * scale, Inv.y + 124 * scale, Inv.w * 0.58
    local headerH, rows = 28 * scale, maxVisibleRows()
    box(x, y, w, Inv.rowH * rows + headerH + 2, color("panel", 210), color("line", 145))
    shadowText("PRZEDMIOT", x + 12 * scale, y + 7 * scale, x + w, y + headerH, color("muted", 230), 0.68 * scale, "default-bold")
    shadowText("IL.", x + w - 150 * scale, y + 7 * scale, x + w - 102 * scale, y + headerH, color("muted", 230), 0.68 * scale, "default-bold", "right")
    shadowText("WAGA", x + w - 96 * scale, y + 7 * scale, x + w - 18 * scale, y + headerH, color("muted", 230), 0.68 * scale, "default-bold", "right")

    for row = 1, rows do
        local index = Inv.scroll + row
        local item = list[index]
        local rowY = y + headerH + (row - 1) * Inv.rowH
        dxDrawRectangle(x + 1, rowY, w - 2, Inv.rowH - 1, index == Inv.selected and color("rowActive", 225) or ((row % 2 == 0) and color("rowAlt", 142) or color("row", 132)), true)
        if item then
            local qty = item.itemId == "cash" and moneyText(item.quantity) or ("x" .. tostring(item.quantity or 1))
            shadowText(item.label, x + 12 * scale, rowY + 7 * scale, x + w - 162 * scale, rowY + Inv.rowH, color("text", 238), 0.73 * scale, "default-bold", "left", "top", true)
            shadowText(qty, x + w - 150 * scale, rowY + 7 * scale, x + w - 102 * scale, rowY + Inv.rowH, color("text", 232), 0.73 * scale, "default-bold", "right")
            shadowText(weightText(item.totalWeight), x + w - 98 * scale, rowY + 7 * scale, x + w - 18 * scale, rowY + Inv.rowH, color("muted", 230), 0.73 * scale, "default-bold", "right")
        end
    end
    if #list == 0 then shadowText("Brak przedmiotow w tej kategorii.", x, y + headerH + 46 * scale, x + w, y + headerH + 86 * scale, color("muted", 230), 0.82 * scale, "default-bold", "center", "center") end
end

local function detailRows(item)
    return {
        { item.itemId == "cash" and "Kwota" or "Ilosc", item.itemId == "cash" and moneyText(item.quantity) or ("x" .. tostring(item.quantity or 1)) },
        { "Waga", weightText(item.totalWeight) .. " / " .. weightText(item.weight or 0) .. " szt." },
        { "Jakosc", tostring(item.quality or 100) .. "%" },
        { "Stan", tostring(item.state or "normal") },
        { "UID", item.virtual and "system" or ("#" .. tostring(item.uid or "-")) }
    }
end

local function drawActionButton(scale, x, y, w, h, action, active)
    local fill = active and color("action", 235) or color("panelSoft", 205)
    dxDrawRectangle(x, y, w, h, fill, true)
    dxDrawRectangle(x, y + h - 2, w, 2, active and color("accent", 245) or color("line", 135), true)
    shadowText(action.label or action.id, x + 12 * scale, y + 8 * scale, x + w - 12 * scale, y + h, color("text", 240), 0.72 * scale, "default-bold", "left", "top", true)
end

local function drawActionPane(scale, item)
    local x, y = Inv.x + Inv.w * 0.63, Inv.y + 124 * scale
    local w, h = Inv.w - (x - Inv.x) - 22 * scale, Inv.h - 182 * scale
    box(x, y, w, h, color("panel", 218), color("line", 150))
    Inv.actionBounds = {}

    local action = Inv.action
    if not action then return false end
    shadowText(action.title or "Akcje", x + 18 * scale, y + 16 * scale, x + w - 18 * scale, y + 42 * scale, color("text", 245), 0.92 * scale, "default-bold", "left", "top", true)
    shadowText(item and item.label or "Przedmiot", x + 18 * scale, y + 42 * scale, x + w - 18 * scale, y + 64 * scale, color("accent", 235), 0.70 * scale, "default-bold", "left", "top", true)

    local yy = y + 78 * scale
    for _, line in ipairs(action.lines or {}) do
        shadowText(line, x + 18 * scale, yy, x + w - 18 * scale, yy + 24 * scale, color("muted", 230), 0.70 * scale, "default-bold", "left", "top", true, true)
        yy = yy + 25 * scale
    end

    if action.editor then
        yy = yy + 8 * scale
        local editH = 100 * scale
        dxDrawRectangle(x + 18 * scale, yy, w - 36 * scale, editH, color("barBack", 235), true)
        dxDrawRectangle(x + 18 * scale, yy, w - 36 * scale, 1, color("line", 160), true)
        local text = Inv.editText or ""
        if Inv.editing and (getTickCount() % 1000) < 520 then text = text .. "|" end
        shadowText(#text > 0 and text or "Kliknij 'Edytuj notatke' i wpisz tresc...", x + 28 * scale, yy + 10 * scale, x + w - 28 * scale, yy + editH - 10 * scale, #text > 0 and color("text", 235) or color("muted", 160), 0.70 * scale, "default", "left", "top", true, true)
        yy = yy + editH + 14 * scale
    else
        yy = yy + 12 * scale
    end

    for index, btn in ipairs(action.actions or {}) do
        local bh = 32 * scale
        drawActionButton(scale, x + 18 * scale, yy, w - 36 * scale, bh, btn, index == (action.selected or 1))
        Inv.actionBounds[#Inv.actionBounds + 1] = { index = index, x = x + 18 * scale, y = yy, w = w - 36 * scale, h = bh }
        yy = yy + bh + 8 * scale
    end

    shadowText("ESC - wroc do szczegolow    ENTER - wykonaj", x + 18 * scale, y + h - 32 * scale, x + w - 18 * scale, y + h - 12 * scale, color("muted", 210), 0.62 * scale, "default-bold", "center")
    return true
end

local function drawDetails(scale, item)
    local x, y = Inv.x + Inv.w * 0.63, Inv.y + 124 * scale
    local w, h = Inv.w - (x - Inv.x) - 22 * scale, Inv.h - 182 * scale
    if Inv.action then drawActionPane(scale, item) return end
    box(x, y, w, h, color("panel", 218), color("line", 150))
    if not item then shadowText("Wybierz przedmiot", x + 18 * scale, y + 28 * scale, x + w - 18 * scale, y + 76 * scale, color("muted", 230), 0.9 * scale, "default-bold", "center", "center") return end

    shadowText(item.label, x + 18 * scale, y + 16 * scale, x + w - 18 * scale, y + 42 * scale, color("text", 245), 0.94 * scale, "default-bold", "left", "top", true)
    shadowText(categoryLabel(item.category), x + 18 * scale, y + 44 * scale, x + w - 18 * scale, y + 66 * scale, color("accent", 235), 0.70 * scale, "default-bold")

    local yy = y + 84 * scale
    for _, row in ipairs(detailRows(item)) do
        shadowText(row[1], x + 18 * scale, yy, x + 120 * scale, yy + 20 * scale, color("muted", 220), 0.70 * scale, "default-bold")
        shadowText(row[2], x + 120 * scale, yy, x + w - 18 * scale, yy + 20 * scale, color("text", 232), 0.70 * scale, "default-bold", "right")
        yy = yy + 25 * scale
    end

    yy = yy + 10 * scale
    shadowText("Opis", x + 18 * scale, yy, x + w - 18 * scale, yy + 20 * scale, color("muted", 230), 0.68 * scale, "default-bold")
    shadowText(item.description or "Brak opisu.", x + 18 * scale, yy + 24 * scale, x + w - 18 * scale, y + h - 94 * scale, color("text", 225), 0.72 * scale, "default", "left", "top", true, true)

    local canUse = item.usable == true or utilityItems[item.itemId] == true
    local actionY = y + h - 74 * scale
    shadowText("ENTER", x + 18 * scale, actionY, x + 92 * scale, actionY + 22 * scale, canUse and color("accent", 230) or color("muted", 150), 0.72 * scale, "default-bold")
    shadowText(canUse and "Zarzadzaj / uzyj" or "Brak akcji", x + 96 * scale, actionY, x + w - 18 * scale, actionY + 22 * scale, color("text", 220), 0.72 * scale, "default-bold")
    shadowText("BACKSPACE", x + 18 * scale, actionY + 28 * scale, x + 118 * scale, actionY + 50 * scale, item.virtual and color("muted", 135) or color("danger", 220), 0.72 * scale, "default-bold")
    shadowText(item.virtual and "Nie mozna wyrzucic" or "Wyrzuc na ziemie", x + 120 * scale, actionY + 28 * scale, x + w - 18 * scale, actionY + 50 * scale, color("text", 220), 0.72 * scale, "default-bold")
end

local function drawInventory()
    if not Inv.visible or isPlayerMapVisible() then return end
    local scale = rebuildBounds()
    local item, list = selectedItem()
    dxDrawRectangle(0, 0, Inv.sx, Inv.sy, color("backdrop"), true)
    box(Inv.x, Inv.y, Inv.w, Inv.h, color("background"), color("line", 150))
    dxDrawRectangle(Inv.x, Inv.y, Inv.w, 4 * scale, color("accent", 235), true)

    shadowText("Ekwipunek postaci", Inv.x + 22 * scale, Inv.y + 20 * scale, Inv.x + Inv.w, Inv.y + 48 * scale, color("text", 245), 1.02 * scale, "default-bold")
    shadowText("HeavyRPG inventory", Inv.x + 22 * scale, Inv.y + 48 * scale, Inv.x + Inv.w, Inv.y + 68 * scale, color("muted", 220), 0.66 * scale, "default-bold")
    local weightX, weightY = Inv.x + Inv.w - 290 * scale, Inv.y + 28 * scale
    shadowText(weightText(Inv.currentWeight) .. " / " .. weightText(Inv.maxWeight), weightX, weightY - 18 * scale, Inv.x + Inv.w - 22 * scale, weightY, color("text", 232), 0.72 * scale, "default-bold", "right")
    drawWeightBar(weightX, weightY + 4 * scale, 260 * scale, 9 * scale)

    drawCategories(scale)
    drawList(scale, list)
    drawDetails(scale, item)
    shadowText("I / ESC - zamknij    TAB / klik - kategoria    ENTER - akcje    BACKSPACE - wyrzuc 1    DEL - wyrzuc stos", Inv.x + 22 * scale, Inv.y + Inv.h - 42 * scale, Inv.x + Inv.w - 22 * scale, Inv.y + Inv.h - 18 * scale, color("muted", 225), 0.66 * scale, "default-bold", "center")
end

local function drawDropPrompt(scale, sx, sy)
    local drop = Inv.nearDrop
    if not drop or Inv.visible then return end
    local text = "E - podnies " .. tostring(drop.label or "przedmiot") .. " x" .. tostring(drop.quantity or 1)
    local w = math.max(330 * scale, dxGetTextWidth(text, 0.78 * scale, "default-bold") + 42 * scale)
    local h = 40 * scale
    local x = (sx - w) / 2
    local y = sy - 132 * scale
    box(x, y, w, h, color("panel", 220), color("line", 170))
    shadowText(text, x, y + 10 * scale, x + w, y + h, color("text", 245), 0.78 * scale, "default-bold", "center")
end

local function renderOverlay()
    local scale, sx, sy = uiScale()
    drawDropPrompt(scale, sx, sy)
end

local function requestSync() triggerServerEvent("HeavyRPG:Inventory:request", resourceRoot) end

local function runMenuAction(btn)
    if not btn or btn.id == "noop" then return end
    if btn.id == "notebook_edit" then
        Inv.editing = true
        Inv.editText = Inv.action and tostring(Inv.action.text or "") or ""
        return
    end
    if btn.id == "notebook_save" then
        triggerServerEvent("HeavyRPG:Inventory:menuAction", resourceRoot, "notebook_save", toJSON({ text = Inv.editText or "" }, true))
        Inv.editing = false
        return
    end
    if btn.id == "server_use" and Inv.action and Inv.action.item then
        triggerServerEvent("HeavyRPG:Inventory:use", resourceRoot, Inv.action.item.uid, Inv.action.item.itemId)
        return
    end
    triggerServerEvent("HeavyRPG:Inventory:menuAction", resourceRoot, btn.id, toJSON({ amount = btn.amount or 0 }, true))
end

function Inv.handleClick(button, state, absX, absY)
    if not Inv.visible or button ~= "left" or state ~= "down" then return end
    for _, bounds in ipairs(Inv.actionBounds or {}) do
        if absX >= bounds.x and absX <= bounds.x + bounds.w and absY >= bounds.y and absY <= bounds.y + bounds.h then
            if Inv.action then Inv.action.selected = bounds.index runMenuAction((Inv.action.actions or {})[bounds.index]) end
            cancelEvent()
            return
        end
    end
    for _, bounds in ipairs(Inv.categoryBounds or {}) do
        if absX >= bounds.x and absX <= bounds.x + bounds.w and absY >= bounds.y and absY <= bounds.y + bounds.h then
            closeAction()
            Inv.category, Inv.selected, Inv.scroll = bounds.id, 1, 0
            cancelEvent()
            return
        end
    end
    local scale = uiScale()
    local list = filteredItems()
    local listX, listY, listW = Inv.x + 22 * scale, Inv.y + 124 * scale, Inv.w * 0.58
    local headerH, rows = 28 * scale, maxVisibleRows()
    if absX >= listX and absX <= listX + listW and absY >= listY + headerH and absY <= listY + headerH + rows * Inv.rowH then
        closeAction()
        local index = Inv.scroll + math.floor((absY - listY - headerH) / Inv.rowH) + 1
        if list[index] then Inv.selected = index end
        cancelEvent()
    end
end

local function setVisible(state)
    state = state == true
    if state and Inv.blocked then return end
    if Inv.visible == state then return end
    Inv.visible = state
    showCursor(state)
    if state then
        rebuildBounds()
        requestSync()
        addEventHandler("onClientRender", root, drawInventory)
        if not clickAttached then addEventHandler("onClientClick", root, Inv.handleClick) clickAttached = true end
        if not characterAttached then addEventHandler("onClientCharacter", root, function(char) if Inv.visible and Inv.editing and #Inv.editText < 500 then Inv.editText = Inv.editText .. tostring(char or "") end end) characterAttached = true end
    else
        closeAction()
        removeEventHandler("onClientRender", root, drawInventory)
        if clickAttached then removeEventHandler("onClientClick", root, Inv.handleClick) clickAttached = false end
    end
end

local function canToggle()
    if Inv.blocked then return false end
    if HRP.ClientCharacter and HRP.ClientCharacter.visible then return false end
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
    closeAction()
    Inv.category, Inv.selected, Inv.scroll = cats[current], 1, 0
end

local function moveSelection(offset)
    local list = filteredItems()
    if #list == 0 then return end
    closeAction()
    Inv.selected = clamp(Inv.selected + offset, 1, #list)
    normalizeSelection(list)
end

local function selectedAction(action)
    local item = selectedItem()
    if not item then return end
    if action == "use" then
        local localAction = makeActionForItem(item)
        if localAction then
            Inv.action = localAction
            Inv.action.selected = 1
            Inv.editText = localAction.text or ""
            Inv.editing = false
        elseif item.usable then
            triggerServerEvent("HeavyRPG:Inventory:use", resourceRoot, item.uid, item.itemId)
        end
        return
    end
    if item.virtual then return end
    if action == "drop_one" then triggerServerEvent("HeavyRPG:Inventory:drop", resourceRoot, item.uid, 1) end
    if action == "drop_stack" then triggerServerEvent("HeavyRPG:Inventory:drop", resourceRoot, item.uid, item.quantity or 1) end
end

local function handleKey(button, press)
    if not press then return end
    button = tostring(button or ""):lower()

    if Inv.visible and Inv.editing then
        if button == "backspace" then Inv.editText = string.sub(Inv.editText or "", 1, math.max(0, #(Inv.editText or "") - 1)) cancelEvent() return end
        if button == "enter" then runMenuAction({ id = "notebook_save" }) cancelEvent() return end
        if button == "escape" then Inv.editing = false cancelEvent() return end
        cancelEvent()
        return
    end

    if button == "e" and Inv.nearDrop and not Inv.visible then
        triggerServerEvent("HeavyRPG:Inventory:pickupDrop", resourceRoot, Inv.nearDrop.id)
        cancelEvent()
        return
    end

    if button == tostring(cfg().key or "i") then
        if not canToggle() then return end
        setVisible(not Inv.visible)
        cancelEvent()
        return
    end

    if not Inv.visible then return end
    if Inv.action then
        local actions = Inv.action.actions or {}
        if button == "escape" then closeAction() cancelEvent()
        elseif button == "arrow_u" then Inv.action.selected = clamp((Inv.action.selected or 1) - 1, 1, math.max(1, #actions)) cancelEvent()
        elseif button == "arrow_d" then Inv.action.selected = clamp((Inv.action.selected or 1) + 1, 1, math.max(1, #actions)) cancelEvent()
        elseif button == "enter" then runMenuAction(actions[Inv.action.selected or 1]) cancelEvent() end
        return
    end

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

local function blockInventory()
    Inv.blocked = true
    closeAction()
    setVisible(false)
end

local function unblockInventory() Inv.blocked = false end

addEvent("HeavyRPG:Inventory:sync", true)
addEventHandler("HeavyRPG:Inventory:sync", resourceRoot, function(payload)
    payload = type(payload) == "table" and payload or {}
    Inv.blocked = false
    Inv.items = type(payload.items) == "table" and payload.items or {}
    Inv.categories = type(payload.categories) == "table" and payload.categories or {}
    Inv.currentWeight = tonumber(payload.currentWeight) or 0
    Inv.maxWeight = tonumber(payload.maxWeight) or 35
    normalizeSelection(filteredItems())
end)

addEvent("HeavyRPG:Inventory:open", true)
addEventHandler("HeavyRPG:Inventory:open", resourceRoot, function() setVisible(true) end)

addEvent("HeavyRPG:Inventory:nearDrop", true)
addEventHandler("HeavyRPG:Inventory:nearDrop", resourceRoot, function(state, payload)
    if state then Inv.nearDrop = type(payload) == "table" and payload or nil else Inv.nearDrop = nil end
end)

addEvent("HeavyRPG:Inventory:action", true)
addEventHandler("HeavyRPG:Inventory:action", resourceRoot, function(payload)
    if type(payload) ~= "table" then return end
    Inv.action = {
        title = payload.title or "Akcja",
        lines = payload.lines or {},
        actions = { { id = "noop", label = payload.footer or "Zamknij" } },
        selected = 1
    }
end)

addEventHandler("HeavyRPG:Auth:show", resourceRoot, blockInventory)
addEventHandler("HeavyRPG:Character:showCreator", resourceRoot, blockInventory)
addEventHandler("HeavyRPG:Character:hideCreator", resourceRoot, unblockInventory)
addEventHandler("onClientResourceStart", resourceRoot, function()
    Inv.blocked = true
    addEventHandler("onClientKey", root, handleKey)
    if not overlayAttached then addEventHandler("onClientRender", root, renderOverlay) overlayAttached = true end
end)
addEventHandler("onClientResourceStop", resourceRoot, function()
    removeEventHandler("onClientKey", root, handleKey)
    if overlayAttached then removeEventHandler("onClientRender", root, renderOverlay) overlayAttached = false end
    setVisible(false)
end)