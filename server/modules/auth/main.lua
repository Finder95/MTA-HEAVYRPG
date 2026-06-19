HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Auth = HRP.Auth or {}
local Auth = HRP.Auth

local function sendAuth(player, action, ok, code, message, payload)
    if not isElement(player) then return end
    triggerClientEvent(player, "HeavyRPG:Auth:response", resourceRoot, action, ok, {
        code = code,
        message = message,
        payload = payload or {}
    })
end

local function showAuth(player, reason)
    if not isElement(player) then return end
    triggerClientEvent(player, "HeavyRPG:Auth:show", resourceRoot, {
        reason = reason or "auth_required",
        serverName = HRP.Config.name,
        minPassword = HRP.Config.auth.passwordMin,
        usernameMin = HRP.Config.auth.usernameMin,
        usernameMax = HRP.Config.auth.usernameMax
    })
end

local function generatedEmail(username)
    return HRP.Utils.lower(username) .. "@local.heavyrpg"
end

local function routeAfterAuth(player, account, publicAccount)
    if HRP.Character and HRP.Character.Repository then
        HRP.Character.Repository.findByAccountId(account.id, function(character)
            if not isElement(player) then return end
            if character then
                triggerEvent("HeavyRPG:Character:onPlayerReady", resourceRoot, player, HRP.Character.getPublic(character))
            else
                HRP.Character.showCreator(player, publicAccount)
            end
        end)
        return
    end

    triggerEvent("HeavyRPG:Auth:onPlayerLoggedIn", resourceRoot, player, publicAccount)
end

local function finishLogin(player, account, remember, authType)
    HRP.Auth.Repository.updateSuccessfulLogin(account.id, player)

    local function attachWithToken(token)
        local payload = HRP.Auth.Session.attach(player, account, authType or "password", token)
        HRP.Security.audit(account.id, account.username, authType or "login", true, player, "OK")
        sendAuth(player, authType == "register" and "register" or "login", true, HRP.AuthCodes.OK, "Zalogowano pomyslnie.", payload)
        routeAfterAuth(player, account, payload.account)
    end

    if remember then
        HRP.Auth.Session.createRememberToken(account.id, player, attachWithToken)
    else
        attachWithToken(nil)
    end
end

local function handleLogin(player, payload)
    if HRP.Auth.Session.isLogged(player) then
        sendAuth(player, "login", false, HRP.AuthCodes.ALREADY_LOGGED_IN, "Jestes juz zalogowany.")
        return
    end

    local allowed, rateReason = HRP.Security.checkRateLimit(player, "login")
    if not allowed then
        sendAuth(player, "login", false, HRP.AuthCodes.RATE_LIMIT, rateReason)
        return
    end

    local valid, reason = HRP.Auth.Validators.loginPayload(payload)
    if not valid then
        sendAuth(player, "login", false, HRP.AuthCodes.VALIDATION_FAILED, reason)
        return
    end

    local identifier = HRP.Utils.trim(payload.identifier or payload.username)
    local password = tostring(payload.password or "")
    local remember = HRP.Utils.bool(payload.remember)

    HRP.Auth.Repository.findByIdentifier(identifier, function(account)
        if not isElement(player) then return end

        if not account then
            HRP.Security.audit(nil, identifier, "login", false, player, "ACCOUNT_NOT_FOUND")
            sendAuth(player, "login", false, HRP.AuthCodes.ACCOUNT_NOT_FOUND, "Nieprawidlowy login lub haslo.")
            return
        end

        local now = HRP.Utils.now()
        if tonumber(account.is_banned) == 1 then
            HRP.Security.audit(account.id, account.username, "login", false, player, "ACCOUNT_BANNED")
            sendAuth(player, "login", false, HRP.AuthCodes.ACCOUNT_BANNED, account.ban_reason or "Konto jest zablokowane.")
            return
        end

        if tonumber(account.locked_until) and tonumber(account.locked_until) > now then
            local left = tonumber(account.locked_until) - now
            HRP.Security.audit(account.id, account.username, "login", false, player, "ACCOUNT_LOCKED")
            sendAuth(player, "login", false, HRP.AuthCodes.ACCOUNT_LOCKED, "Konto chwilowo zablokowane. Sprobuj za " .. tostring(math.ceil(left / 60)) .. " min.")
            return
        end

        if not HRP.Auth.Session.canLoginAccount(account.id, player) then
            sendAuth(player, "login", false, HRP.AuthCodes.ALREADY_LOGGED_IN, "To konto jest juz online.")
            return
        end

        passwordVerify(password, account.password_hash, {}, function(match)
            if not isElement(player) then return end

            if match then
                finishLogin(player, account, remember, "login")
                return
            end

            HRP.Auth.Repository.addFailedLogin(account, function(failed, lockUntil)
                local msg = "Nieprawidlowy login lub haslo."
                if lockUntil and lockUntil > 0 then
                    msg = "Za duzo blednych prob. Konto zablokowane na 15 minut."
                end

                HRP.Security.audit(account.id, account.username, "login", false, player, "PASSWORD_INVALID:" .. tostring(failed))
                sendAuth(player, "login", false, HRP.AuthCodes.PASSWORD_INVALID, msg)
            end)
        end)
    end)
end

local function handleRegister(player, payload)
    if HRP.Auth.Session.isLogged(player) then
        sendAuth(player, "register", false, HRP.AuthCodes.ALREADY_LOGGED_IN, "Jestes juz zalogowany.")
        return
    end

    local allowed, rateReason = HRP.Security.checkRateLimit(player, "register")
    if not allowed then
        sendAuth(player, "register", false, HRP.AuthCodes.RATE_LIMIT, rateReason)
        return
    end

    local valid, reason = HRP.Auth.Validators.registerPayload(payload)
    if not valid then
        sendAuth(player, "register", false, HRP.AuthCodes.VALIDATION_FAILED, reason)
        return
    end

    local username = HRP.Utils.trim(payload.username)
    local email = generatedEmail(username)
    local password = tostring(payload.password)
    local remember = HRP.Utils.bool(payload.remember)
    local serial = getPlayerSerial(player)

    HRP.Auth.Repository.countBySerial(serial, function(count)
        if not isElement(player) then return end
        if count >= HRP.Config.auth.maxAccountsPerSerial then
            HRP.Security.audit(nil, username, "register", false, player, "SERIAL_LIMIT")
            sendAuth(player, "register", false, HRP.AuthCodes.SERIAL_LIMIT, "Osiagnieto limit kont dla tego serialu.")
            return
        end

        HRP.Auth.Repository.usernameOrEmailExists(username, email, function(existing)
            if not isElement(player) then return end
            if existing then
                HRP.Security.audit(nil, username, "register", false, player, "ACCOUNT_EXISTS")
                sendAuth(player, "register", false, HRP.AuthCodes.ACCOUNT_EXISTS, "Ten login jest juz zajety.")
                return
            end

            passwordHash(password, "bcrypt", { cost = HRP.Config.auth.bcryptCost }, function(hashedPassword)
                if not isElement(player) then return end
                if not hashedPassword then
                    sendAuth(player, "register", false, HRP.AuthCodes.SERVER_ERROR, "Nie udalo sie zabezpieczyc hasla.")
                    return
                end

                HRP.Auth.Repository.createAccount(username, email, hashedPassword, player, function(created, accountId)
                    if not isElement(player) then return end
                    if not created then
                        HRP.Security.audit(nil, username, "register", false, player, "INSERT_FAILED")
                        sendAuth(player, "register", false, HRP.AuthCodes.ACCOUNT_EXISTS, "Nie udalo sie utworzyc konta. Mozliwe, ze login jest zajety.")
                        return
                    end

                    HRP.Security.audit(accountId, username, "register", true, player, "OK")
                    HRP.Auth.Repository.findById(accountId, function(account)
                        if not isElement(player) or not account then
                            sendAuth(player, "register", false, HRP.AuthCodes.SERVER_ERROR, "Konto utworzono, ale nie udalo sie go zalogowac.")
                            return
                        end
                        finishLogin(player, account, remember, "register")
                    end)
                end)
            end)
        end)
    end)
end

local function handleResume(player, token)
    local allowed, rateReason = HRP.Security.checkRateLimit(player, "resume")
    if not allowed then
        showAuth(player, "rate_limit")
        return
    end

    if HRP.Auth.Session.isLogged(player) then return end

    HRP.Auth.Session.resumeFromToken(player, token, function(ok, code, data)
        if not isElement(player) then return end
        if ok then
            HRP.Security.audit(data.account.id, data.account.username, "resume", true, player, "OK")
            sendAuth(player, "resume", true, HRP.AuthCodes.OK, "Sesja przywrocona.", data)
            routeAfterAuth(player, data.account, data.account)
        else
            HRP.Security.audit(nil, nil, "resume", false, player, tostring(code))
            showAuth(player, tostring(code or "session_invalid"))
            sendAuth(player, "resume", false, code or HRP.AuthCodes.SESSION_INVALID, "Sesja wygasla. Zaloguj sie ponownie.")
        end
    end)
end

function isPlayerAuthenticated(player)
    return HRP.Auth.Session.isLogged(player)
end

function getPlayerAccountId(player)
    return HRP.Auth.Session.getAccountId(player)
end

function getPlayerAccountData(player)
    return HRP.Auth.Session.getAccount(player)
end

addEvent("HeavyRPG:Auth:clientReady", true)
addEventHandler("HeavyRPG:Auth:clientReady", resourceRoot, function(token)
    local player = client
    if not isElement(player) then return end

    fadeCamera(player, true)
    setElementFrozen(player, true)

    if type(token) == "string" and #token > 0 then
        handleResume(player, token)
    else
        showAuth(player, "client_ready")
    end
end)

addEvent("HeavyRPG:Auth:login", true)
addEventHandler("HeavyRPG:Auth:login", resourceRoot, function(payload)
    if client then handleLogin(client, payload) end
end)

addEvent("HeavyRPG:Auth:register", true)
addEventHandler("HeavyRPG:Auth:register", resourceRoot, function(payload)
    if client then handleRegister(client, payload) end
end)

addEvent("HeavyRPG:Auth:logout", true)
addEventHandler("HeavyRPG:Auth:logout", resourceRoot, function(deleteToken)
    local player = client
    if not isElement(player) then return end

    if HRP.Utils.bool(deleteToken) then
        HRP.Auth.Session.deletePlayerTokens(player)
    end

    HRP.Security.audit(HRP.Auth.Session.getAccountId(player), nil, "logout", true, player, "OK")
    HRP.Auth.Session.detach(player)
    showAuth(player, "logout")
end)

addEvent("HeavyRPG:Auth:onPlayerLoggedIn", false)

local module = {}
function module.onStart()
    for _, player in ipairs(getElementsByType("player")) do
        if not HRP.Auth.Session.isLogged(player) then
            setTimer(function(p)
                if isElement(p) then showAuth(p, "resource_start") end
            end, 1500, 1, player)
        end
    end
end

HRP.Modules.register("auth", module)
