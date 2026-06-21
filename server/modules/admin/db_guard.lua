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
    and exec([[CREATE INDEX IF NOT EXISTS idx_world_placed_notes_place ON world_placed_notes(dimension, interior)]])
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
    and exec([[CREATE TABLE IF NOT EXISTS admin_punishments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_account_id INTEGER,
        target_character_id INTEGER,
        target_serial TEXT NOT NULL DEFAULT '',
        target_name TEXT NOT NULL DEFAULT '',
        admin_account_id INTEGER,
        admin_character_id INTEGER,
        admin_name TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        duration INTEGER,
        expires_at INTEGER,
        active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )]])
    and exec([[CREATE INDEX IF NOT EXISTS idx_admin_punishments_target ON admin_punishments(target_serial, active, type, expires_at)]])
    and exec([[CREATE INDEX IF NOT EXISTS idx_admin_punishments_created ON admin_punishments(created_at)]])
    and exec([[CREATE INDEX IF NOT EXISTS idx_admin_punishments_character ON admin_punishments(target_character_id, active)]])
    and exec([[CREATE TABLE IF NOT EXISTS admin_player_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_account_id INTEGER,
        target_character_id INTEGER,
        target_serial TEXT NOT NULL DEFAULT '',
        target_name TEXT NOT NULL DEFAULT '',
        admin_account_id INTEGER,
        admin_character_id INTEGER,
        admin_name TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        priority INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
    )]])
    and exec([[CREATE INDEX IF NOT EXISTS idx_admin_player_notes_target ON admin_player_notes(target_serial, target_character_id)]])
    and exec([[CREATE TABLE IF NOT EXISTS admin_watchlist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_account_id INTEGER,
        target_character_id INTEGER,
        target_serial TEXT NOT NULL DEFAULT '',
        target_name TEXT NOT NULL DEFAULT '',
        reason TEXT NOT NULL DEFAULT '',
        priority INTEGER NOT NULL DEFAULT 1,
        added_by_account_id INTEGER,
        added_by_character_id INTEGER,
        added_by_name TEXT NOT NULL DEFAULT '',
        active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )]])
    and exec([[CREATE INDEX IF NOT EXISTS idx_admin_watchlist_target ON admin_watchlist(target_serial, active)]])

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