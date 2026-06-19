HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Auth = HRP.Auth or {}
HRP.Auth.Validators = HRP.Auth.Validators or {}

local V = HRP.Auth.Validators

function V.username(username)
    username = HRP.Utils.trim(username)
    local cfg = HRP.Config.auth

    if #username < cfg.usernameMin or #username > cfg.usernameMax then
        return false, "Nazwa musi miec od " .. cfg.usernameMin .. " do " .. cfg.usernameMax .. " znakow."
    end

    if not username:match("^[A-Za-z0-9_]+$") then
        return false, "Nazwa moze zawierac tylko litery, cyfry i podkreslenie."
    end

    return true
end

function V.email(email)
    email = HRP.Utils.lower(email)
    local cfg = HRP.Config.auth

    if #email < 6 or #email > cfg.emailMax then
        return false, "Podaj poprawny adres e-mail."
    end

    if not email:match("^[%w%._%+%-]+@[%w%-]+%.[%w%.-]+$") then
        return false, "Podaj poprawny adres e-mail."
    end

    return true
end

function V.password(password)
    if type(password) ~= "string" then
        return false, "Haslo jest wymagane."
    end

    local cfg = HRP.Config.auth
    if #password < cfg.passwordMin then
        return false, "Haslo musi miec minimum " .. cfg.passwordMin .. " znakow."
    end

    if #password > cfg.passwordMax then
        return false, "Haslo jest za dlugie. Maksymalnie " .. cfg.passwordMax .. " znaki."
    end

    return true
end

function V.loginPayload(payload)
    if type(payload) ~= "table" then
        return false, "Niepoprawne dane logowania."
    end

    local identifier = HRP.Utils.trim(payload.identifier or payload.username or "")
    local password = payload.password

    if #identifier < 3 then
        return false, "Wpisz login."
    end

    if type(password) ~= "string" or #password < 1 then
        return false, "Wpisz haslo."
    end

    return true
end

function V.registerPayload(payload)
    if type(payload) ~= "table" then
        return false, "Niepoprawne dane rejestracji."
    end

    local ok, reason = V.username(payload.username)
    if not ok then return false, reason end

    ok, reason = V.password(payload.password)
    if not ok then return false, reason end

    return true
end
