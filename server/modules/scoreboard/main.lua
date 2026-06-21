HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Scoreboard = HRP.Scoreboard or {}

local Scoreboard = HRP.Scoreboard

local function trim(value)
    value = tostring(value or "")
    if HRP.Utils and HRP.Utils.trim then return HRP.Utils.trim(value) end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function cleanText(value, fallback)
    value = trim(value or fallback or "")
    value = value:gsub("#%x%x%x%x%x%x", ""):gsub("[%c\r\n]", " ")
    value = value:gsub("%s+", " ")
    if value == "" then return fallback or "-" end
    return value
end

local function characterName(player)
    local stored = getElementData(player, "hrp:character:name")
    if type(stored) == "string" and trim(stored) ~= "" then
        return cleanText(stored, "Bez postaci")
    end

    local firstname = getElementData(player, "hrp:character:firstname")
    local lastname = getElementData(player, "hrp:character:lastname")
    local fullName = trim(tostring(firstname or "") .. " " .. tostring(lastname or ""))
    if fullName ~= "" then return cleanText(fullName, "Bez postaci") end

    return "Bez postaci"
end

local function loginName(player)
    if HRP.Auth and HRP.Auth.Session and HRP.Auth.Session.getAccount then
        local account = HRP.Auth.Session.getAccount(player)
        if account and account.username then
            return cleanText(account.username, "niezalogowany")
        end
    end

    local username = getElementData(player, "HRP:account:username")
    if type(username) == "string" and trim(username) ~= "" then
        return cleanText(username, "niezalogowany")
    end

    return "niezalogowany"
end

local function playerRow(player)
    local characterId = tonumber(getElementData(player, "hrp:character:id"))
    local accountId = tonumber(getElementData(player, "HRP:account:id"))

    return {
        characterId = characterId or 0,
        accountId = accountId or 0,
        characterName = characterName(player),
        login = loginName(player),
        ping = getPlayerPing(player) or 0,
        ready = characterId ~= nil
    }
end

local function buildRows()
    local rows = {}

    for _, player in ipairs(getElementsByType("player")) do
        rows[#rows + 1] = playerRow(player)
    end

    table.sort(rows, function(a, b)
        if a.ready ~= b.ready then return a.ready end
        if a.characterName ~= b.characterName then return a.characterName < b.characterName end
        return a.login < b.login
    end)

    return rows
end

function Scoreboard.sendTo(player)
    if not isElement(player) then return false end
    triggerClientEvent(player, "HeavyRPG:Scoreboard:update", resourceRoot, buildRows())
    return true
end

addEvent("HeavyRPG:Scoreboard:request", true)
addEventHandler("HeavyRPG:Scoreboard:request", resourceRoot, function()
    if client and isElement(client) then
        Scoreboard.sendTo(client)
    end
end)

local module = {}
function module.onStart()
    HRP.Logger.info("scoreboard", "Customowa tabela TAB gotowa.")
end

HRP.Modules.register("scoreboard", module)
