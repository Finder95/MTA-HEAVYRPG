HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientShops = HRP.ClientShops or {
    visible = false,
    prompt = nil,
    offers = {},
    categories = {},
    bounds = { categories = {}, offers = {}, buttons = {} },
    selected = 1,
    category = "all",
    quantity = 1,
    cash = 0,
    shopName = "Sklep",
    clerkName = "Sklepikarka",
    status = nil,
    statusType = "muted",
    lastBuy = 0,
    wasFrozen = nil,
    cursorWasShowing = nil
}

local Shop = HRP.ClientShops
local handleClick

local colors = {
    bg = { 17, 18, 17, 236 },
    panel = { 28, 29, 27, 224 },
    row = { 40, 42, 39, 170 },
    rowAlt = { 35, 36, 34, 155 },
    active = { 95, 78, 45, 225 },
    line = { 116, 101, 68, 175 },
    text = { 232, 226, 211, 255 },
    muted = { 147, 140, 124, 255 },
    accent = { 214, 171, 79, 255 },
    green = { 119, 191, 124, 255 },
    red = { 202, 82, 70, 255 },
    veil = { 6, 7, 8, 112 }
}

local blockedControls = {
    "fire", "aim_weapon", "next_weapon", "previous_weapon", "forwards", "backwards",
    "left", "right", "jump", "sprint", "walk", "crouch", "enter_exit",
    "vehicle_fire", "vehicle_secondary_fire", "vehicle_left", "vehicle_right",
    "accelerate", "brake_reverse", "handbrake", "horn", "sub_mission"
}

local function rgba(name, alpha)
    local c = colors[name] or colors.text
    return tocolor(c[1], c[2], c[3], alpha or c[4] or 255)
end

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function uiScale()
    local sx, sy = guiGetScreenSize()
    local scale = math.min(sx / 1920, sy / 1080)
    return clamp(scale, 0.86, 1.10), sx, sy
end

local function money(value)
    return "$" .. tostring(math.floor(tonumber(value) or 0))
end

local function text(value, x, y, w, h, textColor, scale, font, alignX, alignY, clip, wrap)
    value = tostring(value or "")
    dxDrawText(value, x + 1, y + 1, w + 1, h + 1, tocolor(0, 0, 0, 170), scale or 1, font or "default", alignX or "left", alignY or "top", clip == true, wrap == true, true)
    dxDrawText(value, x, y, w, h, textColor, scale or 1, font or "default", alignX or "left", alignY or "top", clip == true, wrap == true, true)
end

local function box(x, y, w, h, fill, border)
    dxDrawRectangle(x, y, w, h, fill, true)
    dxDrawRectangle(x, y, w, 1, border, true)
    dxDrawRectangle(x, y + h - 1, w, 1, border, true)
    dxDrawRectangle(x, y, 1, h, border, true)
    dxDrawRectangle(x + w - 1, y, 1, h, border, true)
end

local function resetBounds()
    Shop.bounds = { categories = {}, offers = {}, buttons = {} }
end

local function addBound(group, action, x, y, w, h, data)
    Shop.bounds[group] = Shop.bounds[group] or {}
    data = type(data) == "table" and data or {}
    data.action = action
    data.x, data.y, data.w, data.h = x, y, w, h
    Shop.bounds[group][#Shop.bounds[group] + 1] = data
end

local function inside(bound, x, y)
    return bound and x >= bound.x and x <= bound.x + bound.w and y >= bound.y and y <= bound.y + bound.h
end

local function drawButton(x, y, w, h, label, action, enabled, mode)
    enabled = enabled ~= false
    local fill = rgba(mode == "primary" and "active" or "row", enabled and 210 or 105)
    local border = rgba(mode == "primary" and "accent" or "line", enabled and 205 or 115)
    local labelColor = enabled and rgba(mode == "primary" and "text" or "text", 242) or rgba("muted", 150)

    box(x, y, w, h, fill, border)
    text(label, x, y + 1, x + w, y + h, labelColor, 0.72, "default-bold", "center", "center", true)
    if action then addBound("buttons", action, x, y, w, h, { enabled = enabled }) end
end

local function setMenuInputState(enabled)
    if enabled then
        Shop.cursorWasShowing = isCursorShowing and isCursorShowing() or false
        Shop.wasFrozen = isElementFrozen(localPlayer)
        for _, control in ipairs(blockedControls) do toggleControl(control, false) end
        setElementFrozen(localPlayer, true)
        showCursor(true)
        return
    end

    for _, control in ipairs(blockedControls) do toggleControl(control, true) end
    if Shop.wasFrozen ~= nil then
        setElementFrozen(localPlayer, Shop.wasFrozen == true)
    else
        setElementFrozen(localPlayer, false)
    end
    if Shop.cursorWasShowing ~= nil then
        showCursor(Shop.cursorWasShowing == true)
    else
        showCursor(false)
    end
    Shop.wasFrozen = nil
    Shop.cursorWasShowing = nil
end

local function categoryLabel(id)
    if id == "all" then return "Wszystko" end
    for _, category in ipairs(Shop.categories or {}) do
        if tostring(category.id) == tostring(id) then return tostring(category.label or id) end
    end
    return tostring(id or "Inne")
end

local function categoryOrder()
    local out, seen = { "all" }, { all = true }
    for _, category in ipairs(Shop.categories or {}) do
        local id = tostring(category.id or "")
        if id ~= "" and not seen[id] then out[#out + 1], seen[id] = id, true end
    end
    for _, offer in ipairs(Shop.offers or {}) do
        local id = tostring(offer.category or "misc")
        if not seen[id] then out[#out + 1], seen[id] = id, true end
    end
    return out
end

local function filteredOffers()
    local out = {}
    for _, offer in ipairs(Shop.offers or {}) do
        if Shop.category == "all" or tostring(offer.category) == Shop.category then out[#out + 1] = offer end
    end
    return out
end

local function selectedOffer()
    local offers = filteredOffers()
    if #offers == 0 then
        Shop.selected = 1
        Shop.quantity = 1
        return nil, offers
    end
    Shop.selected = clamp(Shop.selected, 1, #offers)
    local offer = offers[Shop.selected]
    Shop.quantity = clamp(Shop.quantity, 1, tonumber(offer.maxQuantity) or 1)
    return offer, offers
end

local function closeShop()
    if not Shop.visible then return end
    Shop.visible = false
    Shop.status = nil
    resetBounds()
    setMenuInputState(false)
    removeEventHandler("onClientRender", root, Shop.render)
    removeEventHandler("onClientClick", root, handleClick)
end

local function openShop(payload)
    payload = type(payload) == "table" and payload or {}
    local wasVisible = Shop.visible
    Shop.visible = true
    Shop.prompt = nil
    Shop.offers = type(payload.offers) == "table" and payload.offers or {}
    Shop.categories = type(payload.categories) == "table" and payload.categories or {}
    Shop.cash = tonumber(payload.cash) or 0
    Shop.shopName = tostring(payload.name or "Sklep")
    Shop.clerkName = tostring(payload.clerkName or "Sklepikarka")
    Shop.selected = 1
    Shop.category = "all"
    Shop.quantity = 1
    Shop.status = "Wybierz towar i kliknij Kup."
    Shop.statusType = "muted"
    resetBounds()
    if not wasVisible then setMenuInputState(true) else showCursor(true) end
    removeEventHandler("onClientRender", root, Shop.render)
    removeEventHandler("onClientClick", root, handleClick)
    addEventHandler("onClientRender", root, Shop.render)
    addEventHandler("onClientClick", root, handleClick, true, "high+20")
end

local function setStatus(message, kind)
    Shop.status = tostring(message or "")
    Shop.statusType = tostring(kind or "muted")
end

local function moveSelection(offset)
    local _, offers = selectedOffer()
    if #offers == 0 then return end
    Shop.selected = clamp(Shop.selected + offset, 1, #offers)
    Shop.quantity = 1
end

local function changeQuantity(offset)
    local offer = selectedOffer()
    if not offer then return end
    Shop.quantity = clamp(Shop.quantity + offset, 1, tonumber(offer.maxQuantity) or 1)
end

local function nextCategory(offset)
    local categories = categoryOrder()
    local current = 1
    for index, id in ipairs(categories) do if id == Shop.category then current = index break end end
    current = current + offset
    if current < 1 then current = #categories end
    if current > #categories then current = 1 end
    Shop.category = categories[current]
    Shop.selected = 1
    Shop.quantity = 1
end

local function buySelected()
    local offer = selectedOffer()
    if not offer then return end
    local qty = clamp(Shop.quantity, 1, tonumber(offer.maxQuantity) or 1)
    local total = qty * (tonumber(offer.price) or 0)
    if (tonumber(Shop.cash) or 0) < total then
        setStatus("Nie masz wystarczajacej gotowki przy sobie.", "error")
        return
    end

    local now = getTickCount()
    if now - Shop.lastBuy < 650 then return end
    Shop.lastBuy = now
    setStatus("Przekazuje zamowienie do sklepikarki...", "muted")
    triggerServerEvent("HeavyRPG:Shops:buy", resourceRoot, offer.id, qty)
end

local function drawPrompt()
    local prompt = Shop.prompt
    if not prompt or Shop.visible then return end

    local s, sx, sy = uiScale()
    local key = string.upper(tostring(prompt.key or (HRP.Config.shops and HRP.Config.shops.key) or "e"))
    local action = tostring(prompt.action or "Uzyj")
    local label = tostring(prompt.label or "Sklep")
    local line = key .. " - " .. action
    local w = math.max(390 * s, dxGetTextWidth(line, 0.82 * s, "default-bold") + 70 * s)
    local h = 72 * s
    local x = (sx - w) / 2
    local y = sy - 156 * s

    box(x, y, w, h, rgba("panel", 226), rgba("line", 190))
    dxDrawRectangle(x, y, 4 * s, h, rgba("accent", 245), true)
    text(label, x + 24 * s, y + 12 * s, x + w - 24 * s, y + 32 * s, rgba("accent", 240), 0.68 * s, "default-bold", "left", "top", true)
    text(line, x + 24 * s, y + 34 * s, x + w - 24 * s, y + 62 * s, rgba("text", 245), 0.82 * s, "default-bold", "left", "top", true)
end

local function drawCategories(s, x, y, w)
    local categories = categoryOrder()
    local cx = x
    for _, id in ipairs(categories) do
        local label = categoryLabel(id)
        local cw = math.max(90 * s, dxGetTextWidth(label, 0.66 * s, "default-bold") + 24 * s)
        if cx + cw > x + w then break end
        local active = Shop.category == id
        dxDrawRectangle(cx, y, cw, 30 * s, active and rgba("active", 230) or rgba("row", 145), true)
        dxDrawRectangle(cx, y + 28 * s, cw, 2 * s, active and rgba("accent", 245) or rgba("line", 135), true)
        text(label, cx, y + 8 * s, cx + cw, y + 30 * s, active and rgba("text", 245) or rgba("muted", 225), 0.64 * s, "default-bold", "center", "top", true)
        addBound("categories", "category", cx, y, cw, 30 * s, { id = id })
        cx = cx + cw + 8 * s
    end
end

local function drawOfferList(s, x, y, w, h, offers)
    box(x, y, w, h, rgba("panel", 215), rgba("line", 150))
    text("Towar", x + 14 * s, y + 10 * s, x + w - 120 * s, y + 32 * s, rgba("muted", 225), 0.66 * s, "default-bold")
    text("Cena", x + w - 112 * s, y + 10 * s, x + w - 18 * s, y + 32 * s, rgba("muted", 225), 0.66 * s, "default-bold", "right")

    local rowH = 38 * s
    local firstY = y + 40 * s
    local visibleRows = math.floor((h - 48 * s) / rowH)
    local scroll = 0
    if Shop.selected > visibleRows then scroll = Shop.selected - visibleRows end

    if #offers == 0 then
        text("Brak towarow w tej kategorii.", x, firstY + 24 * s, x + w, firstY + 70 * s, rgba("muted", 220), 0.78 * s, "default-bold", "center", "center")
        return
    end

    for row = 1, visibleRows do
        local index = scroll + row
        local offer = offers[index]
        if not offer then break end
        local yy = firstY + (row - 1) * rowH
        local active = index == Shop.selected
        dxDrawRectangle(x + 1, yy, w - 2, rowH - 2, active and rgba("active", 228) or (row % 2 == 0 and rgba("rowAlt", 150) or rgba("row", 158)), true)
        text(tostring(offer.label or offer.itemId), x + 14 * s, yy + 9 * s, x + w - 126 * s, yy + rowH, rgba("text", 238), 0.72 * s, "default-bold", "left", "top", true)
        text(money(offer.price), x + w - 112 * s, yy + 9 * s, x + w - 18 * s, yy + rowH, rgba("accent", 235), 0.72 * s, "default-bold", "right")
        addBound("offers", "offer", x + 1, yy, w - 2, rowH - 2, { index = index })
    end
end

local function drawDetails(s, x, y, w, h, offer)
    box(x, y, w, h, rgba("panel", 220), rgba("line", 150))
    if not offer then
        text("Wybierz towar", x, y + 40 * s, x + w, y + 90 * s, rgba("muted", 230), 0.88 * s, "default-bold", "center", "center")
        drawButton(x + 18 * s, y + h - 46 * s, w - 36 * s, 34 * s, "Zamknij", "close", true)
        return
    end

    local qty = clamp(Shop.quantity, 1, tonumber(offer.maxQuantity) or 1)
    local total = qty * (tonumber(offer.price) or 0)
    local canPay = (tonumber(Shop.cash) or 0) >= total

    text(tostring(offer.label or offer.itemId), x + 18 * s, y + 18 * s, x + w - 18 * s, y + 48 * s, rgba("text", 245), 0.92 * s, "default-bold", "left", "top", true)
    text(categoryLabel(offer.category), x + 18 * s, y + 48 * s, x + w - 18 * s, y + 70 * s, rgba("accent", 235), 0.66 * s, "default-bold")
    text(tostring(offer.description or "Brak opisu."), x + 18 * s, y + 82 * s, x + w - 18 * s, y + 148 * s, rgba("muted", 228), 0.68 * s, "default", "left", "top", true, true)

    local boxY = y + 160 * s
    dxDrawRectangle(x + 18 * s, boxY, w - 36 * s, 82 * s, rgba("row", 165), true)
    text("Ilosc", x + 34 * s, boxY + 10 * s, x + w - 34 * s, boxY + 30 * s, rgba("muted", 230), 0.66 * s, "default-bold")

    local qtyY = boxY + 38 * s
    local btn = 30 * s
    local minusX = x + 34 * s
    local plusX = x + w - 34 * s - btn
    drawButton(minusX, qtyY, btn, btn, "-", "qtyMinus", qty > 1)
    drawButton(plusX, qtyY, btn, btn, "+", "qtyPlus", qty < (tonumber(offer.maxQuantity) or 1))
    text(tostring(qty), minusX + btn + 8 * s, qtyY + 1, plusX - 8 * s, qtyY + btn, rgba("text", 245), 0.96 * s, "default-bold", "center", "center", true)

    local costY = boxY + 100 * s
    text("Cena laczna", x + 18 * s, costY, x + 145 * s, costY + 24 * s, rgba("muted", 230), 0.70 * s, "default-bold")
    text(money(total), x + 145 * s, costY, x + w - 18 * s, costY + 24 * s, canPay and rgba("green", 235) or rgba("red", 235), 0.84 * s, "default-bold", "right")
    text("Gotowka", x + 18 * s, costY + 28 * s, x + 145 * s, costY + 52 * s, rgba("muted", 230), 0.70 * s, "default-bold")
    text(money(Shop.cash), x + 145 * s, costY + 28 * s, x + w - 18 * s, costY + 52 * s, rgba("text", 235), 0.78 * s, "default-bold", "right")

    local statusColor = Shop.statusType == "error" and rgba("red", 235) or (Shop.statusType == "success" and rgba("green", 235) or rgba("muted", 225))
    text(Shop.status or "", x + 18 * s, y + h - 94 * s, x + w - 18 * s, y + h - 56 * s, statusColor, 0.66 * s, "default-bold", "left", "top", true, true)

    local buttonY = y + h - 46 * s
    local buttonW = (w - 44 * s) / 2
    drawButton(x + 18 * s, buttonY, buttonW, 34 * s, "Zamknij", "close", true)
    drawButton(x + 26 * s + buttonW, buttonY, buttonW, 34 * s, "Kup", "buy", canPay, "primary")
end

function Shop.render()
    drawPrompt()
    if not Shop.visible then return end

    local s, sx, sy = uiScale()
    local w = math.min(940 * s, sx - 72 * s)
    local h = math.min(590 * s, sy - 72 * s)
    local x = (sx - w) / 2
    local y = (sy - h) / 2
    local offer, offers = selectedOffer()
    resetBounds()

    dxDrawRectangle(0, 0, sx, sy, rgba("veil", 122), true)
    box(x, y, w, h, rgba("bg", 238), rgba("line", 160))
    dxDrawRectangle(x, y, w, 4 * s, rgba("accent", 240), true)

    text(Shop.clerkName, x + 24 * s, y + 20 * s, x + w - 24 * s, y + 42 * s, rgba("accent", 240), 0.70 * s, "default-bold", "left", "top", true)
    text(Shop.shopName, x + 24 * s, y + 42 * s, x + w - 24 * s, y + 74 * s, rgba("text", 245), 1.18 * s, "default-bold", "left", "top", true)
    text("Gotowka " .. money(Shop.cash), x + 24 * s, y + 44 * s, x + w - 24 * s, y + 72 * s, rgba("accent", 230), 0.76 * s, "default-bold", "right", "top", true)

    drawCategories(s, x + 24 * s, y + 88 * s, w - 48 * s)
    drawOfferList(s, x + 24 * s, y + 132 * s, w * 0.56, h - 166 * s, offers)
    drawDetails(s, x + w * 0.62, y + 132 * s, w * 0.34, h - 166 * s, offer)
end

handleClick = function(button, state, absoluteX, absoluteY)
    if not Shop.visible then return end
    if button ~= "left" or state ~= "down" then cancelEvent() return end

    local x, y = tonumber(absoluteX), tonumber(absoluteY)
    if not x or not y then cancelEvent() return end

    for _, bound in ipairs((Shop.bounds and Shop.bounds.buttons) or {}) do
        if inside(bound, x, y) then
            if bound.enabled == false then
                if bound.action == "buy" then setStatus("Nie masz wystarczajacej gotowki przy sobie.", "error") end
                cancelEvent()
                return
            end
            if bound.action == "close" then closeShop() cancelEvent() return end
            if bound.action == "buy" then buySelected() cancelEvent() return end
            if bound.action == "qtyMinus" then changeQuantity(-1) cancelEvent() return end
            if bound.action == "qtyPlus" then changeQuantity(1) cancelEvent() return end
        end
    end

    for _, bound in ipairs((Shop.bounds and Shop.bounds.categories) or {}) do
        if inside(bound, x, y) then
            Shop.category = tostring(bound.id or "all")
            Shop.selected = 1
            Shop.quantity = 1
            cancelEvent()
            return
        end
    end

    for _, bound in ipairs((Shop.bounds and Shop.bounds.offers) or {}) do
        if inside(bound, x, y) then
            Shop.selected = tonumber(bound.index) or Shop.selected
            Shop.quantity = 1
            cancelEvent()
            return
        end
    end

    cancelEvent()
end

local function handleKey(button, press)
    button = tostring(button or ""):lower()
    if Shop.visible then
        if not press then return end
        if button == "escape" then closeShop() cancelEvent() return end
        if button == "arrow_u" or button == "mouse_wheel_up" then moveSelection(-1) cancelEvent() return end
        if button == "arrow_d" or button == "mouse_wheel_down" then moveSelection(1) cancelEvent() return end
        if button == "arrow_l" then changeQuantity(-1) cancelEvent() return end
        if button == "arrow_r" then changeQuantity(1) cancelEvent() return end
        if button == "q" then nextCategory(-1) cancelEvent() return end
        if button == "e" then nextCategory(1) cancelEvent() return end
        if button == "enter" then buySelected() cancelEvent() return end
        cancelEvent()
        return
    end

    if not press then return end
    local key = tostring((HRP.Config.shops and HRP.Config.shops.key) or "e"):lower()
    if button == key and Shop.prompt then
        triggerServerEvent("HeavyRPG:Shops:interact", resourceRoot, Shop.prompt.kind, Shop.prompt.id)
        cancelEvent()
    end
end

addEvent("HeavyRPG:Shops:nearPoint", true)
addEventHandler("HeavyRPG:Shops:nearPoint", resourceRoot, function(state, payload)
    if state then Shop.prompt = type(payload) == "table" and payload or nil else Shop.prompt = nil end
end)

addEvent("HeavyRPG:Shops:open", true)
addEventHandler("HeavyRPG:Shops:open", resourceRoot, openShop)

addEvent("HeavyRPG:Shops:response", true)
addEventHandler("HeavyRPG:Shops:response", resourceRoot, function(payload)
    payload = type(payload) == "table" and payload or {}
    Shop.cash = tonumber(payload.cash) or Shop.cash
    setStatus(payload.message or "", payload.ok and "success" or "error")
end)

addEvent("HeavyRPG:Shops:close", true)
addEventHandler("HeavyRPG:Shops:close", resourceRoot, closeShop)

addEventHandler("onClientResourceStart", resourceRoot, function()
    addEventHandler("onClientRender", root, drawPrompt)
    addEventHandler("onClientKey", root, handleKey, true, "high+20")
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    removeEventHandler("onClientRender", root, drawPrompt)
    removeEventHandler("onClientKey", root, handleKey)
    removeEventHandler("onClientClick", root, handleClick)
    closeShop()
end)
