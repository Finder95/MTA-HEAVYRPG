HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Auth = HRP.Auth or {}
HRP.Auth.Session = HRP.Auth.Session or {
    players = setmetatable({}, { __mode = "k" }),
    accountToPlayer = {}
}

local Session = HRP.Auth.Session

local function publicAccount(account)
    if not account then return nil end
    return {
        id = tonumber(account.id),
        username = account.username,
        email = account.email,
        cash = tonumber(account.cash) or 0,
        level = tonumber(account.level) or 1,
        xp = tonumber(account.xp) or 0,
        adminLevel = tonumber(account.admin_level) or 0
    }
end

function Session.isLogged(player)
    return Session.players[player] ~= nil
end

function Session.getAccountId(player)
    local session = Session.players[player]
    return session and session.account and tonumber(session.account.id) or nil
end

function Session.getAccount(player)
    local session = Session.players[player]
    return session and publicAccount(session.account) or nil
end

function Session.canLoginAccount(accountId, player)
    local oldPlayer = Session.accountToPlayer[tonumber(accountId)]
    if oldPlayer and isElement(oldPlayer) and oldPlayer ~= player then
        if HRP.Config.auth.kickOldSession then
            kickPlayer(oldPlayer, "HeavyRPG", "Konto zostalo zalogowane z innej sesji.")
            return true
        end
        return false
    end
    return true
end

function Session.attach(player, account, authType, rememberToken)
    local accountId = tonumber(account.id)
    Session.players[player] = {
        account = account,
        authType = authType or "password",
        loggedAt = HRP.Utils.now()
    }
    Session.accountToPlayer[accountId] = player

    setElementData(player, "HRP:auth", true, false)
    setElementData(player, "HRP:account:id", accountId, false)
    setElementData(player, "HRP:account:username", account.username, false)

    return {
        account = publicAccount(account),
        rememberToken = rememberToken
    }
end

function Session.detach(player)
    local session = Session.players[player]
    if session and session.account then
        Session.accountToPlayer[tonumber(session.account.id)] = nil
    end

    Session.players[player] = nil
    setElementData(player, "HRP:auth", false, false)
    setElementData(player, "HRP:account:id", false, false)
    setElementData(player, "HRP:account:username", false, false)
end

function Session.createRememberToken(accountId, player, callback)
    if not HRP.Config.auth.rememberSession.enabled then
        callback(nil)
        return
    end

    local raw = table.concat({
        HRP.Utils.randomToken(96),
        tostring(accountId),
        tostring(getTickCount()),
        tostring(getPlayerSerial(player)),
        tostring(math.random(100000, 999999))
    }, ":")

    local token = HRP.Utils.hashSha256(raw) .. HRP.Utils.randomToken(32)
    local tokenHash = HRP.Utils.hashSha256(token)
    local now = HRP.Utils.now()
    local expires = now + ((HRP.Config.auth.rememberSession.days or 14) * 86400)

    local created = HRP.DB.exec([[INSERT INTO account_sessions(account_id, token_hash, serial, ip, created_at, last_used_at, expires_at)
        VALUES(?, ?, ?, ?, ?, ?, ?)]], {
            accountId, tokenHash, getPlayerSerial(player), getPlayerIP(player), now, now, expires
        })

    callback(created and token or nil)
end

function Session.resumeFromToken(player, token, callback)
    if type(token) ~= "string" or #token < 32 then
        callback(false, HRP.AuthCodes.SESSION_INVALID)
        return
    end

    local tokenHash = HRP.Utils.hashSha256(token)
    local now = HRP.Utils.now()
    local serial = getPlayerSerial(player)

    HRP.DB.query([[SELECT s.id AS session_id, s.expires_at, s.serial AS session_serial,
            a.*
        FROM account_sessions s
        INNER JOIN accounts a ON a.id = s.account_id
        WHERE s.token_hash = ?
        LIMIT 1]], { tokenHash }, function(rows)
        local row = rows and rows[1]
        if not row then
            callback(false, HRP.AuthCodes.SESSION_INVALID)
            return
        end

        if tostring(row.session_serial) ~= tostring(serial) then
            HRP.DB.exec("DELETE FROM account_sessions WHERE id = ?", { row.session_id })
            callback(false, HRP.AuthCodes.SESSION_INVALID)
            return
        end

        if tonumber(row.expires_at) <= now then
            HRP.DB.exec("DELETE FROM account_sessions WHERE id = ?", { row.session_id })
            callback(false, HRP.AuthCodes.SESSION_INVALID)
            return
        end

        if tonumber(row.is_banned) == 1 then
            callback(false, HRP.AuthCodes.ACCOUNT_BANNED, row.ban_reason)
            return
        end

        if not Session.canLoginAccount(row.id, player) then
            callback(false, HRP.AuthCodes.ALREADY_LOGGED_IN)
            return
        end

        HRP.DB.exec("UPDATE account_sessions SET last_used_at = ?, ip = ? WHERE id = ?", {
            now, getPlayerIP(player), row.session_id
        })
        HRP.Auth.Repository.updateSuccessfulLogin(row.id, player)

        local payload = Session.attach(player, row, "remember", token)
        callback(true, HRP.AuthCodes.OK, payload)
    end)
end

function Session.deletePlayerTokens(player)
    local accountId = Session.getAccountId(player)
    if accountId then
        HRP.DB.exec("DELETE FROM account_sessions WHERE account_id = ? AND serial = ?", { accountId, getPlayerSerial(player) })
    end
end

addEventHandler("onPlayerQuit", root, function()
    Session.detach(source)
end)
