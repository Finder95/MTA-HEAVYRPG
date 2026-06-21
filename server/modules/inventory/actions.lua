HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local cashDrops = {}

local function notify(player, message, r, g, b)
    if isElement(player) then
        outputChatBox("[EQ] " .. tostring(message), player, r or 210, g or 198, b or 164)
    end
end

local function money(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then return 0 end
    return value
end

local function quantity(value)
    value = math.floor(tonumber(value) or 1)
    if value < 1 then return 1 end
    if value > 999 then return 999 end
    return value
end

local function now() return HRP.Utils.now() end
local function getCharacterId(player) return tonumber(getElementData(player, "hrp:character:id")) end
local function getAccountId(player) return tonumber(getElementData(player, "hrp:account:id")) end

local function saveCash(player)
    local characterId = getCharacterId(player)
    if not characterId then return false end
    return HRP.DB.exec([[UPDATE characters SET cash = ?, updated_at = ? WHERE id = ?]], {
        money(getPlayerMoney(player)),
        now(),
        characterId
    })
end

local function syncMoney(player)
    saveCash(player)
    if HRP.Bank and HRP.Bank.sync then HRP.Bank.sync(player) end
    if HRP.Inventory and HRP.Inventory.sync then HRP.Inventory.sync(player) end
end

local function parsePayload(payload)
    if type(payload) == "table" then return payload end
    if type(payload) == "string" then
        local decoded = fromJSON(payload)
        if type(decoded) == "table" then return decoded end
    end
    return {}
end

local function findVisibleItem(player, uid, itemId)
    uid = tonumber(uid)
    for _, item in ipairs((HRP.Inventory and HRP.Inventory.getVisibleItems and HRP.Inventory.getVisibleItems(player)) or {}) do
        if uid and tonumber(item.uid) == uid then return item end
        if not uid and tostring(item.itemId) == tostring(itemId or "") then return item end
    end
    return nil
end

local function findNearestPlayer(player, maxDistance)
    local px, py, pz = getElementPosition(player)
    local best, bestDistance = nil, tonumber(maxDistance) or 3.0
    for _, target in ipairs(getElementsByType("player")) do
        if target ~= player and getElementDimension(target) == getElementDimension(player) and getElementInterior(target) == getElementInterior(player) then
            local tx, ty, tz = getElementPosition(target)
            local distance = getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz)
            if distance <= bestDistance then
                best, bestDistance = target, distance
            end
        end
    end
    return best
end

local function destroyCashDrop(dropId)
    local drop = cashDrops[tostring(dropId)]
    if not drop then return end
    if drop.marker and isElement(drop.marker) then destroyElement(drop.marker) end
    if drop.object and isElement(drop.object) then destroyElement(drop.object) end
    cashDrops[tostring(dropId)] = nil
end

local function makeDropId(player)
    return table.concat({ "cash", tostring(now()), tostring(getTickCount()), tostring(math.random(100000, 999999)), tostring(getCharacterId(player) or 0) }, "_")
end

local function createCashDropElements(drop)
    drop.marker = createMarker(drop.x, drop.y, drop.z, "cylinder", 1.05, 190, 157, 87, 95)
    drop.object = createObject(1212, drop.x, drop.y, drop.z + 0.12, 0, 0, drop.rotation or 0)
    if drop.marker and isElement(drop.marker) then
        setElementInterior(drop.marker, drop.interior or 0)
        setElementDimension(drop.marker, drop.dimension or 0)
        setElementData(drop.marker, "hrp:drop:id", drop.id, false)
        addEventHandler("onMarkerHit", drop.marker, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                triggerClientEvent(hitElement, "HeavyRPG:Inventory:nearDrop", resourceRoot, true, {
                    id = drop.id,
                    label = "Gotowka",
                    itemId = "cash",
                    quantity = drop.quantity,
                    cash = true,
                    createdAt = drop.createdAt
                })
            end
        end)
        addEventHandler("onMarkerLeave", drop.marker, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                triggerClientEvent(hitElement, "HeavyRPG:Inventory:nearDrop", resourceRoot, false, { id = drop.id, cash = true })
            end
        end)
    end
    if drop.object and isElement(drop.object) then
        setElementInterior(drop.object, drop.interior or 0)
        setElementDimension(drop.object, drop.dimension or 0)
        setElementCollisionsEnabled(drop.object, false)
    end
    cashDrops[drop.id] = drop
end

local function persistCashDrop(drop)
    return HRP.DB.exec([[INSERT INTO world_inventory_drops
        (id, item_id, label, description, category, quantity, weight, quality, state, metadata_json, flags, model,
        pos_x, pos_y, pos_z, rotation, interior, dimension, dropped_by_character_id, dropped_by_account_id, created_at, updated_at)
        VALUES(?, 'cash', 'Gotowka', 'Fizycznie wyrzucona gotowka.', 'money', ?, 0, 100, ?, '{}', 'money,virtual', 1212, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            drop.id,
            drop.quantity,
            "$" .. tostring(drop.quantity),
            drop.x,
            drop.y,
            drop.z,
            drop.rotation,
            drop.interior,
            drop.dimension,
            drop.droppedByCharacterId,
            drop.droppedByAccountId,
            drop.createdAt,
            drop.updatedAt
        })
end

local function findNotebook(player, uid)
    uid = tonumber(uid)
    for _, item in ipairs((HRP.Inventory and HRP.Inventory.getItems and HRP.Inventory.getItems(player)) or {}) do
        if item.itemId == "notebook" and (not uid or tonumber(item.uid) == uid) then return item end
    end
    return nil
end

local function saveNotebook(player, uid, text)
    local item = findNotebook(player, uid)
    if not item then return false, "Nie masz tego notesu." end

    text = HRP.Utils.trim(tostring(text or ""))
    if #text < 1 then return false, "Notatka jest pusta." end
    if #text > 500 then text = text:sub(1, 500) end

    local metadata = type(item.metadata) == "table" and item.metadata or {}
    metadata.note = text

    local ok = HRP.DB.exec([[UPDATE character_inventory
        SET metadata_json = ?, updated_at = ?
        WHERE id = ? AND character_id = ?]], {
            toJSON(metadata, true) or "{}",
            now(),
            item.uid,
            getCharacterId(player)
        })

    if not ok then return false, "Nie udalo sie zapisac notesu." end
    if HRP.Inventory.load then HRP.Inventory.load(player, false) end
    return true, "Zapisano notes."
end

local function giveCash(player, amount)
    amount = money(amount)
    if amount <= 0 then return false, "Podaj poprawna kwote." end
    if money(getPlayerMoney(player)) < amount then return false, "Nie masz tyle gotowki." end
    local target = findNearestPlayer(player, 3.0)
    if not target then return false, "Nie ma nikogo blisko, komu mozna przekazac gotowke." end
    takePlayerMoney(player, amount)
    givePlayerMoney(target, amount)
    syncMoney(player)
    syncMoney(target)
    notify(target, "Otrzymales gotowke: $" .. tostring(amount) .. ".", 180, 220, 170)
    return true, "Przekazano gotowke: $" .. tostring(amount) .. "."
end

local function dropCash(player, amount)
    amount = money(amount)
    if amount <= 0 then return false, "Podaj poprawna kwote." end
    if money(getPlayerMoney(player)) < amount then return false, "Nie masz tyle gotowki." end

    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local timestamp = now()
    local drop = {
        id = makeDropId(player),
        quantity = amount,
        x = x,
        y = y,
        z = z - 0.85,
        rotation = rz or 0,
        interior = getElementInterior(player),
        dimension = getElementDimension(player),
        droppedByCharacterId = getCharacterId(player),
        droppedByAccountId = getAccountId(player),
        createdAt = timestamp,
        updatedAt = timestamp
    }

    takePlayerMoney(player, amount)
    syncMoney(player)
    if not persistCashDrop(drop) then
        givePlayerMoney(player, amount)
        syncMoney(player)
        return false, "Nie udalo sie zapisac dropu gotowki. Gotowka wrocila do kieszeni."
    end
    createCashDropElements(drop)
    return true, "Wyrzucono gotowke na ziemie: $" .. tostring(amount) .. "."
end

local function giveItem(player, uid, amount)
    local item = findVisibleItem(player, uid)
    if not item or item.virtual then return false, "Nie znaleziono przedmiotu do przekazania." end
    local target = findNearestPlayer(player, 3.0)
    if not target then return false, "Nie ma nikogo blisko, komu mozna przekazac przedmiot." end
    amount = math.min(quantity(amount), tonumber(item.quantity) or 1)
    local ok, message = HRP.Inventory.take(player, item.uid, amount)
    if not ok then return false, message end
    local added, addMessage = HRP.Inventory.add(target, item.itemId, amount, item.metadata, item.quality)
    if not added then
        HRP.Inventory.add(player, item.itemId, amount, item.metadata, item.quality)
        return false, addMessage or "Nie udalo sie przekazac przedmiotu."
    end
    notify(target, "Otrzymales: " .. tostring(item.label) .. " x" .. tostring(amount) .. ".", 180, 220, 170)
    return true, "Przekazano: " .. tostring(item.label) .. " x" .. tostring(amount) .. "."
end

local function sellItem(player, uid, amount, price)
    local item = findVisibleItem(player, uid)
    if not item or item.virtual then return false, "Tego przedmiotu nie mozna sprzedac." end
    local target = findNearestPlayer(player, 3.0)
    if not target then return false, "Nie ma nikogo blisko, komu mozna sprzedac przedmiot." end
    amount = math.min(quantity(amount), tonumber(item.quantity) or 1)
    price = money(price)
    if price <= 0 then return false, "Podaj cene sprzedazy." end
    if money(getPlayerMoney(target)) < price then return false, "Kupujacy nie ma tyle gotowki przy sobie." end

    local ok, message = HRP.Inventory.take(player, item.uid, amount)
    if not ok then return false, message end
    takePlayerMoney(target, price)
    givePlayerMoney(player, price)
    syncMoney(player)
    syncMoney(target)

    local added, addMessage = HRP.Inventory.add(target, item.itemId, amount, item.metadata, item.quality)
    if not added then
        takePlayerMoney(player, price)
        givePlayerMoney(target, price)
        syncMoney(player)
        syncMoney(target)
        HRP.Inventory.add(player, item.itemId, amount, item.metadata, item.quality)
        return false, addMessage or "Nie udalo sie przekazac przedmiotu kupujacemu."
    end

    notify(target, "Kupiles: " .. tostring(item.label) .. " x" .. tostring(amount) .. " za $" .. tostring(price) .. ".", 180, 220, 170)
    return true, "Sprzedano: " .. tostring(item.label) .. " x" .. tostring(amount) .. " za $" .. tostring(price) .. "."
end

addEvent("HeavyRPG:Inventory:pickupCashDrop", true)
addEventHandler("HeavyRPG:Inventory:pickupCashDrop", resourceRoot, function(dropId)
    local player = client
    local drop = cashDrops[tostring(dropId or "")]
    if not isElement(player) or not drop then return end
    if getElementInterior(player) ~= drop.interior or getElementDimension(player) ~= drop.dimension then notify(player, "Jestes za daleko.", 230, 90, 80) return end
    local px, py, pz = getElementPosition(player)
    if getDistanceBetweenPoints3D(px, py, pz, drop.x, drop.y, drop.z) > 2.5 then notify(player, "Jestes za daleko.", 230, 90, 80) return end
    givePlayerMoney(player, drop.quantity)
    syncMoney(player)
    HRP.DB.exec([[DELETE FROM world_inventory_drops WHERE id = ?]], { drop.id })
    destroyCashDrop(drop.id)
    triggerClientEvent(player, "HeavyRPG:Inventory:nearDrop", resourceRoot, false, { id = drop.id, cash = true })
    notify(player, "Podniesiono gotowke: $" .. tostring(drop.quantity) .. ".", 180, 220, 170)
end)

addEvent("HeavyRPG:Inventory:menuAction", true)
addEventHandler("HeavyRPG:Inventory:menuAction", resourceRoot, function(action, payload)
    local player = client
    if not isElement(player) or not getCharacterId(player) then return end

    action = tostring(action or "")
    payload = parsePayload(payload)

    local ok, message = false, "Nieznana akcja ekwipunku."
    if action == "cash_give" then
        ok, message = giveCash(player, payload.amount)
    elseif action == "cash_drop" or action == "cash_drop_all" then
        ok, message = dropCash(player, payload.amount)
    elseif action == "item_give" then
        ok, message = giveItem(player, payload.uid, payload.amount)
    elseif action == "item_drop" then
        ok, message = HRP.Inventory.drop(player, tonumber(payload.uid), payload.amount or 1)
    elseif action == "item_sell" then
        ok, message = sellItem(player, payload.uid, payload.amount, payload.price)
    elseif action == "notebook_save" then
        ok, message = saveNotebook(player, payload.uid, payload.text)
    elseif action == "phone_open" and HRP.Phone and HRP.Phone.openPanel then
        ok, message = HRP.Phone.openPanel(player)
    elseif action == "phone_contacts" and HRP.Phone and HRP.Phone.openContacts then
        ok, message = HRP.Phone.openContacts(player)
    elseif action == "phone_sms_help" then
        ok, message = true, "SMS: /sms <numer> <tresc>, kontakt: /kontakt <nazwa> <numer>."
    end

    notify(player, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for dropId in pairs(cashDrops) do destroyCashDrop(dropId) end
end)