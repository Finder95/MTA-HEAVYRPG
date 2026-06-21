HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local PER_CHARACTER_LIMIT = 25
local SERVER_LIMIT = 500
local RETRY_DELAY_MS = 1000
local MAX_RETRIES = 15

local function log(level, message)
    if HRP.Logger and HRP.Logger[level] then
        HRP.Logger[level]("inventory", message)
    else
        outputDebugString("[inventory] " .. tostring(message))
    end
end

local function exec(sql, params)
    if not HRP.DB or not HRP.DB.exec then return false end
    return HRP.DB.exec(sql, params or {}) == true
end

local function ensurePlacedNotesSchema()
    if not exec([[CREATE TABLE IF NOT EXISTS world_placed_notes (
        id TEXT PRIMARY KEY,
        place_type TEXT NOT NULL DEFAULT 'world',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        pos_x REAL NOT NULL,
        pos_y REAL NOT NULL,
        pos_z REAL NOT NULL,
        interior INTEGER NOT NULL DEFAULT 0,
        dimension INTEGER NOT NULL DEFAULT 0,
        placed_by_character_id INTEGER,
        placed_by_account_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )]]) then return false end

    if not exec([[CREATE INDEX IF NOT EXISTS idx_world_placed_notes_place ON world_placed_notes(dimension, interior)]]) then return false end
    if not exec([[CREATE INDEX IF NOT EXISTS idx_world_placed_notes_character ON world_placed_notes(placed_by_character_id)]]) then return false end
    if not exec([[CREATE INDEX IF NOT EXISTS idx_world_placed_notes_created ON world_placed_notes(created_at)]]) then return false end

    exec([[DROP TRIGGER IF EXISTS trg_world_placed_notes_limit_total]])
    exec([[DROP TRIGGER IF EXISTS trg_world_placed_notes_limit_character]])

    if not exec([[CREATE TRIGGER IF NOT EXISTS trg_world_placed_notes_limit_total
        BEFORE INSERT ON world_placed_notes
        WHEN (SELECT COUNT(*) FROM world_placed_notes) >= ]] .. tostring(SERVER_LIMIT) .. [[
        BEGIN
            SELECT RAISE(ABORT, 'server placed note limit reached');
        END]]) then return false end

    if not exec([[CREATE TRIGGER IF NOT EXISTS trg_world_placed_notes_limit_character
        BEFORE INSERT ON world_placed_notes
        WHEN NEW.placed_by_character_id IS NOT NULL
            AND (SELECT COUNT(*) FROM world_placed_notes WHERE placed_by_character_id = NEW.placed_by_character_id) >= ]] .. tostring(PER_CHARACTER_LIMIT) .. [[
        BEGIN
            SELECT RAISE(ABORT, 'character placed note limit reached');
        END]]) then return false end

    setElementData(resourceRoot, "hrp:inventory:placedNoteLimitPerCharacter", PER_CHARACTER_LIMIT, false)
    setElementData(resourceRoot, "hrp:inventory:placedNoteLimitServer", SERVER_LIMIT, false)
    return true
end

local function ensureWithRetry(attempt)
    attempt = tonumber(attempt) or 1
    if ensurePlacedNotesSchema() then
        log("info", "Tabela i limity notatek w swiecie gotowe: " .. tostring(PER_CHARACTER_LIMIT) .. " na postac, " .. tostring(SERVER_LIMIT) .. " globalnie.")
        return
    end

    if attempt >= MAX_RETRIES then
        log("error", "Nie udalo sie przygotowac tabeli world_placed_notes po " .. tostring(MAX_RETRIES) .. " probach.")
        return
    end

    setTimer(function() ensureWithRetry(attempt + 1) end, RETRY_DELAY_MS, 1)
end

addEventHandler("onResourceStart", resourceRoot, function()
    setTimer(function() ensureWithRetry(1) end, 250, 1)
end)

addEvent("HeavyRPG:Inventory:ensurePlacedNotesSchema", true)
addEventHandler("HeavyRPG:Inventory:ensurePlacedNotesSchema", resourceRoot, function()
    ensureWithRetry(1)
end)