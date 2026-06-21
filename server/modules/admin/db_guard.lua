HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local function exec(sql)
    return HRP.DB and HRP.DB.exec and HRP.DB.exec(sql, {}) == true
end

local function ensureAdminDependencies()
    exec([[CREATE TABLE IF NOT EXISTS world_placed_notes (
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
end

addEventHandler("onResourceStart", resourceRoot, function()
    setTimer(ensureAdminDependencies, 100, 1)
end)

addEvent("HeavyRPG:Admin:ensureDependencies", true)
addEventHandler("HeavyRPG:Admin:ensureDependencies", resourceRoot, ensureAdminDependencies)