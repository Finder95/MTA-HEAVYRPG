HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local MAX_RETRIES = 15
local RETRY_MS = 500

local function exec(sql)
    return HRP.DB and HRP.DB.exec and HRP.DB.exec(sql, {}) == true
end

local function ensureAdminDependencies()
    if not HRP.DB or not HRP.DB.connection then return false end

    local ok = exec([[CREATE TABLE IF NOT EXISTS world_placed_notes (
        id TEXT PRIMARY KEY,
        place_type TEXT NOT NULL DEFAULT 'world',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        pos_x REAL NOT NULL DEFAULT 0,
        pos_y REAL NOT NULL DEFAULT 0,
        pos_z REAL NOT NULL DEFAULT 0,
        interior INTEGER NOT NULL DEFAULT 0,
        dimension INTEGER NOT NULL DEFAULT 0,
        placed_by_character_id INTEGER,
        placed_by_account_id INTEGER,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
    )]])
    and exec([[CREATE TABLE IF NOT EXISTS admin_members (
        account_id INTEGER NOT NULL,
        character_id INTEGER,
        level INTEGER NOT NULL DEFAULT 0,
        role TEXT NOT NULL DEFAULT 'Admin',
        notes TEXT NOT NULL DEFAULT '',
        added_by_account_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(account_id)
    )]])
    and exec([[CREATE INDEX IF NOT EXISTS idx_admin_members_character ON admin_members(character_id)]])
    and exec([[CREATE TABLE IF NOT EXISTS admin_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER,
        character_id INTEGER,
        admin_name TEXT NOT NULL DEFAULT '',
        action TEXT NOT NULL,
        target TEXT NOT NULL DEFAULT '',
        detail_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL
    )]])
    and exec([[CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON admin_audit(created_at)]])

    return ok == true
end

local function ensureWithRetry(attempt)
    attempt = tonumber(attempt) or 1
    if ensureAdminDependencies() then return end
    if attempt >= MAX_RETRIES then
        outputDebugString("[HeavyRPG:Admin] Nie udalo sie przygotowac tabel admina po " .. tostring(MAX_RETRIES) .. " probach.", 1)
        return
    end
    setTimer(function() ensureWithRetry(attempt + 1) end, RETRY_MS, 1)
end

addEventHandler("onResourceStart", resourceRoot, function()
    setTimer(function() ensureWithRetry(1) end, 250, 1)
end)

addEvent("HeavyRPG:Admin:ensureDependencies", true)
addEventHandler("HeavyRPG:Admin:ensureDependencies", resourceRoot, function() ensureWithRetry(1) end)