HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Auth = HRP.Auth or {}
HRP.Auth.Repository = HRP.Auth.Repository or {}

local Repo = HRP.Auth.Repository

function Repo.findByIdentifier(identifier, callback)
    local normalized = HRP.Utils.lower(identifier)
    HRP.DB.query([[SELECT * FROM accounts
        WHERE normalized_username = ? OR LOWER(email) = ?
        LIMIT 1]], { normalized, normalized }, function(rows)
        callback(rows and rows[1] or nil)
    end)
end

function Repo.findById(accountId, callback)
    HRP.DB.query("SELECT * FROM accounts WHERE id = ? LIMIT 1", { tonumber(accountId) or 0 }, function(rows)
        callback(rows and rows[1] or nil)
    end)
end

function Repo.usernameOrEmailExists(username, email, callback)
    local normalized = HRP.Utils.lower(username)
    local normalizedEmail = HRP.Utils.lower(email)
    HRP.DB.query([[SELECT username, email FROM accounts
        WHERE normalized_username = ? OR LOWER(email) = ?
        LIMIT 1]], { normalized, normalizedEmail }, function(rows)
        callback(rows and rows[1] or nil)
    end)
end

function Repo.createAccount(username, email, passwordHashValue, player, callback)
    local now = HRP.Utils.now()
    local serial = getPlayerSerial(player)
    local ip = getPlayerIP(player)
    local normalized = HRP.Utils.lower(username)
    local spawnMoney = HRP.Config.auth.spawn.startingMoney or 500

    local created = HRP.DB.exec([[INSERT INTO accounts
        (username, normalized_username, email, password_hash, serial, last_serial, last_ip, cash, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            HRP.Utils.trim(username), normalized, HRP.Utils.lower(email), passwordHashValue,
            serial, serial, ip, spawnMoney, now, now
        })

    if not created then
        callback(false, nil)
        return
    end

    Repo.findByIdentifier(username, function(account)
        callback(account ~= nil, account and tonumber(account.id) or nil)
    end)
end

function Repo.updateSuccessfulLogin(accountId, player)
    local now = HRP.Utils.now()
    HRP.DB.exec([[UPDATE accounts
        SET failed_logins = 0, locked_until = 0, last_login_at = ?, updated_at = ?, last_serial = ?, last_ip = ?
        WHERE id = ?]], {
            now, now, getPlayerSerial(player), getPlayerIP(player), accountId
        })
end

function Repo.addFailedLogin(account, callback)
    local failed = (tonumber(account.failed_logins) or 0) + 1
    local lockUntil = 0
    local cfg = HRP.Config.auth.failedLoginLock

    if failed >= cfg.attempts then
        lockUntil = HRP.Utils.now() + cfg.lockSeconds
    end

    HRP.DB.exec("UPDATE accounts SET failed_logins = ?, locked_until = ?, updated_at = ? WHERE id = ?", {
        failed, lockUntil, HRP.Utils.now(), account.id
    })

    if callback then callback(failed, lockUntil) end
end
