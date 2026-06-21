HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Utils = HRP.Utils or {}

function HRP.Utils.trim(value)
    if type(value) ~= "string" then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function HRP.Utils.lower(value)
    if type(value) ~= "string" then return "" end
    return string.lower(HRP.Utils.trim(value))
end

function HRP.Utils.now()
    local rt = getRealTime()
    return rt and rt.timestamp or 0
end

function HRP.Utils.bool(value)
    return value == true or value == 1 or value == "1" or value == "true"
end

function HRP.Utils.safePlayerName(player)
    if isElement(player) and getElementType(player) == "player" then
        local characterName = getElementData(player, "hrp:character:name")
        if type(characterName) == "string" and HRP.Utils.trim(characterName) ~= "" then
            return HRP.Utils.trim(characterName):gsub("#%x%x%x%x%x%x", "")
        end
        return getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
    end
    return "unknown"
end

function HRP.Utils.hashSha256(value)
    return hash("sha256", tostring(value or ""))
end

function HRP.Utils.randomToken(length)
    length = length or 64
    local alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local out = {}

    for i = 1, length do
        local index = math.random(1, #alphabet)
        out[#out + 1] = alphabet:sub(index, index)
    end

    return table.concat(out)
end

function HRP.Utils.jsQuote(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\"", "\\\"")
    return "\"" .. value .. "\""
end
