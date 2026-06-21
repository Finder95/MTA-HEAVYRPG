HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local LEVELS = {
    [0] = "Gracz",
    [1] = "Support",
    [2] = "Moderator",
    [3] = "Administrator",
    [4] = "Head Admin",
    [100] = "Developer"
}

local function now()
    return HRP.Utils and HRP.Utils.now and HRP.Utils.now() or getRealTime().timestamp
end

local function roleName(level)
    level = tonumber(level) or 0
    return LEVELS[level] or (level >= 100 and "Developer" or "Admin")
end

local function clampInt(value, minValue, maxValue)
    value = math.floor(tonumber(value) or minValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function accountId(player)
    return (HRP.Auth and HRP.Auth.Session and HRP.Auth.Session.getAccountId and HRP.Auth.Session.getAccountId(player))
        or tonumber(getElementData(player, "HRP:account:id"))
        or tonumber(getElementData(player, "hrp:account:id"))
end

local function characterId(player)
    return tonumber(getElementData(player, "hrp:character:id"))
end

local function notify(player, message, r, g, b)
    if isElement(player) then outputChatBox("[APANEL] " .. tostring(message), player, r or 210, g or 198, b or 164) end
end

local function ensureSchema()
    if not HRP.DB or not HRP.DB.exec then return false end
    return HRP.DB.exec([[CREATE TABLE IF NOT EXISTS admin_members (
        account_id INTEGER NOT NULL,
        character_id INTEGER,
        level INTEGER NOT NULL DEFAULT 0,
        role TEXT NOT NULL DEFAULT 'Admin',
        notes TEXT NOT NULL DEFAULT '',
        added_by_account_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(account_id)
    )]], {})
end

local function syncSessionAccount(player, level)
    local session = HRP.Auth and HRP.Auth.Session
    local state = session and session.players and session.players[player]
    if type(state) == "table" and type(state.account) == "table" then
        state.account.admin_level = tonumber(level) or 0
    end
end

local function setCachedLevel(player, level, role)
    if not isElement(player) then return end
    level = tonumber(level) or 0
    setElementData(player, "hrp:admin:level", level, false)
    setElementData(player, "hrp:admin:role", role or roleName(level), false)
    syncSessionAccount(player, level)
end

local function refreshPlayerLevel(player)
    if not isElement(player) or not HRP.DB or not HRP.DB.query then return end
    local aid = accountId(player)
    if not aid then setCachedLevel(player, 0, "Gracz") return end
    ensureSchema()
    HRP.DB.query([[SELECT a.admin_level, m.level AS member_level, m.role FROM accounts a LEFT JOIN admin_members m ON m.account_id = a.id WHERE a.id = ? LIMIT 1]], { aid }, function(rows)
        if not isElement(player) then return end
        local row = rows and rows[1]
        local level = math.max(tonumber(row and row.admin_level) or 0, tonumber(row and row.member_level) or 0)
        setCachedLevel(player, level, (row and row.role and row.role ~= "") and row.role or roleName(level))
    end)
end

local function findPlayerBySerial(serial)
    serial = tostring(serial or "")
    for _, player in ipairs(getElementsByType("player")) do
        if tostring(getPlayerSerial(player)) == serial then return player end
    end
    return nil
end

local function saveAdminRank(target, level, admin)
    if not ensureSchema() then return false, "Brak tabeli adminow." end
    local aid = accountId(target)
    if not aid then return false, "Gracz nie jest zalogowany." end

    local cid = characterId(target)
    local ts = now()
    level = clampInt(level, 0, 100)

    if not HRP.DB.exec([[UPDATE accounts SET admin_level = ?, updated_at = ? WHERE id = ?]], { level, ts, aid }) then
        return false, "Nie udalo sie zapisac poziomu w koncie."
    end

    local ok
    if level > 0 then
        ok = HRP.DB.exec([[INSERT OR REPLACE INTO admin_members(account_id, character_id, level, role, notes, added_by_account_id, created_at, updated_at)
            VALUES(?, ?, ?, ?, COALESCE((SELECT notes FROM admin_members WHERE account_id = ?), ''), ?, COALESCE((SELECT created_at FROM admin_members WHERE account_id = ?), ?), ?)]], {
                aid, cid, level, roleName(level), aid, accountId(admin), aid, ts, ts
            })
    else
        ok = HRP.DB.exec([[DELETE FROM admin_members WHERE account_id = ?]], { aid })
    end

    if not ok then return false, "Nie udalo sie zapisac wpisu w admin_members." end
    setCachedLevel(target, level, roleName(level))
    setTimer(refreshPlayerLevel, 250, 1, target)
    return true
end

addEvent("HeavyRPG:Auth:onPlayerLoggedIn", false)
addEventHandler("HeavyRPG:Auth:onPlayerLoggedIn", resourceRoot, function(player)
    if isElement(player) then refreshPlayerLevel(player) end
end)

addEventHandler("HeavyRPG:Character:onPlayerReady", resourceRoot, function(player)
    if isElement(player) then refreshPlayerLevel(player) end
end)

addEventHandler("HeavyRPG:Admin:action", resourceRoot, function(action, payload)
    if tostring(action or "") ~= "setAdmin" then return end
    if not HRP.Admin or not HRP.Admin.has or not HRP.Admin.has(client, 100) then return end
    payload = type(payload) == "table" and payload or {}
    local target = findPlayerBySerial(payload.serial)
    if not target then return end
    local ok, message = saveAdminRank(target, payload.level, client)
    if not ok then notify(client, message or "Nie udalo sie utrwalic rangi.", 230, 90, 80) end
end, false, "low")

addEventHandler("onPlayerJoin", root, function()
    setCachedLevel(source, 0, "Gracz")
    setTimer(refreshPlayerLevel, 1500, 1, source)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    ensureSchema()
    setTimer(function()
        for _, player in ipairs(getElementsByType("player")) do
            refreshPlayerLevel(player)
        end
    end, 1500, 1)
end)
