HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Inventory = HRP.Inventory or {}
local Inventory = HRP.Inventory

local inventories = {}
local worldDrops = {}
local nextDropId = 1
local utilityItems = { cash = true, id_card = true, phone = true, notebook = true, lockpick = true }

local schema = {
    [[CREATE TABLE IF NOT EXISTS character_inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character_id INTEGER NOT NULL,
        item_id TEXT NOT NULL,
        label TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'misc',
        quantity INTEGER NOT NULL DEFAULT 1,
        weight REAL NOT NULL DEFAULT 0,
        quality INTEGER NOT NULL DEFAULT 100,
        state TEXT NOT NULL DEFAULT 'normal',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        flags TEXT NOT NULL DEFAULT '',
        slot INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(character_id) REFERENCES characters(id) ON DELETE CASCADE
    )]],
    [[CREATE INDEX IF NOT EXISTS idx_character_inventory_character ON character_inventory(character_id, slot, id)]],
    [[CREATE INDEX IF NOT EXISTS idx_character_inventory_item ON character_inventory(character_id, item_id)]]
}

local function cfg() return HRP.Config.inventory or {} end
local function definitions() return cfg().items or {} end
local function starterItems() return cfg().starterItems or {} end
local function now() return HRP.Utils.now() end
local function number(value, fallback) value = tonumber(value) if not value then return fallback or 0 end return value end
local function int(value, fallback) return math.floor(number(value, fallback or 0)) end
local function money(value) value = int(value, 0) if value < 0 then return 0 end return value end
local function getCharacterId(player) return tonumber(getElementData(player, "hrp:character:id")) end
local function getAccountId(player) return tonumber(getElementData(player, "hrp:account:id")) or (HRP.Auth and HRP.Auth.Session and HRP.Auth.Session.getAccountId(player)) end
local function getDefinition(itemId) return definitions()[tostring(itemId or "")] end

local function quantity(value)
    value = int(value, 1)
    if value < 1 then return 1 end
    if value > 999 then return 999 end
    return value
end

local function clampQuality(value)
    value = int(value, 100)
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

local function itemWeight(itemId, fallback)
    local def = getDefinition(itemId)
    return number(def and def.weight, number(fallback, 0))
end

local function jsonEncode(value)
    if type(value) ~= "table" then return "{}" end
    return toJSON(value, true) or "{}"
end

local function jsonDecode(value)
    if type(value) ~= "string" or #value == 0 then return {} end
    local decoded = fromJSON(value)
    return type(decoded) == "table" and decoded or {}
end

local function isEmptyMetadata(value)
    if type(value) ~= "table" then return true end
    for _ in pairs(value) do return false end
    return true
end

local function parseFlags(flags)
    local parsed = {}
    flags = tostring(flags or "")
    for flag in flags:gmatch("[^,]+") do parsed[#parsed + 1] = flag end
    return parsed
end

local function notify(player, message, r, g, b)
    if isElement(player) then outputChatBox("[EQ] " .. tostring(message), player, r or 210, g or 198, b or 164) end
end

local function publicItem(row)
    if not row then return nil end
    local itemId = tostring(row.item_id or row.id or "")
    local def = getDefinition(itemId) or {}
    local qty = quantity(row.quantity)
    local weight = itemWeight(itemId, row.weight)

    return {
        uid = tonumber(row.id),
        itemId = itemId,
        label = tostring(row.label or def.label or itemId),
        description = tostring(row.description or def.description or ""),
        category = tostring(row.category or def.category or "misc"),
        quantity = qty,
        weight = weight,
        totalWeight = weight * qty,
        quality = clampQuality(row.quality),
        state = tostring(row.state or "normal"),
        metadata = jsonDecode(row.metadata_json),
        flags = parseFlags(row.flags),
        slot = int(row.slot, 0),
        usable = def.usable == true or utilityItems[itemId] == true,
        stackable = def.stackable ~= false,
        virtual = false,
        createdAt = tonumber(row.created_at) or 0,
        updatedAt = tonumber(row.updated_at) or 0
    }
end

local function cashItem(player)
    local def = getDefinition("cash") or {}
    local cash = isElement(player) and money(getPlayerMoney(player)) or 0
    return {
        uid = -1,
        itemId = "cash",
        label = tostring(def.label or "Gotowka"),
        description = tostring(def.description or "Pieniadze trzymane przy sobie."),
        category = tostring(def.category or "money"),
        quantity = cash,
        weight = 0,
        totalWeight = 0,
        quality = 100,
        state = "$" .. tostring(cash),
        metadata = {},
        flags = parseFlags(def.flags or "money,virtual"),
        slot = -100,
        usable = true,
        stackable = false,
        virtual = true,
        createdAt = 0,
        updatedAt = now()
    }
end

local function sortItems(a, b)
    if (a.slot or 0) ~= (b.slot or 0) then return (a.slot or 0) < (b.slot or 0) end
    if a.category ~= b.category then return tostring(a.category) < tostring(b.category) end
    if a.label ~= b.label then return tostring(a.label) < tostring(b.label) end
    return (a.uid or 0) < (b.uid or 0)
end

local function currentWeight(items)
    local total = 0
    for _, item in ipairs(items or {}) do if not item.virtual then total = total + number(item.totalWeight, 0) end end
    return total
end

local function visibleItems(player, items)
    local out = { cashItem(player) }
    for _, item in ipairs(items or {}) do out[#out + 1] = item end
    table.sort(out, sortItems)
    return out
end

function Inventory.getMaxWeight(player)
    local base = number(cfg().maxWeight, 35)
    local strength = number(getElementData(player, "hrp:stat:strength"), 0)
    return base + math.max(0, strength) * number(cfg().weightPerStrength, 1.5)
end

local function buildPayload(player)
    local state = inventories[player] or { items = {} }
    return {
        items = visibleItems(player, state.items),
        currentWeight = currentWeight(state.items),
        maxWeight = Inventory.getMaxWeight(player),
        slots = number(cfg().slots, 48),
        categories = cfg().categories or {},
        updatedAt = now()
    }
end

function Inventory.sync(player)
    if not isElement(player) then return false end
    local payload = buildPayload(player)
    setElementData(player, "hrp:inventory:weight", payload.currentWeight, false)
    triggerClientEvent(player, "HeavyRPG:Inventory:sync", resourceRoot, payload)
    return true
end

local function saveCharacterCash(player)
    local characterId = getCharacterId(player)
    if not characterId then return false end
    return HRP.DB.exec([[UPDATE characters SET cash = ?, updated_at = ? WHERE id = ?]], { money(getPlayerMoney(player)), now(), characterId })
end

local function syncMoneySystems(player)
    saveCharacterCash(player)
    if HRP.Bank and HRP.Bank.sync then HRP.Bank.sync(player) end
    Inventory.sync(player)
end

local function ensureSchema()
    for _, sql in ipairs(schema) do
        if not HRP.DB.exec(sql) then
            HRP.Logger.error("inventory", "Nie udalo sie przygotowac tabeli ekwipunku: " .. tostring(sql))
            return false
        end
    end
    return true
end

local function setState(player, rows)
    local items = {}
    for _, row in ipairs(rows or {}) do
        local item = publicItem(row)
        if item and item.uid then items[#items + 1] = item end
    end
    table.sort(items, sortItems)
    inventories[player] = { items = items, loadedAt = now() }
    Inventory.sync(player)
end

local function insertItemRow(characterId, itemId, qty, metadata, quality, slot)
    local def = getDefinition(itemId)
    if not def then return false, "Nieznany przedmiot: " .. tostring(itemId) end
    if def.virtual then return false, "Tego przedmiotu nie zapisuje sie w tabeli." end

    local timestamp = now()
    return HRP.DB.exec([[INSERT INTO character_inventory
        (character_id, item_id, label, description, category, quantity, weight, quality, state, metadata_json, flags, slot, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            characterId,
            tostring(itemId),
            tostring(def.label or itemId),
            tostring(def.description or ""),
            tostring(def.category or "misc"),
            quantity(qty),
            itemWeight(itemId, 0),
            clampQuality(quality),
            tostring((metadata and metadata.state) or "normal"),
            jsonEncode(metadata),
            tostring(def.flags or ""),
            int(slot, 0),
            timestamp,
            timestamp
        })
end

local function seedStarterItems(player, characterId, callback)
    local slot = 1
    for _, entry in ipairs(starterItems()) do
        local itemId = entry.itemId or entry.id
        if itemId then
            insertItemRow(characterId, itemId, entry.quantity or 1, entry.metadata, entry.quality or 100, entry.slot or slot)
            slot = slot + 1
        end
    end
    if callback then callback() end
end

function Inventory.load(player, seedIfEmpty)
    if not isElement(player) then return false end
    local characterId = getCharacterId(player)
    if not characterId then return false end

    return HRP.DB.query([[SELECT * FROM character_inventory WHERE character_id = ? ORDER BY slot ASC, id ASC]], { characterId }, function(rows)
        if not isElement(player) then return end
        rows = rows or {}
        if seedIfEmpty and #rows == 0 and (cfg().seedStarterItems ~= false) then
            seedStarterItems(player, characterId, function() Inventory.load(player, false) end)
            return
        end
        setState(player, rows)
    end)
end

local function findItem(player, uid)
    uid = tonumber(uid)
    if not uid or uid < 1 then return nil end
    local state = inventories[player]
    if not state then return nil end
    for _, item in ipairs(state.items or {}) do if tonumber(item.uid) == uid then return item end end
    return nil
end

local function findStack(player, itemId, quality, stateName)
    local state = inventories[player]
    if not state then return nil end
    quality = clampQuality(quality)
    stateName = tostring(stateName or "normal")
    for _, item in ipairs(state.items or {}) do
        if item.itemId == itemId and item.stackable and item.quality == quality and item.state == stateName then return item end
    end
    return nil
end

function Inventory.getItemQuantity(player, itemId)
    itemId = tostring(itemId or "")
    if itemId == "cash" then return money(getPlayerMoney(player)) end
    local total = 0
    local state = inventories[player]
    for _, item in ipairs((state and state.items) or {}) do if item.itemId == itemId then total = total + quantity(item.quantity) end end
    return total
end

local function removeQuantity(player, uid, amount)
    local item = findItem(player, uid)
    if not item then return false, "Nie znaleziono przedmiotu." end
    amount = quantity(amount)
    local characterId = getCharacterId(player)
    if not characterId then return false, "Brak aktywnej postaci." end

    if amount >= item.quantity then
        if not HRP.DB.exec([[DELETE FROM character_inventory WHERE id = ? AND character_id = ?]], { item.uid, characterId }) then return false, "Nie udalo sie usunac przedmiotu." end
    else
        if not HRP.DB.exec([[UPDATE character_inventory SET quantity = quantity - ?, updated_at = ? WHERE id = ? AND character_id = ?]], { amount, now(), item.uid, characterId }) then return false, "Nie udalo sie zmienic ilosci przedmiotu." end
    end

    Inventory.load(player, false)
    return true
end

function Inventory.add(player, itemId, qty, metadata, quality)
    if not isElement(player) then return false, "Gracz offline." end
    local characterId = getCharacterId(player)
    if not characterId then return false, "Brak aktywnej postaci." end

    itemId = tostring(itemId or "")
    qty = quantity(qty)
    if itemId == "cash" then
        givePlayerMoney(player, qty)
        syncMoneySystems(player)
        return true, "Dodano gotowke: $" .. tostring(qty) .. "."
    end

    local def = getDefinition(itemId)
    if not def then return false, "Nieznany przedmiot." end
    if def.virtual then return false, "Tego przedmiotu nie mozna dodac jako zwykly item." end

    local payload = buildPayload(player)
    local addedWeight = itemWeight(itemId, 0) * qty
    if payload.currentWeight + addedWeight > payload.maxWeight then return false, "Ekwipunek jest za ciezki." end

    local stateName = tostring((metadata and metadata.state) or "normal")
    local finalQuality = clampQuality(quality)
    local stack = (def.stackable ~= false and isEmptyMetadata(metadata)) and findStack(player, itemId, finalQuality, stateName) or nil
    if stack then
        if not HRP.DB.exec([[UPDATE character_inventory SET quantity = quantity + ?, updated_at = ? WHERE id = ? AND character_id = ?]], { qty, now(), stack.uid, characterId }) then return false, "Nie udalo sie powiekszyc stosu przedmiotu." end
    else
        local ok = insertItemRow(characterId, itemId, qty, metadata, finalQuality, 0)
        if not ok then return false, "Nie udalo sie dodac przedmiotu." end
    end

    Inventory.load(player, false)
    return true, "Dodano: " .. tostring(def.label or itemId) .. " x" .. tostring(qty) .. "."
end

function Inventory.take(player, uid, qty) return removeQuantity(player, uid, qty) end

function Inventory.takeByItemId(player, itemId, qty)
    if not isElement(player) then return false, "Gracz offline." end
    itemId = tostring(itemId or "")
    qty = quantity(qty)
    if itemId == "cash" then
        if money(getPlayerMoney(player)) < qty then return false, "Gracz nie ma tyle gotowki przy sobie." end
        takePlayerMoney(player, qty)
        syncMoneySystems(player)
        return true, "Zabrano gotowke: $" .. tostring(qty) .. "."
    end

    if Inventory.getItemQuantity(player, itemId) < qty then return false, "Gracz nie ma wymaganej ilosci tego przedmiotu." end
    local remaining = qty
    local state = inventories[player]
    for _, item in ipairs((state and state.items) or {}) do
        if item.itemId == itemId and remaining > 0 then
            local taken = math.min(remaining, item.quantity)
            local ok, reason = removeQuantity(player, item.uid, taken)
            if not ok then return false, reason end
            remaining = remaining - taken
        end
    end
    return true, "Zabrano " .. tostring(itemId) .. " x" .. tostring(qty) .. "."
end

function Inventory.getItems(player) local state = inventories[player] return state and state.items or {} end
function Inventory.getVisibleItems(player) return visibleItems(player, Inventory.getItems(player)) end
function Inventory.getWeight(player) return currentWeight(Inventory.getItems(player)) end

local function dropModel(item)
    local models = (cfg().dropModels or {})
    return tonumber(models[item.itemId] or models[item.category] or models.default) or 1271
end

local function publicDrop(drop)
    return {
        id = drop.id,
        label = drop.label,
        itemId = drop.itemId,
        quantity = drop.quantity,
        x = drop.x,
        y = drop.y,
        z = drop.z,
        createdAt = drop.createdAt
    }
end

local function destroyDrop(dropId)
    local drop = worldDrops[dropId]
    if not drop then return end
    if drop.marker and isElement(drop.marker) then destroyElement(drop.marker) end
    if drop.object and isElement(drop.object) then destroyElement(drop.object) end
    worldDrops[dropId] = nil
end

local function createWorldDrop(player, item, qty)
    if not isElement(player) or not item then return false end
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local dropId = nextDropId
    nextDropId = nextDropId + 1

    local drop = {
        id = dropId,
        itemId = item.itemId,
        label = item.label,
        description = item.description,
        category = item.category,
        quantity = quantity(qty),
        weight = item.weight,
        quality = item.quality,
        state = item.state,
        metadata = item.metadata or {},
        flags = item.flags or {},
        x = x,
        y = y,
        z = z - 0.85,
        interior = getElementInterior(player),
        dimension = getElementDimension(player),
        createdAt = now()
    }

    drop.marker = createMarker(drop.x, drop.y, drop.z, "cylinder", 1.15, 190, 157, 87, 95)
    drop.object = createObject(dropModel(item), drop.x, drop.y, drop.z + 0.18, 0, 0, rz or 0)
    if drop.marker and isElement(drop.marker) then
        setElementInterior(drop.marker, drop.interior)
        setElementDimension(drop.marker, drop.dimension)
        setElementData(drop.marker, "hrp:drop:id", drop.id, false)
        addEventHandler("onMarkerHit", drop.marker, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                triggerClientEvent(hitElement, "HeavyRPG:Inventory:nearDrop", resourceRoot, true, publicDrop(drop))
            end
        end)
        addEventHandler("onMarkerLeave", drop.marker, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                triggerClientEvent(hitElement, "HeavyRPG:Inventory:nearDrop", resourceRoot, false, { id = drop.id })
            end
        end)
    end
    if drop.object and isElement(drop.object) then
        setElementInterior(drop.object, drop.interior)
        setElementDimension(drop.object, drop.dimension)
        setElementCollisionsEnabled(drop.object, false)
    end

    worldDrops[dropId] = drop
    setTimer(function(id) destroyDrop(id) end, 2 * 60 * 60 * 1000, 1, dropId)
    return true
end

local function sendActionPanel(player, title, lines, footer)
    triggerClientEvent(player, "HeavyRPG:Inventory:action", resourceRoot, {
        title = title,
        lines = lines or {},
        footer = footer or "ESC - zamknij"
    })
end

local function broadcastNearby(player, message)
    local x, y, z = getElementPosition(player)
    for _, target in ipairs(getElementsWithinRange(x, y, z, 10, "player")) do
        outputChatBox("[RP] " .. tostring(message), target, 190, 170, 120)
    end
end

local function handleUtilityUse(player, itemId, item)
    local characterId = getCharacterId(player)
    if itemId == "cash" then
        local cash = money(getPlayerMoney(player))
        local bank = HRP.Bank and HRP.Bank.getBalance and HRP.Bank.getBalance(player) or 0
        sendActionPanel(player, "GOTOWKA W KIESZENI", {
            "Przy sobie: $" .. tostring(cash),
            "Na koncie bankowym: $" .. tostring(bank),
            "Gotowka jest fizyczna: mozna ja dac/zabrac komendami administracyjnymi albo podpiac pod handel.",
            "Wplata i wyplata sa pod komendami banku: /wplac oraz /wyplac."
        })
        return true, "Sprawdzono gotowke."
    end

    if itemId == "id_card" then
        local name = HRP.Utils.safePlayerName(player)
        sendActionPanel(player, "DOWOD OSOBISTY", {
            "Imie i nazwisko: " .. name,
            "ID postaci: #" .. tostring(characterId or "brak"),
            "ID konta: #" .. tostring(getAccountId(player) or "brak"),
            "Status dokumentu: wazny",
            "Uzycie RP: okazanie dokumentu w poblizu postaci."
        })
        broadcastNearby(player, name .. " okazuje dowod osobisty.")
        return true, "Okazano dowod osobisty."
    end

    if itemId == "phone" then
        sendActionPanel(player, "TELEFON KOMORKOWY", {
            "Stan: wlaczony",
            "Numer: nieprzypisany",
            "Dostepne funkcje szkieletowe: kontakty, SMS, ogloszenia, bank, notatki.",
            "Telefon jest gotowy pod osobny modul UI, ale juz dziala jako item RP."
        })
        return true, "Wyciagnieto telefon."
    end

    if itemId == "notebook" then
        local note = item and item.metadata and item.metadata.note or "Brak wpisu."
        sendActionPanel(player, "NOTES POSTACI", {
            "Aktualna notatka:",
            tostring(note),
            "Aby zapisac nowa tresc uzyj: /notatka <tekst>",
            "Notatka zapisuje sie w metadanych tego przedmiotu."
        })
        return true, "Otworzono notes."
    end

    if itemId == "lockpick" then
        sendActionPanel(player, "WYTRYCH", {
            "To narzedzie jest gotowe pod system drzwi, pojazdow i wlaman.",
            "Aktualnie nie ma jeszcze celu uzycia w zasiegu.",
            "Przedmiot nie zostal zuzyty."
        })
        return true, "Sprawdzono wytrych."
    end

    return false, "Tego przedmiotu nie da sie jeszcze uzyc."
end

local function applyItemEffect(player, item)
    local def = getDefinition(item.itemId)
    if utilityItems[item.itemId] then return handleUtilityUse(player, item.itemId, item) end
    if not def or def.usable ~= true then return false, "Tego przedmiotu nie da sie uzyc." end

    local effect = def.effect or {}
    local used = false
    if effect.health then setElementHealth(player, math.min(100, getElementHealth(player) + number(effect.health, 0))) used = true end
    if effect.armor then setPedArmor(player, math.min(100, getPedArmor(player) + number(effect.armor, 0))) used = true end
    if effect.cash then givePlayerMoney(player, math.max(0, int(effect.cash, 0))) syncMoneySystems(player) used = true end
    if type(effect.needs) == "table" and HRP.Survival then
        for key, amount in pairs(effect.needs) do HRP.Survival.add(player, key, amount, true) used = true end
    end
    if not used then return false, "Przedmiot nie ma jeszcze efektu." end
    if def.consume ~= false then removeQuantity(player, item.uid, 1) else Inventory.sync(player) end
    triggerEvent("HeavyRPG:Inventory:onItemUsed", resourceRoot, player, item.itemId, item.uid)
    return true, tostring(def.useMessage or ("Uzyto: " .. item.label .. "."))
end

function Inventory.use(player, uid, itemId)
    if not isElement(player) then return false, "Gracz offline." end
    if tonumber(uid) == -1 and tostring(itemId) == "cash" then return handleUtilityUse(player, "cash", cashItem(player)) end
    local item = findItem(player, uid)
    if not item then return false, "Nie znaleziono przedmiotu." end
    return applyItemEffect(player, item)
end

function Inventory.drop(player, uid, qty)
    if not isElement(player) then return false, "Gracz offline." end
    local item = findItem(player, uid)
    if not item then return false, "Nie znaleziono przedmiotu." end
    qty = quantity(qty)
    local droppedQty = math.min(qty, item.quantity)
    local ok, reason = removeQuantity(player, uid, droppedQty)
    if not ok then return false, reason end
    createWorldDrop(player, item, droppedQty)
    triggerEvent("HeavyRPG:Inventory:onItemDropped", resourceRoot, player, item.itemId, droppedQty)
    return true, "Wyrzucono na ziemie: " .. tostring(item.label) .. " x" .. tostring(droppedQty) .. "."
end

function Inventory.pickupDrop(player, dropId)
    if not isElement(player) then return false, "Gracz offline." end
    local drop = worldDrops[tonumber(dropId)]
    if not drop then return false, "Ten przedmiot juz zniknal." end
    if getElementInterior(player) ~= drop.interior or getElementDimension(player) ~= drop.dimension then return false, "Jestes za daleko." end
    local px, py, pz = getElementPosition(player)
    if getDistanceBetweenPoints3D(px, py, pz, drop.x, drop.y, drop.z) > 2.5 then return false, "Jestes za daleko." end

    local ok, message = Inventory.add(player, drop.itemId, drop.quantity, drop.metadata, drop.quality)
    if not ok then return false, message end
    destroyDrop(drop.id)
    triggerClientEvent(player, "HeavyRPG:Inventory:nearDrop", resourceRoot, false, { id = drop.id })
    return true, "Podniesiono: " .. tostring(drop.label) .. " x" .. tostring(drop.quantity) .. "."
end

local function updateNotebook(player, text)
    text = HRP.Utils.trim(table.concat({ text or "" }, " "))
    if #text < 1 then return false, "Uzycie: /notatka <tekst>" end
    if #text > 220 then text = text:sub(1, 220) end
    local item
    for _, entry in ipairs(Inventory.getItems(player)) do if entry.itemId == "notebook" then item = entry break end end
    if not item then return false, "Nie masz notesu." end
    local metadata = item.metadata or {}
    metadata.note = text
    if not HRP.DB.exec([[UPDATE character_inventory SET metadata_json = ?, updated_at = ? WHERE id = ? AND character_id = ?]], { jsonEncode(metadata), now(), item.uid, getCharacterId(player) }) then return false, "Nie udalo sie zapisac notatki." end
    Inventory.load(player, false)
    return true, "Zapisano notatke w notesie."
end

local function attachPlayer(player) if isElement(player) then Inventory.load(player, true) end end
local function detachPlayer(player) if isElement(player) then inventories[player] = nil setElementData(player, "hrp:inventory:weight", false, false) end end

local function handleOpenCommand(player)
    if not getCharacterId(player) then notify(player, "Najpierw wybierz postac.", 230, 90, 80) return end
    Inventory.sync(player)
    triggerClientEvent(player, "HeavyRPG:Inventory:open", resourceRoot)
end

local function getAdminLevel(player)
    local account = HRP.Auth and HRP.Auth.Session and HRP.Auth.Session.getAccount(player)
    return tonumber(account and account.adminLevel) or 0
end

local function findPlayer(query)
    query = tostring(query or "")
    if #query == 0 then return nil end
    local numeric = tonumber(query)
    for _, player in ipairs(getElementsByType("player")) do if numeric and getCharacterId(player) == numeric then return player end end
    local lowered = HRP.Utils.lower(query)
    for _, player in ipairs(getElementsByType("player")) do if HRP.Utils.lower(HRP.Utils.safePlayerName(player)):find(lowered, 1, true) then return player end end
    return nil
end

local function handleGiveCommand(player, _, targetQuery, itemId, qty, quality)
    if getAdminLevel(player) <= 0 then notify(player, "Brak uprawnien.", 230, 90, 80) return end
    local target = findPlayer(targetQuery)
    if not target then notify(player, "Uzycie: /" .. ((cfg().commands and cfg().commands.give) or "dajitem") .. " <gracz/id_postaci> <item_id|cash> [ilosc] [jakosc]", 230, 90, 80) return end
    local ok, message = Inventory.add(target, itemId, qty or 1, nil, quality or 100)
    notify(player, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
    if ok and target ~= player then notify(target, message, 180, 220, 170) end
end

local function handleTakeCommand(player, _, targetQuery, itemKey, qty)
    if getAdminLevel(player) <= 0 then notify(player, "Brak uprawnien.", 230, 90, 80) return end
    local target = findPlayer(targetQuery)
    if not target then notify(player, "Uzycie: /" .. ((cfg().commands and cfg().commands.take) or "zabierzitem") .. " <gracz/id_postaci> <uid|item_id|cash> [ilosc]", 230, 90, 80) return end
    local ok, message
    if tonumber(itemKey) then ok, message = Inventory.take(target, tonumber(itemKey), qty or 1) else ok, message = Inventory.takeByItemId(target, itemKey, qty or 1) end
    notify(player, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
    if ok and target ~= player then notify(target, message, 230, 180, 120) end
end

local function handleListCommand(player)
    if getAdminLevel(player) <= 0 then notify(player, "Brak uprawnien.", 230, 90, 80) return end
    local ids = {}
    for itemId, def in pairs(definitions()) do if not def.virtual then ids[#ids + 1] = itemId end end
    table.sort(ids)
    notify(player, "Dostepne itemy: " .. table.concat(ids, ", ") .. ", cash")
end

local function handleNoteCommand(player, _, ...)
    local ok, message = updateNotebook(player, table.concat({ ... }, " "))
    notify(player, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end

addEvent("HeavyRPG:Inventory:request", true)
addEventHandler("HeavyRPG:Inventory:request", resourceRoot, function() if isElement(client) and getCharacterId(client) then Inventory.load(client, false) end end)

addEvent("HeavyRPG:Inventory:use", true)
addEventHandler("HeavyRPG:Inventory:use", resourceRoot, function(uid, itemId)
    local ok, message = Inventory.use(client, tonumber(uid), itemId)
    notify(client, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)

addEvent("HeavyRPG:Inventory:drop", true)
addEventHandler("HeavyRPG:Inventory:drop", resourceRoot, function(uid, qty)
    local ok, message = Inventory.drop(client, tonumber(uid), qty or 1)
    notify(client, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)

addEvent("HeavyRPG:Inventory:pickupDrop", true)
addEventHandler("HeavyRPG:Inventory:pickupDrop", resourceRoot, function(dropId)
    local ok, message = Inventory.pickupDrop(client, tonumber(dropId))
    notify(client, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)

addEvent("HeavyRPG:Inventory:onItemUsed", false)
addEvent("HeavyRPG:Inventory:onItemDropped", false)

local module = {}
function module.onStart()
    if not ensureSchema() then return end
    local commands = cfg().commands or {}
    addEventHandler("HeavyRPG:Character:onPlayerReady", resourceRoot, attachPlayer)
    addEventHandler("onPlayerQuit", root, function() detachPlayer(source) end)
    addCommandHandler(commands.open or "eq", handleOpenCommand)
    addCommandHandler("ekwipunek", handleOpenCommand)
    addCommandHandler(commands.give or "dajitem", handleGiveCommand)
    addCommandHandler(commands.take or "zabierzitem", handleTakeCommand)
    addCommandHandler(commands.list or "itemy", handleListCommand)
    addCommandHandler("notatka", handleNoteCommand)
    HRP.Logger.info("inventory", "Tekstowy system ekwipunku DX/SQLite gotowy z dropami swiata.")
end

addEventHandler("onResourceStop", resourceRoot, function()
    for dropId in pairs(worldDrops) do destroyDrop(dropId) end
end)

function givePlayerInventoryItem(player, itemId, qty, metadata, quality) return Inventory.add(player, itemId, qty, metadata, quality) end
function takePlayerInventoryItem(player, uid, qty) return Inventory.take(player, uid, qty) end
function takePlayerInventoryItemById(player, itemId, qty) return Inventory.takeByItemId(player, itemId, qty) end
function getPlayerInventoryItems(player) return Inventory.getItems(player) end
function getPlayerInventoryItemQuantity(player, itemId) return Inventory.getItemQuantity(player, itemId) end
function getPlayerInventoryWeight(player) return Inventory.getWeight(player), Inventory.getMaxWeight(player) end

HRP.Modules.register("inventory", module)
