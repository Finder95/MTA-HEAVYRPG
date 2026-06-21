HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local Advanced = {}
local vanished = {}
local godmode = {}
local jailed = {}

local ACTION_LEVELS = {
    spectate = 1,
    stopSpectate = 1,
    staffDuty = 1,
    revive = 2,
    addStaffNote = 2,
    addWatch = 2,
    removeWatch = 2,
    jail = 3,
    unjail = 3,
    vanish = 3,
    godmode = 3,
    setGravity = 4,
    setGameSpeed = 4,
    clearStaffNotes = 4
}

local function now()
    return HRP.Utils and HRP.Utils.now and HRP.Utils.now() or getRealTime().timestamp
end

local function notify(player, message, r, g, b)
    if isElement(player) then outputChatBox("[APANEL] " .. tostring(message), player, r or 210, g or 198, b or 164) end
end

local function accountId(player)
    return (HRP.Auth and HRP.Auth.Session and HRP.Auth.Session.getAccountId(player)) or tonumber(getElementData(player, "hrp:account:id"))
end

local function characterId(player)
    return tonumber(getElementData(player, "hrp:character:id"))
end

local function characterName(player)
    return tostring(getElementData(player, "hrp:character:name") or getPlayerName(player) or "-")
end

local function adminLevel(player)
    return HRP.Admin and HRP.Admin.getLevel and HRP.Admin.getLevel(player) or tonumber(getElementData(player, "hrp:admin:level")) or 0
end

local function has(player, level)
    return adminLevel(player) >= (tonumber(level) or 1)
end

local function clampInt(value, minValue, maxValue)
    value = math.floor(tonumber(value) or minValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function trim(value, maxLen)
    value = tostring(value or "")
    if HRP.Utils and HRP.Utils.trim then value = HRP.Utils.trim(value) end
    if maxLen and #value > maxLen then value = value:sub(1, maxLen) end
    return value
end

local function encode(data)
    return type(data) == "table" and (toJSON(data, true) or "{}") or "{}"
end

local function audit(player, action, target, detail)
    if not HRP.DB or not HRP.DB.exec then return end
    HRP.DB.exec([[INSERT INTO admin_audit(account_id, character_id, admin_name, action, target, detail_json, created_at)
        VALUES(?, ?, ?, ?, ?, ?, ?)]], { accountId(player), characterId(player), characterName(player), tostring(action), tostring(target or ""), encode(detail or {}), now() })
end

local function findPlayerBySerial(serial)
    serial = tostring(serial or "")
    for _, player in ipairs(getElementsByType("player")) do
        if tostring(getPlayerSerial(player)) == serial then return player end
    end
    return nil
end

local function ensureSchema()
    if not HRP.DB or not HRP.DB.exec then return false end
    return HRP.DB.exec([[CREATE TABLE IF NOT EXISTS admin_player_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_serial TEXT NOT NULL DEFAULT '',
        target_name TEXT NOT NULL DEFAULT '',
        target_account_id INTEGER,
        target_character_id INTEGER,
        admin_account_id INTEGER,
        admin_character_id INTEGER,
        admin_name TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
    )]], {})
    and HRP.DB.exec([[CREATE INDEX IF NOT EXISTS idx_admin_player_notes_target ON admin_player_notes(target_serial, created_at)]], {})
    and HRP.DB.exec([[CREATE TABLE IF NOT EXISTS admin_watchlist (
        target_serial TEXT PRIMARY KEY,
        target_name TEXT NOT NULL DEFAULT '',
        target_account_id INTEGER,
        target_character_id INTEGER,
        reason TEXT NOT NULL DEFAULT '',
        priority INTEGER NOT NULL DEFAULT 1,
        admin_account_id INTEGER,
        admin_name TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )]], {})
end

local function targetSnapshot(target)
    return {
        serial = getPlayerSerial(target),
        name = getPlayerName(target),
        character = characterName(target),
        accountId = accountId(target),
        characterId = characterId(target)
    }
end

local function sendAdvancedData(player)
    if not has(player, 1) then return end
    local payload = {
        notes = {},
        watchlist = {},
        flags = { vanished = vanished[player] == true, godmode = godmode[player] == true, jailed = jailed[player] == true },
        server = { gravity = getGravity(), gameSpeed = getGameSpeed(), fpsLimit = getFPSLimit and getFPSLimit() or 0 }
    }
    HRP.DB.query([[SELECT * FROM admin_player_notes ORDER BY created_at DESC LIMIT 60]], {}, function(notes)
        payload.notes = type(notes) == "table" and notes or {}
        HRP.DB.query([[SELECT * FROM admin_watchlist ORDER BY priority DESC, updated_at DESC LIMIT 60]], {}, function(watch)
            payload.watchlist = type(watch) == "table" and watch or {}
            if isElement(player) then triggerClientEvent(player, "HeavyRPG:Admin:advancedData", resourceRoot, payload) end
        end)
    end)
end

local function setVanish(player, state)
    vanished[player] = state == true
    setElementAlpha(player, vanished[player] and 0 or 255)
    setPlayerNametagShowing(player, not vanished[player])
    setElementData(player, "hrp:admin:vanish", vanished[player], false)
end

local function setGodmode(player, state)
    godmode[player] = state == true
    setElementData(player, "hrp:admin:godmode", godmode[player], false)
end

local function jailPlayer(target, minutes)
    local x, y, z = 264.4, 77.5, 1001.0
    jailed[target] = { untilTs = now() + minutes * 60, oldInterior = getElementInterior(target), oldDimension = getElementDimension(target) }
    setElementInterior(target, 6)
    setElementDimension(target, 65010)
    setElementPosition(target, x, y, z)
    setElementFrozen(target, true)
    setTimer(function(player)
        if isElement(player) and jailed[player] then
            setElementFrozen(player, false)
            jailed[player] = nil
            notify(player, "Kara jail dobiegla konca.", 140, 220, 150)
        end
    end, minutes * 60000, 1, target)
end

local function unjailPlayer(target)
    jailed[target] = nil
    setElementFrozen(target, false)
    setElementInterior(target, 0)
    setElementDimension(target, 0)
    setElementPosition(target, 1481.08, -1749.32, 15.45)
end

local function perform(player, action, data)
    if not has(player, 1) then return false, "Brak uprawnien." end
    data = type(data) == "table" and data or {}
    action = tostring(action or "")
    local required = ACTION_LEVELS[action] or 100
    if not has(player, required) then return false, "Za niski poziom admina." end

    local target = findPlayerBySerial(data.serial)
    if action ~= "stopSpectate" and action ~= "staffDuty" and action ~= "vanish" and action ~= "godmode" and action ~= "setGravity" and action ~= "setGameSpeed" and action ~= "clearStaffNotes" and not target then
        return false, "Gracz offline albo nie istnieje."
    end

    if action == "spectate" then
        triggerClientEvent(player, "HeavyRPG:Admin:spectate", resourceRoot, target)
    elseif action == "stopSpectate" then
        triggerClientEvent(player, "HeavyRPG:Admin:spectate", resourceRoot, false)
    elseif action == "staffDuty" then
        local state = not (getElementData(player, "hrp:admin:duty") == true)
        setElementData(player, "hrp:admin:duty", state, false)
        notify(player, state and "Wszedles na duty administracyjne." or "Zszedles z duty administracyjnego.", 190, 210, 160)
    elseif action == "vanish" then
        setVanish(player, not vanished[player])
    elseif action == "godmode" then
        setGodmode(player, not godmode[player])
    elseif action == "revive" then
        local x, y, z = getElementPosition(target)
        spawnPlayer(target, x, y, z, getPedRotation(target), getElementModel(target), getElementInterior(target), getElementDimension(target))
        setElementHealth(target, 100)
        setCameraTarget(target, target)
    elseif action == "jail" then
        local minutes = clampInt(data.minutes, 1, 1440)
        jailPlayer(target, minutes)
        notify(target, "Trafiles do admin jail na " .. tostring(minutes) .. " min. Powod: " .. trim(data.reason, 120), 230, 190, 90)
    elseif action == "unjail" then
        unjailPlayer(target)
    elseif action == "addStaffNote" then
        local note = trim(data.note, 500)
        if #note < 3 then return false, "Wpisz tresc notatki staff." end
        local snap = targetSnapshot(target)
        HRP.DB.exec([[INSERT INTO admin_player_notes(target_serial, target_name, target_account_id, target_character_id, admin_account_id, admin_character_id, admin_name, note, created_at)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)]], { snap.serial, snap.character or snap.name, snap.accountId, snap.characterId, accountId(player), characterId(player), characterName(player), note, now() })
    elseif action == "clearStaffNotes" then
        if not target then return false, "Wybierz gracza, ktoremu czyscisz notatki." end
        HRP.DB.exec([[DELETE FROM admin_player_notes WHERE target_serial = ?]], { getPlayerSerial(target) })
    elseif action == "addWatch" then
        local reason = trim(data.reason, 240)
        if #reason < 3 then return false, "Wpisz powod watchlisty." end
        local snap = targetSnapshot(target)
        HRP.DB.exec([[INSERT OR REPLACE INTO admin_watchlist(target_serial, target_name, target_account_id, target_character_id, reason, priority, admin_account_id, admin_name, created_at, updated_at)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, COALESCE((SELECT created_at FROM admin_watchlist WHERE target_serial = ?), ?), ?)]], {
                snap.serial, snap.character or snap.name, snap.accountId, snap.characterId, reason, clampInt(data.priority, 1, 5), accountId(player), characterName(player), snap.serial, now(), now()
            })
    elseif action == "removeWatch" then
        HRP.DB.exec([[DELETE FROM admin_watchlist WHERE target_serial = ?]], { getPlayerSerial(target) })
    elseif action == "setGravity" then
        setGravity(math.max(0.001, math.min(0.1, tonumber(data.value) or 0.008)))
    elseif action == "setGameSpeed" then
        setGameSpeed(math.max(0.1, math.min(10, tonumber(data.value) or 1)))
    else
        return false, "Nieznana akcja advanced."
    end

    audit(player, "advanced:" .. action, target and getPlayerSerial(target) or "global", data)
    return true, "Wykonano advanced: " .. action .. "."
end

addEvent("HeavyRPG:Admin:advancedRequest", true)
addEventHandler("HeavyRPG:Admin:advancedRequest", resourceRoot, function()
    sendAdvancedData(client)
end)

addEvent("HeavyRPG:Admin:advanced", true)
addEventHandler("HeavyRPG:Admin:advanced", resourceRoot, function(action, payload)
    local ok, message = perform(client, action, payload)
    notify(client, message, ok and 140 or 230, ok and 220 or 90, ok and 150 or 80)
    sendAdvancedData(client)
end)

addEventHandler("HeavyRPG:Admin:request", resourceRoot, function()
    sendAdvancedData(client)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    ensureSchema()
end)

addEventHandler("onPlayerDamage", root, function()
    if godmode[source] then cancelEvent() end
end)

addEventHandler("onPlayerQuit", root, function()
    vanished[source] = nil
    godmode[source] = nil
    jailed[source] = nil
end)

_G.HRPAdminAdvanced = Advanced
