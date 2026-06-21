HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Admin = HRP.Admin or {}
local Admin = HRP.Admin

local DEVELOPER_PASSWORD = "mtadevelop1"
local LEVELS = {
    [0] = "Gracz",
    [1] = "Support",
    [2] = "Moderator",
    [3] = "Administrator",
    [4] = "Head Admin",
    [100] = "Developer"
}

local ACTION_LEVELS = {
    heal = 1,
    setHealth = 1,
    goto = 1,
    armor = 2,
    setArmor = 2,
    freeze = 2,
    bring = 2,
    slap = 2,
    fixVehicle = 2,
    giveCash = 3,
    takeCash = 3,
    kick = 3,
    announce = 3,
    setDimension = 3,
    setInterior = 3,
    setAdmin = 100
}

local function now() return HRP.Utils and HRP.Utils.now and HRP.Utils.now() or getRealTime().timestamp end
local function notify(player, message, r, g, b) if isElement(player) then outputChatBox("[APANEL] " .. tostring(message), player, r or 210, g or 198, b or 164) end end
local function accountId(player) return (HRP.Auth and HRP.Auth.Session and HRP.Auth.Session.getAccountId(player)) or tonumber(getElementData(player, "HRP:account:id")) or tonumber(getElementData(player, "hrp:account:id")) end
local function characterId(player) return tonumber(getElementData(player, "hrp:character:id")) end
local function characterName(player) return tostring(getElementData(player, "hrp:character:name") or getPlayerName(player) or "-") end
local function clampInt(value, minValue, maxValue) value = math.floor(tonumber(value) or minValue) if value < minValue then return minValue end if value > maxValue then return maxValue end return value end
local function encode(data) return type(data) == "table" and (toJSON(data, true) or "{}") or "{}" end

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
    and HRP.DB.exec([[CREATE INDEX IF NOT EXISTS idx_admin_members_character ON admin_members(character_id)]], {})
    and HRP.DB.exec([[CREATE TABLE IF NOT EXISTS admin_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER,
        character_id INTEGER,
        admin_name TEXT NOT NULL DEFAULT '',
        action TEXT NOT NULL,
        target TEXT NOT NULL DEFAULT '',
        detail_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL
    )]], {})
    and HRP.DB.exec([[CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON admin_audit(created_at)]], {})
end

local function roleName(level)
    level = tonumber(level) or 0
    return LEVELS[level] or (level >= 100 and "Developer" or "Admin")
end

local function setCachedLevel(player, level, role)
    level = tonumber(level) or 0
    setElementData(player, "hrp:admin:level", level, false)
    setElementData(player, "hrp:admin:role", role or roleName(level), false)
end

function Admin.getLevel(player)
    if not isElement(player) then return 0 end
    return tonumber(getElementData(player, "hrp:admin:level")) or 0
end

function Admin.has(player, required)
    return Admin.getLevel(player) >= (tonumber(required) or 1)
end

local function audit(player, action, target, detail)
    if not HRP.DB or not HRP.DB.exec then return end
    HRP.DB.exec([[INSERT INTO admin_audit(account_id, character_id, admin_name, action, target, detail_json, created_at)
        VALUES(?, ?, ?, ?, ?, ?, ?)]], {
            accountId(player), characterId(player), characterName(player), tostring(action), tostring(target or ""), encode(detail or {}), now()
        })
end

local function refreshPlayerLevel(player)
    if not isElement(player) then return end
    local aid = accountId(player)
    if not aid then setCachedLevel(player, 0, "Gracz") return end

    HRP.DB.query([[SELECT a.admin_level, m.level AS member_level, m.role
        FROM accounts a
        LEFT JOIN admin_members m ON m.account_id = a.id
        WHERE a.id = ? LIMIT 1]], { aid }, function(rows)
        if not isElement(player) then return end
        local row = rows and rows[1]
        local level = math.max(tonumber(row and row.admin_level) or 0, tonumber(row and row.member_level) or 0)
        setCachedLevel(player, level, (row and row.role and row.role ~= "") and row.role or roleName(level))
    end)
end

local function findPlayerBySerial(serial)
    serial = tostring(serial or "")
    for _, player in ipairs(getElementsByType("player")) do if tostring(getPlayerSerial(player)) == serial then return player end end
    return nil
end

local function boolText(value)
    return value and "tak" or "nie"
end

local function onlinePlayers()
    local out = {}
    for _, player in ipairs(getElementsByType("player")) do
        local x, y, z = getElementPosition(player)
        local vehicle = getPedOccupiedVehicle(player)
        out[#out + 1] = {
            serial = getPlayerSerial(player),
            name = getPlayerName(player),
            accountId = accountId(player),
            characterId = characterId(player),
            character = characterName(player),
            adminLevel = Admin.getLevel(player),
            adminRole = tostring(getElementData(player, "hrp:admin:role") or roleName(Admin.getLevel(player))),
            health = math.floor(getElementHealth(player) or 0),
            armor = math.floor(getPedArmor(player) or 0),
            skin = getElementModel(player),
            money = getPlayerMoney(player) or 0,
            ping = getPlayerPing(player) or 0,
            dimension = getElementDimension(player) or 0,
            interior = getElementInterior(player) or 0,
            frozen = isElementFrozen(player),
            vehicle = vehicle and getVehicleName(vehicle) or false,
            position = { x = math.floor(x * 100) / 100, y = math.floor(y * 100) / 100, z = math.floor(z * 100) / 100 }
        }
    end
    return out
end

local function sendData(player)
    if not Admin.has(player, 1) then return end
    local payload = {
        self = { level = Admin.getLevel(player), role = tostring(getElementData(player, "hrp:admin:role") or roleName(Admin.getLevel(player))), name = characterName(player) },
        levels = LEVELS,
        players = onlinePlayers(),
        stats = { online = #getElementsByType("player"), accounts = 0, characters = 0, notes = 0, staff = 0 },
        audit = {}
    }

    HRP.DB.query([[SELECT COUNT(*) AS c FROM accounts]], {}, function(rows)
        payload.stats.accounts = tonumber(rows and rows[1] and rows[1].c) or 0
        HRP.DB.query([[SELECT COUNT(*) AS c FROM characters]], {}, function(rows2)
            payload.stats.characters = tonumber(rows2 and rows2[1] and rows2[1].c) or 0
            HRP.DB.query([[SELECT COUNT(*) AS c FROM admin_members WHERE level > 0]], {}, function(rows3)
                payload.stats.staff = tonumber(rows3 and rows3[1] and rows3[1].c) or 0
                HRP.DB.query([[SELECT COUNT(*) AS c FROM world_placed_notes]], {}, function(rows4)
                    payload.stats.notes = tonumber(rows4 and rows4[1] and rows4[1].c) or 0
                    HRP.DB.query([[SELECT * FROM admin_audit ORDER BY created_at DESC LIMIT 40]], {}, function(auditRows)
                        payload.audit = type(auditRows) == "table" and auditRows or {}
                        if isElement(player) then triggerClientEvent(player, "HeavyRPG:Admin:data", resourceRoot, payload) end
                    end)
                end)
            end)
        end)
    end)
end

local function openPanel(player)
    if not Admin.has(player, 1) then notify(player, "Brak uprawnien do panelu.", 230, 90, 80) return end
    triggerClientEvent(player, "HeavyRPG:Admin:open", resourceRoot, { level = Admin.getLevel(player), role = getElementData(player, "hrp:admin:role") or roleName(Admin.getLevel(player)) })
    sendData(player)
end

local function bootstrapDeveloper(player, password)
    if tostring(password or "") ~= DEVELOPER_PASSWORD then notify(player, "Niepoprawne haslo RCON bootstrap.", 230, 90, 80) return end
    local aid = accountId(player)
    if not aid then notify(player, "Najpierw zaloguj sie na konto.", 230, 90, 80) return end
    local cid = characterId(player)
    local ts = now()

    local ok = HRP.DB.exec([[UPDATE accounts SET admin_level = 100, updated_at = ? WHERE id = ?]], { ts, aid })
        and HRP.DB.exec([[INSERT OR REPLACE INTO admin_members(account_id, character_id, level, role, notes, added_by_account_id, created_at, updated_at)
            VALUES(?, ?, 100, 'Developer', 'Bootstrap przez /rcon login', ?, ?, ?)]], { aid, cid, aid, ts, ts })

    if not ok then notify(player, "Nie udalo sie nadac rangi developer.", 230, 90, 80) return end
    setCachedLevel(player, 100, "Developer")
    audit(player, "bootstrap_developer", getPlayerSerial(player), { command = "/rcon login" })
    notify(player, "Nadano najwyzszy poziom admina: Developer.", 140, 220, 150)
end

local function performAction(player, action, data)
    if not Admin.has(player, 1) then return false, "Brak uprawnien." end
    data = type(data) == "table" and data or {}
    action = tostring(action or "")
    local required = ACTION_LEVELS[action] or 100
    if not Admin.has(player, required) then return false, "Za niski poziom admina." end

    local target = findPlayerBySerial(data.serial)
    if action ~= "announce" and not target then return false, "Gracz offline albo nie istnieje." end

    if action == "heal" then
        setElementHealth(target, 100)
    elseif action == "setHealth" then
        setElementHealth(target, clampInt(data.amount, 1, 100))
    elseif action == "armor" then
        setPedArmor(target, 100)
    elseif action == "setArmor" then
        setPedArmor(target, clampInt(data.amount, 0, 100))
    elseif action == "freeze" then
        setElementFrozen(target, not isElementFrozen(target))
    elseif action == "goto" then
        local x, y, z = getElementPosition(target)
        setElementInterior(player, getElementInterior(target))
        setElementDimension(player, getElementDimension(target))
        setElementPosition(player, x + 1.2, y, z)
    elseif action == "bring" then
        local x, y, z = getElementPosition(player)
        setElementInterior(target, getElementInterior(player))
        setElementDimension(target, getElementDimension(player))
        setElementPosition(target, x + 1.2, y, z)
    elseif action == "slap" then
        local hp = math.max(1, (getElementHealth(target) or 100) - clampInt(data.amount, 1, 95))
        setElementHealth(target, hp)
        setElementVelocity(target, 0, 0, 0.22)
    elseif action == "fixVehicle" then
        local vehicle = getPedOccupiedVehicle(target)
        if not vehicle then return false, "Gracz nie siedzi w pojezdzie." end
        fixVehicle(vehicle)
    elseif action == "giveCash" then
        givePlayerMoney(target, clampInt(data.amount, 1, 1000000))
    elseif action == "takeCash" then
        takePlayerMoney(target, clampInt(data.amount, 1, 1000000))
    elseif action == "kick" then
        kickPlayer(target, player, tostring(data.reason or "Decyzja administracji."))
    elseif action == "announce" then
        local message = tostring(data.message or "")
        if #message < 3 then return false, "Wpisz tresc ogloszenia." end
        outputChatBox("[ADMIN] " .. message, root, 230, 210, 150)
    elseif action == "setDimension" then
        setElementDimension(target, clampInt(data.amount, 0, 65535))
    elseif action == "setInterior" then
        setElementInterior(target, clampInt(data.amount, 0, 255))
    elseif action == "setAdmin" then
        local level = clampInt(data.level, 0, 100)
        local aid = accountId(target)
        if not aid then return false, "Gracz nie jest zalogowany." end
        local cid = characterId(target)
        local ts = now()
        if not HRP.DB.exec([[UPDATE accounts SET admin_level = ?, updated_at = ? WHERE id = ?]], { level, ts, aid }) then return false, "Nie udalo sie zapisac rangi." end
        HRP.DB.exec([[INSERT OR REPLACE INTO admin_members(account_id, character_id, level, role, notes, added_by_account_id, created_at, updated_at)
            VALUES(?, ?, ?, ?, '', ?, ?, ?)]], { aid, cid, level, roleName(level), accountId(player), ts, ts })
        setCachedLevel(target, level, roleName(level))
    else
        return false, "Nieznana akcja."
    end

    audit(player, action, target and getPlayerSerial(target) or tostring(data.serial or "global"), data)
    if target and target ~= player then notify(target, "Administrator wykonal akcje: " .. action .. ".", 210, 198, 164) end
    return true, "Wykonano akcje: " .. action .. "."
end

addCommandHandler("apanel", function(player) openPanel(player) end)
addCommandHandler("rcon", function(player, _, subcommand, password)
    if tostring(subcommand or ""):lower() == "login" then bootstrapDeveloper(player, password) return end
    notify(player, "Uzycie: /rcon login <haslo>", 230, 190, 90)
end)

addEvent("HeavyRPG:Admin:request", true)
addEventHandler("HeavyRPG:Admin:request", resourceRoot, function() sendData(client) end)

addEvent("HeavyRPG:Admin:action", true)
addEventHandler("HeavyRPG:Admin:action", resourceRoot, function(action, payload)
    local ok, message = performAction(client, action, payload)
    notify(client, message, ok and 140 or 230, ok and 220 or 90, ok and 150 or 80)
    sendData(client)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    ensureSchema()
    setTimer(function()
        for _, player in ipairs(getElementsByType("player")) do refreshPlayerLevel(player) end
    end, 1000, 1)
end)

addEventHandler("HeavyRPG:Auth:success", resourceRoot, function()
    refreshPlayerLevel(client or source)
end)

addEventHandler("onPlayerJoin", root, function() setCachedLevel(source, 0, "Gracz") end)

addEventHandler("onPlayerQuit", root, function()
    if Admin.getLevel(source) > 0 then audit(source, "quit", getPlayerSerial(source), {}) end
end)
