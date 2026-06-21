HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientInventory = HRP.ClientInventory or {}
local Inv = HRP.ClientInventory

Inv.visible = false
Inv.blocked = true
Inv.items = {}
Inv.categories = {}
Inv.categoryBounds = {}
Inv.actionBounds = {}
Inv.selected = 1
Inv.scroll = 0
Inv.category = "all"
Inv.currentWeight = 0
Inv.maxWeight = 35
Inv.nearDrop = nil
Inv.action = nil
Inv.prompt = nil
Inv.editing = false
Inv.editText = ""

local clickAttached = false
local overlayAttached = false
local characterAttached = false
local fallbackCategories = { all = "Wszystko", money = "Gotowka", documents = "Dokumenty", consumable = "Jedzenie", medical = "Medyczne", utility = "Uzytkowe", illegal = "Nielegalne", misc = "Inne" }
local utilityItems = { cash = true, id_card = true, phone = true, notebook = true, lockpick = true }
local colors = {
    bg = { 18, 20, 22, 238 }, panel = { 25, 28, 30, 226 }, row = { 33, 37, 40, 144 }, alt = { 29, 32, 35, 132 },
    active = { 79, 92, 93, 230 }, line = { 86, 99, 99, 185 }, text = { 232, 229, 219, 255 }, muted = { 154, 158, 154, 255 },
    accent = { 183, 158, 96, 255 }, danger = { 178, 72, 64, 255 }, dark = { 10, 12, 13, 210 }, veil = { 8, 10, 12, 118 }
}

local function cfg() return HRP.Config.inventory or {} end
local function rgba(name, a) local c = colors[name] or colors.text return tocolor(c[1], c[2], c[3], a or c[4] or 255) end
local function clamp(v, a, b) v = tonumber(v) or a if v < a then return a end if v > b then return b end return v end
local function money(v) return "$" .. tostring(math.floor(tonumber(v) or 0)) end
local function kg(v) return string.format("%.2f kg", tonumber(v) or 0) end
local function scale() local sx, sy = guiGetScreenSize() local s = math.min(sx / 1920, sy / 1080) return clamp(s, 0.86, 1.10), sx, sy end
local function text(t, x, y, w, h, c, s, f, ax, ay, clip, wrap) dxDrawText(tostring(t or ""), x + 1, y + 1, w + 1, h + 1, tocolor(0,0,0,170), s or 1, f or "default", ax or "left", ay or "top", clip == true, wrap == true, true) dxDrawText(tostring(t or ""), x, y, w, h, c, s or 1, f or "default", ax or "left", ay or "top", clip == true, wrap == true, true) end
local function box(x, y, w, h, fill, border) dxDrawRectangle(x,y,w,h,fill,true) dxDrawRectangle(x,y,w,1,border,true) dxDrawRectangle(x,y+h-1,w,1,border,true) dxDrawRectangle(x,y,1,h,border,true) dxDrawRectangle(x+w-1,y,1,h,border,true) end

local function layout()
    local s, sx, sy = scale()
    Inv.sx, Inv.sy = sx, sy
    Inv.w = math.floor(clamp(980 * s, 820, sx - 64))
    Inv.h = math.floor(clamp(620 * s, 520, sy - 64))
    Inv.x = math.floor((sx - Inv.w) / 2)
    Inv.y = math.floor((sy - Inv.h) / 2)
    Inv.rowH = math.floor(30 * s)
    return s
end

local function categoryLabel(id)
    for _, cat in ipairs(Inv.categories or {}) do if tostring(cat.id) == tostring(id) then return tostring(cat.label or id) end end
    return fallbackCategories[id] or tostring(id)
end

local function categoryOrder()
    local out, seen = { "all" }, { all = true }
    for _, cat in ipairs(Inv.categories or {}) do local id = tostring(cat.id or cat) if not seen[id] then out[#out+1], seen[id] = id, true end end
    for _, item in ipairs(Inv.items or {}) do local id = tostring(item.category or "misc") if not seen[id] then out[#out+1], seen[id] = id, true end end
    return out
end

local function filtered()
    local out = {}
    for _, item in ipairs(Inv.items or {}) do if Inv.category == "all" or item.category == Inv.category then out[#out+1] = item end end
    return out
end

local function rowsVisible() local s = scale() return math.max(6, math.floor((Inv.h - 210 * s) / (Inv.rowH or 30))) end
local function normalize(list) list = list or filtered() local rows = rowsVisible() if #list == 0 then Inv.selected, Inv.scroll = 1, 0 return end Inv.selected = clamp(Inv.selected, 1, #list) Inv.scroll = clamp(Inv.scroll, 0, math.max(0, #list - rows)) if Inv.selected < Inv.scroll + 1 then Inv.scroll = Inv.selected - 1 end if Inv.selected > Inv.scroll + rows then Inv.scroll = Inv.selected - rows end end
local function selectedItem() local list = filtered() normalize(list) return list[Inv.selected], list end
local function closeAction() Inv.action, Inv.prompt, Inv.editing, Inv.editText, Inv.actionBounds = nil, nil, false, "", {} end
local function add(actions, id, label, opts) opts = opts or {} opts.id = id opts.label = label actions[#actions + 1] = opts end

local function makeAction(item)
    if not item then return nil end
    local actions, lines = {}, {}
    if item.itemId == "cash" then
        lines = { "Przy sobie: " .. money(item.quantity), "Wybierz akcje i wpisz kwote. Bank zostaje poza ekwipunkiem." }
        add(actions, "cash_give", "Przekaz", { prompt = "amount", max = item.quantity or 0 })
        add(actions, "cash_drop", "Wyrzuc", { prompt = "amount", max = item.quantity or 0 })
        return { title = "Gotowka", item = item, lines = lines, actions = actions }
    end
    if item.itemId == "notebook" then
        return { title = "Notes", item = item, lines = { "Edytuj prywatna notatke tego przedmiotu." }, editor = true, text = tostring((item.metadata and item.metadata.note) or ""), actions = { { id = "notebook_edit", label = "Edytuj notatke" }, { id = "notebook_save", label = "Zapisz notatke" }, { id = "item_give", label = "Przekaz", prompt = "amount", max = 1 }, { id = "item_drop", label = "Wyrzuc", prompt = "amount", max = 1 } } }
    end
    if item.itemId == "phone" then
        return { title = "Telefon", item = item, lines = { "Uzyj telefonu, aby otworzyc osobny smartfon CEF." }, actions = { { id = "phone_open", label = "Uzyj" }, { id = "item_give", label = "Przekaz", prompt = "amount", max = 1 }, { id = "item_drop", label = "Wyrzuc", prompt = "amount", max = 1 } } }
    end
    if item.usable == true or utilityItems[item.itemId] then add(actions, "server_use", item.category == "consumable" and "Uzyj / spozyj" or "Uzyj") end
    if not item.virtual then
        add(actions, "item_give", "Przekaz", { prompt = "amount", max = item.quantity or 1 })
        add(actions, "item_drop", "Wyrzuc", { prompt = "amount", max = item.quantity or 1 })
        add(actions, "item_sell", "Sprzedaj", { prompt = "sale", max = item.quantity or 1 })
    end
    if #actions == 0 then add(actions, "noop", "Brak dostepnych akcji") end
    return { title = "Zarzadzaj przedmiotem", item = item, lines = { item.description or "Brak opisu.", "Wybierz akcje, potem podaj ilosc/cene w panelu." }, actions = actions }
end

local function startPrompt(btn)
    local max = math.max(1, tonumber(btn.max) or ((Inv.action and Inv.action.item and Inv.action.item.quantity) or 1))
    Inv.prompt = { action = btn, amount = tostring(math.min(1, max)), price = "", field = "amount", max = max }
end

local function confirmPrompt()
    if not Inv.prompt or not Inv.action or not Inv.action.item then return end
    local btn = Inv.prompt.action
    local amount = math.floor(tonumber(Inv.prompt.amount) or 0)
    local price = math.floor(tonumber(Inv.prompt.price) or 0)
    if amount < 1 then amount = 1 end
    if amount > Inv.prompt.max then amount = Inv.prompt.max end
    if btn.prompt == "sale" and price < 1 then return end
    triggerServerEvent("HeavyRPG:Inventory:menuAction", resourceRoot, btn.id, toJSON({ uid = Inv.action.item.uid, itemId = Inv.action.item.itemId, amount = amount, price = price }, true))
    Inv.prompt = nil
end

local function drawCategories(s)
    Inv.categoryBounds = {}
    local x, y, h = Inv.x + 22*s, Inv.y + 76*s, 30*s
    for _, id in ipairs(categoryOrder()) do
        local label = categoryLabel(id)
        local w = math.max(88*s, dxGetTextWidth(label, 0.70*s, "default-bold") + 22*s)
        if x + w > Inv.x + Inv.w - 22*s then break end
        local active = Inv.category == id
        dxDrawRectangle(x, y, w, h, active and rgba("active",220) or rgba("panel",178), true)
        dxDrawRectangle(x, y+h-2, w, 2, active and rgba("accent",240) or rgba("line",120), true)
        text(label, x, y+8*s, x+w, y+h, active and rgba("text",245) or rgba("muted",225), 0.70*s, "default-bold", "center")
        Inv.categoryBounds[#Inv.categoryBounds+1] = { id=id, x=x, y=y, w=w, h=h }
        x = x + w + 7*s
    end
end

local function drawList(s, list)
    local x, y, w = Inv.x + 22*s, Inv.y + 124*s, Inv.w * 0.58
    local headerH, rows = 28*s, rowsVisible()
    box(x, y, w, Inv.rowH * rows + headerH + 2, rgba("panel",210), rgba("line",145))
    text("PRZEDMIOT", x+12*s, y+7*s, x+w, y+headerH, rgba("muted",230), 0.68*s, "default-bold")
    text("IL.", x+w-150*s, y+7*s, x+w-102*s, y+headerH, rgba("muted",230), 0.68*s, "default-bold", "right")
    text("WAGA", x+w-96*s, y+7*s, x+w-18*s, y+headerH, rgba("muted",230), 0.68*s, "default-bold", "right")
    for row = 1, rows do
        local index, item = Inv.scroll + row, list[Inv.scroll + row]
        local rowY = y + headerH + (row - 1) * Inv.rowH
        dxDrawRectangle(x+1, rowY, w-2, Inv.rowH-1, index == Inv.selected and rgba("active",225) or (row % 2 == 0 and rgba("alt",142) or rgba("row",132)), true)
        if item then
            text(item.label, x+12*s, rowY+7*s, x+w-162*s, rowY+Inv.rowH, rgba("text",238), 0.73*s, "default-bold", "left", "top", true)
            text(item.itemId == "cash" and money(item.quantity) or ("x" .. tostring(item.quantity or 1)), x+w-150*s, rowY+7*s, x+w-102*s, rowY+Inv.rowH, rgba("text",232), 0.73*s, "default-bold", "right")
            text(kg(item.totalWeight), x+w-98*s, rowY+7*s, x+w-18*s, rowY+Inv.rowH, rgba("muted",230), 0.73*s, "default-bold", "right")
        end
    end
end

local function runAction(btn)
    if not btn or btn.id == "noop" then return end
    if btn.prompt then startPrompt(btn) return end
    if btn.id == "notebook_edit" then Inv.editing = true Inv.editText = tostring((Inv.action and Inv.action.text) or "") return end
    if btn.id == "notebook_save" then triggerServerEvent("HeavyRPG:Inventory:menuAction", resourceRoot, "notebook_save", toJSON({ uid = Inv.action.item.uid, text = Inv.editText or "" }, true)) Inv.editing = false return end
    if btn.id == "server_use" then triggerServerEvent("HeavyRPG:Inventory:use", resourceRoot, Inv.action.item.uid, Inv.action.item.itemId) return end
    triggerServerEvent("HeavyRPG:Inventory:menuAction", resourceRoot, btn.id, toJSON({ uid = Inv.action.item.uid, itemId = Inv.action.item.itemId, amount = btn.amount or 1 }, true))
end

local function drawPrompt(s, x, y, w, yy)
    local prompt = Inv.prompt
    if not prompt then return yy end
    dxDrawRectangle(x+18*s, yy, w-36*s, 122*s, rgba("dark",235), true)
    text((prompt.action.label or "Akcja") .. " - parametry", x+30*s, yy+10*s, x+w-30*s, yy+30*s, rgba("accent",240), 0.70*s, "default-bold")
    local amountActive = prompt.field == "amount"
    local priceActive = prompt.field == "price"
    text("Ilosc / kwota", x+30*s, yy+38*s, x+130*s, yy+58*s, amountActive and rgba("text",245) or rgba("muted",220), 0.66*s, "default-bold")
    text(prompt.amount or "", x+140*s, yy+38*s, x+w-30*s, yy+58*s, amountActive and rgba("accent",245) or rgba("text",230), 0.76*s, "default-bold", "right")
    if prompt.action.prompt == "sale" then
        text("Cena laczna", x+30*s, yy+62*s, x+130*s, yy+82*s, priceActive and rgba("text",245) or rgba("muted",220), 0.66*s, "default-bold")
        text(prompt.price ~= "" and money(prompt.price) or "$0", x+140*s, yy+62*s, x+w-30*s, yy+82*s, priceActive and rgba("accent",245) or rgba("text",230), 0.76*s, "default-bold", "right")
    end
    text("ENTER - potwierdz    TAB - pole    ESC - anuluj", x+30*s, yy+94*s, x+w-30*s, yy+114*s, rgba("muted",220), 0.58*s, "default-bold", "center")
    return yy + 134*s
end

local function drawRight(s, item)
    local x, y = Inv.x + Inv.w * 0.63, Inv.y + 124*s
    local w, h = Inv.w - (x - Inv.x) - 22*s, Inv.h - 182*s
    box(x, y, w, h, rgba("panel",218), rgba("line",150))
    Inv.actionBounds = {}
    if not item then text("Wybierz przedmiot", x, y+32*s, x+w, y+80*s, rgba("muted",230), 0.9*s, "default-bold", "center") return end
    if not Inv.action then
        text(item.label, x+18*s, y+16*s, x+w-18*s, y+44*s, rgba("text",245), 0.94*s, "default-bold", "left", "top", true)
        text(categoryLabel(item.category), x+18*s, y+44*s, x+w-18*s, y+66*s, rgba("accent",235), 0.70*s, "default-bold")
        local yy = y + 86*s
        local rows = { { item.itemId == "cash" and "Kwota" or "Ilosc", item.itemId == "cash" and money(item.quantity) or ("x" .. tostring(item.quantity or 1)) }, { "Waga", kg(item.totalWeight) }, { "Jakosc", tostring(item.quality or 100) .. "%" }, { "Stan", tostring(item.state or "normal") }, { "UID", item.virtual and "system" or ("#" .. tostring(item.uid or "-")) } }
        for _, row in ipairs(rows) do text(row[1], x+18*s, yy, x+120*s, yy+20*s, rgba("muted",220), 0.70*s, "default-bold") text(row[2], x+120*s, yy, x+w-18*s, yy+20*s, rgba("text",232), 0.70*s, "default-bold", "right") yy = yy + 25*s end
        text("Opis", x+18*s, yy+10*s, x+w-18*s, yy+30*s, rgba("muted",230), 0.68*s, "default-bold")
        text(item.description or "Brak opisu.", x+18*s, yy+34*s, x+w-18*s, y+h-70*s, rgba("text",225), 0.72*s, "default", "left", "top", true, true)
        text("ENTER", x+18*s, y+h-48*s, x+92*s, y+h-26*s, rgba("accent",230), 0.72*s, "default-bold")
        text("Zarzadzaj przedmiotem", x+96*s, y+h-48*s, x+w-18*s, y+h-26*s, rgba("text",220), 0.72*s, "default-bold")
        return
    end
    local a = Inv.action
    text(a.title or "Akcje", x+18*s, y+16*s, x+w-18*s, y+42*s, rgba("text",245), 0.92*s, "default-bold", "left", "top", true)
    local yy = y + 74*s
    for _, line in ipairs(a.lines or {}) do text(line, x+18*s, yy, x+w-18*s, yy+24*s, rgba("muted",230), 0.70*s, "default-bold", "left", "top", true, true) yy = yy + 25*s end
    if a.editor then
        yy = yy + 8*s
        dxDrawRectangle(x+18*s, yy, w-36*s, 100*s, rgba("dark",235), true)
        local value = Inv.editText or ""
        if Inv.editing and getTickCount() % 1000 < 520 then value = value .. "|" end
        text(#value > 0 and value or "Kliknij edycje i wpisz tresc...", x+28*s, yy+10*s, x+w-28*s, yy+90*s, #value > 0 and rgba("text",235) or rgba("muted",160), 0.70*s, "default", "left", "top", true, true)
        yy = yy + 114*s
    else yy = yy + 12*s end
    yy = drawPrompt(s, x, y, w, yy)
    if Inv.prompt then return end
    for i, btn in ipairs(a.actions or {}) do
        local bh = 32*s
        dxDrawRectangle(x+18*s, yy, w-36*s, bh, i == (a.selected or 1) and rgba("active",235) or rgba("panel",205), true)
        dxDrawRectangle(x+18*s, yy+bh-2, w-36*s, 2, i == (a.selected or 1) and rgba("accent",245) or rgba("line",135), true)
        text(btn.label or btn.id, x+30*s, yy+8*s, x+w-30*s, yy+bh, rgba("text",240), 0.72*s, "default-bold", "left", "top", true)
        Inv.actionBounds[#Inv.actionBounds+1] = { index=i, x=x+18*s, y=yy, w=w-36*s, h=bh }
        yy = yy + bh + 8*s
    end
end

local function drawInventory()
    if not Inv.visible or isPlayerMapVisible() then return end
    local s = layout()
    local item, list = selectedItem()
    dxDrawRectangle(0,0,Inv.sx,Inv.sy,rgba("veil"),true)
    box(Inv.x, Inv.y, Inv.w, Inv.h, rgba("bg"), rgba("line",150))
    dxDrawRectangle(Inv.x, Inv.y, Inv.w, 4*s, rgba("accent",235), true)
    text("Ekwipunek postaci", Inv.x+22*s, Inv.y+20*s, Inv.x+Inv.w, Inv.y+48*s, rgba("text",245), 1.02*s, "default-bold")
    text(kg(Inv.currentWeight) .. " / " .. kg(Inv.maxWeight), Inv.x+Inv.w-290*s, Inv.y+10*s, Inv.x+Inv.w-22*s, Inv.y+32*s, rgba("text",232), 0.72*s, "default-bold", "right")
    local ratio = Inv.maxWeight > 0 and clamp(Inv.currentWeight / Inv.maxWeight, 0, 1) or 0
    dxDrawRectangle(Inv.x+Inv.w-282*s, Inv.y+32*s, 260*s, 9*s, rgba("dark",210), true)
    dxDrawRectangle(Inv.x+Inv.w-282*s, Inv.y+32*s, math.max(2, 260*s*ratio), 9*s, ratio > 0.92 and rgba("danger",235) or rgba("accent",235), true)
    drawCategories(s)
    drawList(s, list)
    drawRight(s, item)
    text("I / ESC - zamknij    TAB / klik - kategoria    ENTER - zarzadzaj", Inv.x+22*s, Inv.y+Inv.h-42*s, Inv.x+Inv.w-22*s, Inv.y+Inv.h-18*s, rgba("muted",225), 0.66*s, "default-bold", "center")
end

local function drawDropPrompt()
    local drop = Inv.nearDrop
    if not drop or Inv.visible then return end
    local s, sx, sy = scale()
    local label = drop.itemId == "cash" and money(drop.quantity) or ("x" .. tostring(drop.quantity or 1))
    local prompt = "E - podnies " .. tostring(drop.label or "przedmiot") .. " " .. label
    local w, h = math.max(330*s, dxGetTextWidth(prompt, 0.78*s, "default-bold") + 42*s), 40*s
    box((sx-w)/2, sy-132*s, w, h, rgba("panel",220), rgba("line",170))
    text(prompt, (sx-w)/2, sy-122*s, (sx+w)/2, sy-92*s, rgba("text",245), 0.78*s, "default-bold", "center")
end

local function requestSync() triggerServerEvent("HeavyRPG:Inventory:request", resourceRoot) end
function Inv.handleClick(button, state, ax, ay)
    if not Inv.visible or button ~= "left" or state ~= "down" or Inv.prompt then return end
    for _, b in ipairs(Inv.actionBounds or {}) do if ax >= b.x and ax <= b.x+b.w and ay >= b.y and ay <= b.y+b.h then if Inv.action then Inv.action.selected = b.index runAction((Inv.action.actions or {})[b.index]) end cancelEvent() return end end
    for _, b in ipairs(Inv.categoryBounds or {}) do if ax >= b.x and ax <= b.x+b.w and ay >= b.y and ay <= b.y+b.h then closeAction() Inv.category, Inv.selected, Inv.scroll = b.id, 1, 0 cancelEvent() return end end
    local s = scale(); local list = filtered(); local x, y, w = Inv.x+22*s, Inv.y+124*s, Inv.w*0.58; local header = 28*s
    if ax >= x and ax <= x+w and ay >= y+header and ay <= y+header+rowsVisible()*Inv.rowH then closeAction() local idx = Inv.scroll + math.floor((ay-y-header)/Inv.rowH) + 1 if list[idx] then Inv.selected = idx end cancelEvent() end
end

local function setVisible(state)
    state = state == true
    if state and Inv.blocked then return end
    if Inv.visible == state then return end
    Inv.visible = state
    showCursor(state)
    if state then layout() requestSync() addEventHandler("onClientRender", root, drawInventory) if not clickAttached then addEventHandler("onClientClick", root, Inv.handleClick) clickAttached = true end if not characterAttached then addEventHandler("onClientCharacter", root, function(ch) if Inv.visible and Inv.editing and #Inv.editText < 500 then Inv.editText = Inv.editText .. tostring(ch or "") elseif Inv.visible and Inv.prompt then local char = tostring(ch or "") if char:match("%d") then if Inv.prompt.field == "price" then Inv.prompt.price = (Inv.prompt.price or "") .. char else Inv.prompt.amount = (Inv.prompt.amount or "") .. char end end end end) characterAttached = true end else closeAction() removeEventHandler("onClientRender", root, drawInventory) if clickAttached then removeEventHandler("onClientClick", root, Inv.handleClick) clickAttached = false end end
end

local function canToggle() if Inv.blocked then return false end if HRP.ClientCharacter and HRP.ClientCharacter.visible then return false end if isChatBoxInputActive and isChatBoxInputActive() then return false end if isConsoleActive and isConsoleActive() then return false end if isMainMenuActive and isMainMenuActive() then return false end return true end
local function move(offset) local list = filtered() if #list == 0 then return end closeAction() Inv.selected = clamp(Inv.selected + offset, 1, #list) normalize(list) end
local function nextCategory() local cats, cur = categoryOrder(), 1 for i, id in ipairs(cats) do if id == Inv.category then cur = i break end end cur = cur + 1 if cur > #cats then cur = 1 end closeAction() Inv.category, Inv.selected, Inv.scroll = cats[cur], 1, 0 end

local function handlePromptKey(button)
    if not Inv.prompt then return false end
    if button == "backspace" then if Inv.prompt.field == "price" then Inv.prompt.price = string.sub(Inv.prompt.price or "", 1, math.max(0, #(Inv.prompt.price or "") - 1)) else Inv.prompt.amount = string.sub(Inv.prompt.amount or "", 1, math.max(0, #(Inv.prompt.amount or "") - 1)) end cancelEvent() return true end
    if button == "tab" and Inv.prompt.action.prompt == "sale" then Inv.prompt.field = Inv.prompt.field == "price" and "amount" or "price" cancelEvent() return true end
    if button == "enter" then confirmPrompt() cancelEvent() return true end
    if button == "escape" then Inv.prompt = nil cancelEvent() return true end
    cancelEvent()
    return true
end

local function handleKey(button, press)
    if not press then return end
    button = tostring(button or ""):lower()
    if Inv.visible and Inv.prompt then if handlePromptKey(button) then return end end
    if Inv.visible and Inv.editing then if button == "backspace" then Inv.editText = string.sub(Inv.editText or "", 1, math.max(0, #(Inv.editText or "") - 1)) cancelEvent() return end if button == "enter" then runAction({ id = "notebook_save" }) cancelEvent() return end if button == "escape" then Inv.editing = false cancelEvent() return end cancelEvent() return end
    if button == "e" and Inv.nearDrop and not Inv.visible then if Inv.nearDrop.cash == true or Inv.nearDrop.itemId == "cash" then triggerServerEvent("HeavyRPG:Inventory:pickupCashDrop", resourceRoot, Inv.nearDrop.id) else triggerServerEvent("HeavyRPG:Inventory:pickupDrop", resourceRoot, Inv.nearDrop.id) end cancelEvent() return end
    if button == tostring(cfg().key or "i") then if not canToggle() then return end setVisible(not Inv.visible) cancelEvent() return end
    if not Inv.visible then return end
    if Inv.action then local acts = Inv.action.actions or {} if button == "escape" then closeAction() cancelEvent() elseif button == "arrow_u" then Inv.action.selected = clamp((Inv.action.selected or 1)-1, 1, math.max(1,#acts)) cancelEvent() elseif button == "arrow_d" then Inv.action.selected = clamp((Inv.action.selected or 1)+1, 1, math.max(1,#acts)) cancelEvent() elseif button == "enter" then runAction(acts[Inv.action.selected or 1]) cancelEvent() end return end
    if button == "escape" then setVisible(false) cancelEvent() elseif button == "arrow_u" then move(-1) cancelEvent() elseif button == "arrow_d" then move(1) cancelEvent() elseif button == "mouse_wheel_up" then move(-3) cancelEvent() elseif button == "mouse_wheel_down" then move(3) cancelEvent() elseif button == "tab" then nextCategory() cancelEvent() elseif button == "enter" then local item = selectedItem() Inv.action = makeAction(item) if Inv.action then Inv.action.selected = 1 Inv.editText = Inv.action.text or "" Inv.editing = false end cancelEvent() end
end

local function blockInventory() Inv.blocked = true closeAction() setVisible(false) end
local function unblockInventory() Inv.blocked = false end

addEvent("HeavyRPG:Inventory:sync", true)
addEventHandler("HeavyRPG:Inventory:sync", resourceRoot, function(payload) payload = type(payload) == "table" and payload or {} Inv.blocked = false Inv.items = type(payload.items) == "table" and payload.items or {} Inv.categories = type(payload.categories) == "table" and payload.categories or {} Inv.currentWeight = tonumber(payload.currentWeight) or 0 Inv.maxWeight = tonumber(payload.maxWeight) or 35 normalize(filtered()) end)
addEvent("HeavyRPG:Inventory:open", true)
addEventHandler("HeavyRPG:Inventory:open", resourceRoot, function() setVisible(true) end)
addEvent("HeavyRPG:Inventory:close", true)
addEventHandler("HeavyRPG:Inventory:close", resourceRoot, function() setVisible(false) end)
addEvent("HeavyRPG:Inventory:nearDrop", true)
addEventHandler("HeavyRPG:Inventory:nearDrop", resourceRoot, function(state, payload) if state then Inv.nearDrop = type(payload) == "table" and payload or nil else Inv.nearDrop = nil end end)
addEvent("HeavyRPG:Inventory:action", true)
addEventHandler("HeavyRPG:Inventory:action", resourceRoot, function(payload) if type(payload) ~= "table" then return end Inv.action = { title = payload.title or "Akcja", lines = payload.lines or {}, actions = { { id = "noop", label = payload.footer or "Zamknij" } }, selected = 1 } end)
addEventHandler("HeavyRPG:Auth:show", resourceRoot, blockInventory)
addEventHandler("HeavyRPG:Character:showCreator", resourceRoot, blockInventory)
addEventHandler("HeavyRPG:Character:hideCreator", resourceRoot, unblockInventory)
addEventHandler("onClientResourceStart", resourceRoot, function() Inv.blocked = true addEventHandler("onClientKey", root, handleKey) if not overlayAttached then addEventHandler("onClientRender", root, drawDropPrompt) overlayAttached = true end end)
addEventHandler("onClientResourceStop", resourceRoot, function() removeEventHandler("onClientKey", root, handleKey) if overlayAttached then removeEventHandler("onClientRender", root, drawDropPrompt) overlayAttached = false end setVisible(false) end)