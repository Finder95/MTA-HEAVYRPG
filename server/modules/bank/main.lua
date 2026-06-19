HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Bank = HRP.Bank or {}
local Bank = HRP.Bank

local balances = {}

local function money(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then return 0 end
    return value
end

local function getCharacterId(player)
    return tonumber(getElementData(player, "hrp:character:id"))
end

local function getAccountId(player)
    return tonumber(getElementData(player, "hrp:account:id")) or HRP.Auth.Session.getAccountId(player)
end

local function getPlayerLabel(player)
    local characterId = getCharacterId(player)
    local name = HRP.Utils.safePlayerName(player)
    return name .. (characterId and (" #" .. tostring(characterId)) or "")
end

local function sync(player)
    if not isElement(player) then return false end
    local payload = {
        cash = money(getPlayerMoney(player)),
        bank = money(balances[player] or 0)
    }
    setElementData(player, "hrp:bank", payload.bank, false)
    triggerClientEvent(player, "HeavyRPG:Bank:sync", resourceRoot, payload)
    return true
end

function Bank.sync(player)
    return sync(player)
end

function Bank.getBalance(player)
    return money(balances[player] or 0)
end

function Bank.getCash(player)
    if not isElement(player) then return 0 end
    return money(getPlayerMoney(player))
end

local function saveMoney(player)
    local characterId = getCharacterId(player)
    if not characterId then return false end

    return HRP.DB.exec([[UPDATE characters
        SET cash = ?, bank = ?, updated_at = ?
        WHERE id = ?]], {
            money(getPlayerMoney(player)),
            money(balances[player] or 0),
            HRP.Utils.now(),
            characterId
        })
end

local function record(player, kind, amount, title, targetCharacterId, metaJson)
    local characterId = getCharacterId(player)
    local accountId = getAccountId(player)
    if not characterId or not accountId then return false end

    return HRP.DB.exec([[INSERT INTO bank_transactions
        (character_id, account_id, type, amount, balance_after, title, target_character_id, meta_json, created_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            characterId,
            accountId,
            tostring(kind or "unknown"),
            math.floor(tonumber(amount) or 0),
            money(balances[player] or 0),
            tostring(title or ""),
            targetCharacterId,
            tostring(metaJson or "{}"),
            HRP.Utils.now()
        })
end

local function notify(player, message, r, g, b)
    if not isElement(player) then return end
    outputChatBox("[BANK] " .. tostring(message), player, r or 80, g or 255, b or 160)
end

function Bank.deposit(player, amount, title)
    if not isElement(player) then return false, "Gracz offline." end
    amount = money(amount)
    if amount <= 0 then return false, "Podaj poprawna kwote." end
    if getPlayerMoney(player) < amount then return false, "Nie masz tyle gotowki przy sobie." end

    takePlayerMoney(player, amount)
    balances[player] = money((balances[player] or 0) + amount)
    saveMoney(player)
    record(player, "deposit", amount, title or "Wplata gotowki")
    sync(player)
    return true, "Wplacono $" .. tostring(amount) .. "."
end

function Bank.withdraw(player, amount, title)
    if not isElement(player) then return false, "Gracz offline." end
    amount = money(amount)
    if amount <= 0 then return false, "Podaj poprawna kwote." end
    if Bank.getBalance(player) < amount then return false, "Na koncie nie ma tyle srodkow." end

    balances[player] = money((balances[player] or 0) - amount)
    givePlayerMoney(player, amount)
    saveMoney(player)
    record(player, "withdraw", -amount, title or "Wyplata gotowki")
    sync(player)
    return true, "Wyplacono $" .. tostring(amount) .. "."
end

local function findPlayer(query)
    query = tostring(query or "")
    if #query == 0 then return nil end

    local numeric = tonumber(query)
    for _, player in ipairs(getElementsByType("player")) do
        if numeric and getCharacterId(player) == numeric then return player end
    end

    local lowered = HRP.Utils.lower(query)
    for _, player in ipairs(getElementsByType("player")) do
        if HRP.Utils.lower(HRP.Utils.safePlayerName(player)):find(lowered, 1, true) then
            return player
        end
    end

    return nil
end

function Bank.transfer(player, target, amount, title)
    if not isElement(player) then return false, "Gracz offline." end
    if not isElement(target) then return false, "Nie znaleziono odbiorcy." end
    if player == target then return false, "Nie mozesz przelac samemu sobie." end

    amount = money(amount)
    local cfg = HRP.Config.bank or {}
    if amount <= 0 then return false, "Podaj poprawna kwote." end
    if amount > (cfg.maxTransfer or 250000) then return false, "Kwota przekracza limit przelewu." end

    local tax = math.floor(amount * ((cfg.transferTaxPercent or 0) / 100))
    local total = amount + tax
    if Bank.getBalance(player) < total then
        return false, "Brakuje srodkow. Przelew + oplata: $" .. tostring(total) .. "."
    end

    balances[player] = money((balances[player] or 0) - total)
    balances[target] = money((balances[target] or 0) + amount)

    saveMoney(player)
    saveMoney(target)
    record(player, "transfer_out", -amount, title or ("Przelew do " .. getPlayerLabel(target)), getCharacterId(target))
    if tax > 0 then record(player, "transfer_tax", -tax, "Oplata za przelew", getCharacterId(target)) end
    record(target, "transfer_in", amount, title or ("Przelew od " .. getPlayerLabel(player)), getCharacterId(player))

    sync(player)
    sync(target)
    notify(target, "Otrzymano przelew $" .. tostring(amount) .. " od " .. getPlayerLabel(player) .. ".")
    return true, "Wyslano $" .. tostring(amount) .. " do " .. getPlayerLabel(target) .. (tax > 0 and (". Oplata: $" .. tostring(tax) .. ".") or ".")
end

function Bank.setBalance(player, value, title)
    if not isElement(player) then return false end
    balances[player] = money(value)
    saveMoney(player)
    record(player, "set_balance", 0, title or "Korekta salda")
    sync(player)
    return true
end

function Bank.getRecentTransactions(player, limit, callback)
    if not isElement(player) then
        if callback then callback({}) end
        return false
    end

    local characterId = getCharacterId(player)
    if not characterId then
        if callback then callback({}) end
        return false
    end

    limit = math.max(1, math.min(tonumber(limit) or 10, 50))
    return HRP.DB.query([[SELECT id, type, amount, balance_after, title, target_character_id, meta_json, created_at
        FROM bank_transactions
        WHERE character_id = ?
        ORDER BY created_at DESC, id DESC
        LIMIT ?]], { characterId, limit }, function(rows)
        if callback then callback(rows or {}) end
    end)
end

local function attachPlayer(player, character)
    if not isElement(player) then return end
    character = type(character) == "table" and character or {}

    setElementData(player, "hrp:character:id", tonumber(character.id), false)
    setElementData(player, "hrp:account:id", tonumber(character.accountId), false)
    balances[player] = money(character.bank or (HRP.Config.bank and HRP.Config.bank.startingBalance) or 0)
    setPlayerMoney(player, money(character.cash or getPlayerMoney(player)))
    sync(player)
end

local function detachPlayer(player)
    if not isElement(player) then return end
    saveMoney(player)
    balances[player] = nil
    setElementData(player, "hrp:bank", false, false)
end

local function handleBalanceCommand(player)
    notify(player, "Gotowka: $" .. tostring(Bank.getCash(player)) .. " | Konto: $" .. tostring(Bank.getBalance(player)) .. ".")
end

local function handleDepositCommand(player, _, amount)
    local ok, message = Bank.deposit(player, amount, "Komenda /wplac")
    notify(player, message, ok and 80 or 255, ok and 255 or 90, ok and 160 or 90)
end

local function handleWithdrawCommand(player, _, amount)
    local ok, message = Bank.withdraw(player, amount, "Komenda /wyplac")
    notify(player, message, ok and 80 or 255, ok and 255 or 90, ok and 160 or 90)
end

local function handleTransferCommand(player, _, targetQuery, amount, ...)
    local target = findPlayer(targetQuery)
    local title = table.concat({ ... }, " ")
    local ok, message = Bank.transfer(player, target, amount, #title > 0 and title or nil)
    notify(player, message, ok and 80 or 255, ok and 255 or 90, ok and 160 or 90)
end

local module = {}
function module.onStart()
    local commands = (HRP.Config.bank and HRP.Config.bank.commands) or {}

    addEventHandler("HeavyRPG:Character:onPlayerReady", resourceRoot, attachPlayer)
    addEventHandler("onPlayerQuit", root, function() detachPlayer(source) end)

    addCommandHandler(commands.balance or "bank", handleBalanceCommand)
    addCommandHandler(commands.deposit or "wplac", handleDepositCommand)
    addCommandHandler(commands.withdraw or "wyplac", handleWithdrawCommand)
    addCommandHandler(commands.transfer or "przelew", handleTransferCommand)

    HRP.Logger.info("bank", "System bankowy gotowy: saldo, gotowka, historia, przelewy.")
end

addEventHandler("onResourceStop", resourceRoot, function()
    for player in pairs(balances) do
        saveMoney(player)
    end
end)

function getPlayerBankBalance(player)
    return Bank.getBalance(player)
end

function depositPlayerBankMoney(player, amount, title)
    return Bank.deposit(player, amount, title)
end

function withdrawPlayerBankMoney(player, amount, title)
    return Bank.withdraw(player, amount, title)
end

function transferPlayerBankMoney(player, target, amount, title)
    return Bank.transfer(player, target, amount, title)
end

function getPlayerBankTransactions(player, limit, callback)
    return Bank.getRecentTransactions(player, limit, callback)
end

HRP.Modules.register("bank", module)
