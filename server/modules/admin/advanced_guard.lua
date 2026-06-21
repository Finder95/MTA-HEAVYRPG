HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local attempts = 0
local ready = false

local statements = {
    [[CREATE TABLE IF NOT EXISTS admin_player_notes (
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
    )]],
    [[CREATE INDEX IF NOT EXISTS idx_admin_player_notes_target ON admin_player_notes(target_serial, created_at)]],
    [[CREATE TABLE IF NOT EXISTS admin_watchlist (
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
    )]]
}

local function prepare()
    if ready then return true end
    if not HRP.DB or not HRP.DB.exec then return false end
    for _, sql in ipairs(statements) do
        if not HRP.DB.exec(sql, {}) then return false end
    end
    ready = true
    if HRP.Logger and HRP.Logger.info then HRP.Logger.info("admin", "Advanced admin SQL tables ready.") end
    return true
end

local function retry()
    if prepare() then return end
    attempts = attempts + 1
    if attempts < 20 then setTimer(retry, 750, 1) end
end

addEventHandler("onResourceStart", resourceRoot, function()
    setTimer(retry, 750, 1)
end)

_G.HRPAdminAdvancedPrepare = prepare
