HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Payday = HRP.Payday or {}
local Payday = HRP.Payday

local sessions = {}

local schema = {
    [[CREATE TABLE IF NOT EXISTS character_paydays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        periods INTEGER NOT NULL DEFAULT 1,
        playtime_after INTEGER NOT NULL,
        cash_after INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(character_id) REFERENCES characters(id) ON DELETE CASCADE
    )]],
    [[CREATE INDEX IF NOT EXISTS idx_character_paydays_character ON character_paydays(character_id, created_at)]],
    [[CREATE INDEX IF NOT EXISTS idx_character_paydays_account ON character_paydays(account_id, created_at)]]
}

local function cfg()
    return HRP.Config.payday or {}
end

local function money(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then return 0 end
    return value
end

local function seconds(value, fallback)
    value = math.floor(tonumber(value) or fallback or 0)
    if value < 1 then return 1 end
    return value
end

local function now()
    return HRP.Utils.now()
end

local function getCharacterId(player)
    return tonumber(getElementData(player, "hrp:character:id"))
end

local function getAccountId(player)
    return tonumber(getElementData(player, "hrp:account:id")) or (HRP.Auth and HRP.Auth.Session and HRP.Auth.Session.getAccountId(player))
end

local function intervalSeconds()
    return seconds(cfg().intervalMinutes, 30) * 60
end

local function paydayAmount()
    return money(cfg().amount or 500)
end

local function notify(player, message, r, g, b)
    if not isElement(player) then return end
    outputChatBox("[PAYDAY] " .. tostring(message), player, r or 205, g or 185, b or 125)
end

local function ensureSchema()
    for _, sql in ipairs(schema) do
        if not HRP.DB.exec(sql) then
            HRP.Logger.error("payday", "Nie udalo sie przygotowac tabeli payday: " .. tostring(sql))
            return false
        end
    end
    return true
end

local function saveSession(player)
    local session = sessions[player]
    if not session or not session.characterId then return false end

    return HRP.DB.exec([[UPDATE characters
        SET playtime = ?, cash = ?, updated_at = ?
        WHERE id = ?]], {
            math.floor(tonumber(session.playtime) or 0),
            money(getPlayerMoney(player)),
            now(),
            session.characterId
        })
end

local function recordPayday(player, session, amount, periods)
    return HRP.DB.exec([[INSERT INTO character_paydays
        (character_id, account_id, amount, periods, playtime_after, cash_after, created_at)
        VALUES(?, ?, ?, ?, ?, ?, ?)]], {
            session.characterId,
            session.accountId or getAccountId(player) or 0,
            amount,
            periods,
            math.floor(session.playtime or 0),
            money(getPlayerMoney(player)),
            now()
        })
end

local function syncSystems(player)
    if HRP.Bank and HRP.Bank.sync then HRP.Bank.sync(player) end
    if HRP.Inventory and HRP.Inventory.sync then HRP.Inventory.sync(player) end
end

local function tickPlayer(player, silent)
    if not isElement(player) then return false end
    local session = sessions[player]
    if not session then return false end

    local current = now()
    local elapsed = math.max(0, current - (session.lastSeen or current))
    if elapsed <= 0 then return true end

    local oldPlaytime = math.floor(session.playtime or 0)
    local newPlaytime = oldPlaytime + elapsed
    local interval = intervalSeconds()
    local oldPeriods = math.floor(oldPlaytime / interval)
    local newPeriods = math.floor(newPlaytime / interval)
    local duePeriods = math.max(0, newPeriods - oldPeriods)

    session.playtime = newPlaytime
    session.lastSeen = current
    setElementData(player, "hrp:character:playtime", newPlaytime, false)

    if duePeriods > 0 and paydayAmount() > 0 then
        local amount = paydayAmount() * duePeriods
        givePlayerMoney(player, amount)
        recordPayday(player, session, amount, duePeriods)
        if not silent then
            notify(player, "Otrzymales $" .. tostring(amount) .. " za aktywna gre. Gotowka trafila do kieszeni.", 120, 225, 145)
        end
    end

    saveSession(player)
    syncSystems(player)
    return true
end

function Payday.getPlaytime(player)
    local session = sessions[player]
    if session then return math.floor(session.playtime or 0) end
    return 0
end

function Payday.force(player, periods)
    if not isElement(player) then return false, "Gracz offline." end
    local session = sessions[player]
    if not session then return false, "Gracz nie ma aktywnej postaci." end

    periods = math.max(1, math.floor(tonumber(periods) or 1))
    local amount = paydayAmount() * periods
    givePlayerMoney(player, amount)
    recordPayday(player, session, amount, periods)
    saveSession(player)
    syncSystems(player)
    notify(player, "Administrator wyplacil payday: $" .. tostring(amount) .. ".", 120, 225, 145)
    return true, "Wyplacono payday $" .. tostring(amount) .. "."
end

local function attachPlayer(player, character)
    if not isElement(player) then return end
    character = type(character) == "table" and character or {}

    local characterId = tonumber(character.id) or getCharacterId(player)
    if not characterId then return end

    sessions[player] = {
        characterId = characterId,
        accountId = tonumber(character.accountId) or getAccountId(player) or 0,
        playtime = math.max(0, math.floor(tonumber(character.playtime) or 0)),
        lastSeen = now()
    }

    setElementData(player, "hrp:character:playtime", sessions[player].playtime, false)

    local tickMs = math.max(5000, seconds(cfg().tickSeconds, 60) * 1000)
    sessions[player].timer = setTimer(function(target)
        tickPlayer(target, false)
    end, tickMs, 0, player)
end

local function detachPlayer(player)
    local session = sessions[player]
    if not session then return end

    tickPlayer(player, true)
    if session.timer and isTimer(session.timer) then killTimer(session.timer) end
    sessions[player] = nil
    setElementData(player, "hrp:character:playtime", false, false)
end

local function getAdminLevel(player)
    local account = HRP.Auth and HRP.Auth.Session and HRP.Auth.Session.getAccount(player)
    return tonumber(account and account.adminLevel) or 0
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

local function handlePaydayCommand(player, _, targetQuery, periods)
    if getAdminLevel(player) <= 0 then
        notify(player, "Brak uprawnien.", 230, 90, 80)
        return
    end

    local target = findPlayer(targetQuery) or player
    local ok, message = Payday.force(target, periods or 1)
    notify(player, message, ok and 120 or 230, ok and 225 or 90, ok and 145 or 80)
end

local module = {}
function module.onStart()
    if not ensureSchema() then return end

    addEventHandler("HeavyRPG:Character:onPlayerReady", resourceRoot, attachPlayer)
    addEventHandler("onPlayerQuit", root, function() detachPlayer(source) end)
    addCommandHandler((cfg().commands and cfg().commands.force) or "payday", handlePaydayCommand)

    HRP.Logger.info("payday", "System payday gotowy: $" .. tostring(paydayAmount()) .. " co " .. tostring(cfg().intervalMinutes or 30) .. " minut gry.")
end

addEventHandler("onResourceStop", resourceRoot, function()
    for player in pairs(sessions) do
        detachPlayer(player)
    end
end)

function getPlayerCharacterPlaytime(player)
    return Payday.getPlaytime(player)
end

function forcePlayerPayday(player, periods)
    return Payday.force(player, periods)
end

HRP.Modules.register("payday", module)
