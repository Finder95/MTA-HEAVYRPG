HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

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

local function getCharacterId(player)
    return tonumber(getElementData(player, "hrp:character:id"))
end

local function saveCash(player)
    local characterId = getCharacterId(player)
    if not characterId then return false end
    return HRP.DB.exec([[UPDATE characters SET cash = ?, updated_at = ? WHERE id = ?]], {
        money(getPlayerMoney(player)),
        HRP.Utils.now(),
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

local function findNotebook(player)
    if not HRP.Inventory or not HRP.Inventory.getItems then return nil end
    for _, item in ipairs(HRP.Inventory.getItems(player) or {}) do
        if item.itemId == "notebook" then return item end
    end
    return nil
end

local function saveNotebook(player, text)
    local item = findNotebook(player)
    if not item then return false, "Nie masz notesu." end

    text = HRP.Utils.trim(tostring(text or ""))
    if #text < 1 then return false, "Notatka jest pusta." end
    if #text > 500 then text = text:sub(1, 500) end

    local metadata = type(item.metadata) == "table" and item.metadata or {}
    metadata.note = text

    local ok = HRP.DB.exec([[UPDATE character_inventory
        SET metadata_json = ?, updated_at = ?
        WHERE id = ? AND character_id = ?]], {
            toJSON(metadata, true) or "{}",
            HRP.Utils.now(),
            item.uid,
            getCharacterId(player)
        })

    if not ok then return false, "Nie udalo sie zapisac notesu." end
    if HRP.Inventory.load then HRP.Inventory.load(player, false) end
    return true, "Zapisano notes."
end

local function executeCashAction(player, action, amount)
    amount = money(amount)

    if action == "cash_deposit_all" then
        amount = money(getPlayerMoney(player))
        if amount <= 0 then return false, "Nie masz gotowki przy sobie." end
        if HRP.Bank and HRP.Bank.deposit then return HRP.Bank.deposit(player, amount, "Ekwipunek: wplata calej gotowki") end
        return false, "System bankowy nie jest dostepny."
    end

    if action == "cash_deposit" then
        if amount <= 0 then return false, "Podaj poprawna kwote." end
        if HRP.Bank and HRP.Bank.deposit then return HRP.Bank.deposit(player, amount, "Ekwipunek: wplata gotowki") end
        return false, "System bankowy nie jest dostepny."
    end

    if action == "cash_withdraw" then
        if amount <= 0 then return false, "Podaj poprawna kwote." end
        if HRP.Bank and HRP.Bank.withdraw then return HRP.Bank.withdraw(player, amount, "Ekwipunek: wyplata gotowki") end
        return false, "System bankowy nie jest dostepny."
    end

    return false, "Nieznana akcja gotowki."
end

addEvent("HeavyRPG:Inventory:menuAction", true)
addEventHandler("HeavyRPG:Inventory:menuAction", resourceRoot, function(action, payload)
    local player = client
    if not isElement(player) or not getCharacterId(player) then return end

    action = tostring(action or "")
    payload = parsePayload(payload)

    local ok, message = false, "Nieznana akcja ekwipunku."
    if action == "cash_deposit_all" or action == "cash_deposit" or action == "cash_withdraw" then
        ok, message = executeCashAction(player, action, payload.amount)
        syncMoney(player)
    elseif action == "notebook_save" then
        ok, message = saveNotebook(player, payload.text)
    end

    notify(player, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)
