HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientAuth = HRP.ClientAuth or {}
local Auth = HRP.ClientAuth

local function decodePayload(jsonPayload)
    if type(jsonPayload) ~= "string" then return {} end
    local data = fromJSON(jsonPayload)
    if type(data) ~= "table" then return {} end
    return data
end

function Auth.ready()
    local token = HRP.LocalStorage.getSessionToken()
    triggerServerEvent("HeavyRPG:Auth:clientReady", resourceRoot, token or false)
end

function Auth.show(payload)
    HRP.Browser.setVisible(true)
    HRP.Browser.emit("auth:show", payload or {})
end

function Auth.hide()
    HRP.Browser.emit("auth:hide", {})
    HRP.Browser.setVisible(false)
end

addEvent("HeavyRPG:UI:auth:login", true)
addEventHandler("HeavyRPG:UI:auth:login", root, function(jsonPayload)
    local payload = decodePayload(jsonPayload)
    triggerServerEvent("HeavyRPG:Auth:login", resourceRoot, payload)
end)

addEvent("HeavyRPG:UI:auth:register", true)
addEventHandler("HeavyRPG:UI:auth:register", root, function(jsonPayload)
    local payload = decodePayload(jsonPayload)
    triggerServerEvent("HeavyRPG:Auth:register", resourceRoot, payload)
end)

addEvent("HeavyRPG:UI:auth:logout", true)
addEventHandler("HeavyRPG:UI:auth:logout", root, function(deleteToken)
    triggerServerEvent("HeavyRPG:Auth:logout", resourceRoot, deleteToken == true)
end)

addEvent("HeavyRPG:Auth:show", true)
addEventHandler("HeavyRPG:Auth:show", resourceRoot, function(payload)
    Auth.show(payload)
end)

addEvent("HeavyRPG:Auth:response", true)
addEventHandler("HeavyRPG:Auth:response", resourceRoot, function(action, ok, response)
    response = response or {}

    if ok and response.payload then
        local token = response.payload.rememberToken
        if type(token) == "string" and #token > 0 then
            HRP.LocalStorage.setSessionToken(token)
        end
    end

    if ok and (action == "login" or action == "register" or action == "resume") then
        Auth.hide()
    end

    HRP.Browser.emit("auth:response", {
        action = action,
        ok = ok,
        response = response
    })
end)
