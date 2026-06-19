HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.DB = HRP.DB or {}
HRP.DB.connection = nil

local schema = {
    [[CREATE TABLE IF NOT EXISTS schema_meta (
        "key" TEXT PRIMARY KEY,
        "value" TEXT NOT NULL
    )]],

    [[CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE COLLATE NOCASE,
        normalized_username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        serial TEXT NOT NULL,
        last_serial TEXT,
        last_ip TEXT,
        cash INTEGER NOT NULL DEFAULT 500,
        level INTEGER NOT NULL DEFAULT 1,
        xp INTEGER NOT NULL DEFAULT 0,
        admin_level INTEGER NOT NULL DEFAULT 0,
        is_banned INTEGER NOT NULL DEFAULT 0,
        ban_reason TEXT,
        failed_logins INTEGER NOT NULL DEFAULT 0,
        locked_until INTEGER NOT NULL DEFAULT 0,
        settings_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_login_at INTEGER
    )]],

    [[CREATE INDEX IF NOT EXISTS idx_accounts_serial ON accounts(serial)]],
    [[CREATE INDEX IF NOT EXISTS idx_accounts_email ON accounts(email)]],

    [[CREATE TABLE IF NOT EXISTS account_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        token_hash TEXT NOT NULL UNIQUE,
        serial TEXT NOT NULL,
        ip TEXT,
        created_at INTEGER NOT NULL,
        last_used_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
    )]],

    [[CREATE INDEX IF NOT EXISTS idx_sessions_account ON account_sessions(account_id)]],
    [[CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON account_sessions(expires_at)]],

    [[CREATE TABLE IF NOT EXISTS auth_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER,
        username TEXT,
        action TEXT NOT NULL,
        success INTEGER NOT NULL,
        ip TEXT,
        serial TEXT,
        reason TEXT,
        created_at INTEGER NOT NULL
    )]],

    [[CREATE INDEX IF NOT EXISTS idx_audit_account ON auth_audit(account_id)]],
    [[CREATE INDEX IF NOT EXISTS idx_audit_created ON auth_audit(created_at)]],

    [[CREATE TABLE IF NOT EXISTS characters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        firstname TEXT NOT NULL,
        lastname TEXT NOT NULL,
        gender TEXT NOT NULL DEFAULT 'male',
        age INTEGER NOT NULL DEFAULT 18,
        origin TEXT NOT NULL DEFAULT 'ls_native',
        archetype TEXT NOT NULL DEFAULT 'worker',
        strength INTEGER NOT NULL DEFAULT 4,
        endurance INTEGER NOT NULL DEFAULT 4,
        agility INTEGER NOT NULL DEFAULT 4,
        intelligence INTEGER NOT NULL DEFAULT 4,
        charisma INTEGER NOT NULL DEFAULT 4,
        focus INTEGER NOT NULL DEFAULT 4,
        stat_points INTEGER NOT NULL DEFAULT 24,
        cash INTEGER NOT NULL DEFAULT 500,
        bank INTEGER NOT NULL DEFAULT 0,
        skin INTEGER NOT NULL DEFAULT 0,
        pos_x REAL NOT NULL DEFAULT 1481.08,
        pos_y REAL NOT NULL DEFAULT -1749.32,
        pos_z REAL NOT NULL DEFAULT 15.45,
        rotation REAL NOT NULL DEFAULT 0,
        interior INTEGER NOT NULL DEFAULT 0,
        dimension INTEGER NOT NULL DEFAULT 0,
        playtime INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
    )]],

    [[CREATE INDEX IF NOT EXISTS idx_characters_account ON characters(account_id)]],
    [[CREATE INDEX IF NOT EXISTS idx_characters_account_updated ON characters(account_id, updated_at)]]
}

local migrations = {
    [[ALTER TABLE characters ADD COLUMN gender TEXT NOT NULL DEFAULT 'male']],
    [[ALTER TABLE characters ADD COLUMN origin TEXT NOT NULL DEFAULT 'ls_native']],
    [[ALTER TABLE characters ADD COLUMN archetype TEXT NOT NULL DEFAULT 'worker']],
    [[ALTER TABLE characters ADD COLUMN strength INTEGER NOT NULL DEFAULT 4]],
    [[ALTER TABLE characters ADD COLUMN endurance INTEGER NOT NULL DEFAULT 4]],
    [[ALTER TABLE characters ADD COLUMN agility INTEGER NOT NULL DEFAULT 4]],
    [[ALTER TABLE characters ADD COLUMN intelligence INTEGER NOT NULL DEFAULT 4]],
    [[ALTER TABLE characters ADD COLUMN charisma INTEGER NOT NULL DEFAULT 4]],
    [[ALTER TABLE characters ADD COLUMN focus INTEGER NOT NULL DEFAULT 4]],
    [[ALTER TABLE characters ADD COLUMN stat_points INTEGER NOT NULL DEFAULT 24]],
    [[ALTER TABLE characters ADD COLUMN playtime INTEGER NOT NULL DEFAULT 0]],
    [[ALTER TABLE characters ADD COLUMN last_played_at INTEGER]]
}

local function applyCompatibleMigrations()
    for _, sql in ipairs(migrations) do
        -- SQLite has no ADD COLUMN IF NOT EXISTS in older builds. Duplicate-column failures are expected.
        dbExec(HRP.DB.connection, sql)
    end
end

function HRP.DB.connect()
    if HRP.DB.connection and isElement(HRP.DB.connection) then
        return true
    end

    local cfg = HRP.Config.database
    local options = "share=" .. tostring(cfg.share or 0)
    HRP.DB.connection = dbConnect("sqlite", cfg.path, "", "", options)

    if not HRP.DB.connection then
        HRP.Logger.error("database", "Nie udalo sie polaczyc z SQLite: " .. tostring(cfg.path))
        return false
    end

    for _, sql in ipairs(schema) do
        if not dbExec(HRP.DB.connection, sql) then
            HRP.Logger.error("database", "Blad migracji schema: " .. tostring(sql))
            return false
        end
    end

    applyCompatibleMigrations()

    if not dbExec(HRP.DB.connection, [[INSERT OR REPLACE INTO schema_meta("key", "value") VALUES(?, ?)]], "schema_version", tostring(cfg.schemaVersion or 1)) then
        HRP.Logger.error("database", "Nie udalo sie zapisac schema_version w schema_meta.")
        return false
    end

    HRP.Logger.info("database", "SQLite gotowe: " .. cfg.path)
    return true
end

function HRP.DB.getConnection()
    return HRP.DB.connection
end

function HRP.DB.exec(sql, params)
    if not HRP.DB.connection then return false end
    params = params or {}
    return dbExec(HRP.DB.connection, sql, unpack(params))
end

function HRP.DB.query(sql, params, callback)
    if not HRP.DB.connection then
        if callback then callback(false, 0, 0) end
        return false
    end

    params = params or {}
    return dbQuery(function(qh)
        local result, affectedRows, lastInsertId = dbPoll(qh, 0)
        if result == false then
            HRP.Logger.error("database", "Blad SQL: " .. tostring(lastInsertId or affectedRows or "unknown") .. " | " .. tostring(sql))
            if callback then callback(false, 0, 0) end
            return
        end

        if callback then
            callback(result or {}, tonumber(affectedRows) or 0, tonumber(lastInsertId) or 0)
        end
    end, HRP.DB.connection, sql, unpack(params))
end

function HRP.DB.shutdown()
    if HRP.DB.connection and isElement(HRP.DB.connection) then
        destroyElement(HRP.DB.connection)
    end
    HRP.DB.connection = nil
end