HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local function trim(value)
    value = tostring(value or "")
    if HRP.Utils and HRP.Utils.trim then return HRP.Utils.trim(value) end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function characterName(player)
    if not isElement(player) then return "Ktos" end
    local name = getElementData(player, "hrp:character:name")
    if type(name) == "string" and trim(name) ~= "" then return trim(name) end
    if HRP.Utils and HRP.Utils.safePlayerName then return HRP.Utils.safePlayerName(player) end
    return tostring(getPlayerName(player) or "Ktos"):gsub("#%x%x%x%x%x%x", "")
end

local function hasCharacter(player)
    return isElement(player) and tonumber(getElementData(player, "hrp:character:id")) ~= nil
end

local function cleanMessage(message)
    message = trim(message):gsub("#%x%x%x%x%x%x", ""):gsub("[%c\r\n]", " ")
    message = message:gsub("%s+", " ")
    if #message > 220 then message = message:sub(1, 220) end
    return message
end

local function outputTeamChat(player, text)
    local team = getPlayerTeam(player)
    if not team then return false end
    for _, target in ipairs(getPlayersInTeam(team)) do
        outputChatBox("[TEAM] " .. characterName(player) .. ": " .. text, target, 160, 205, 255)
    end
    return true
end

addEventHandler("onPlayerChat", root, function(message, messageType)
    cancelEvent()

    if not hasCharacter(source) then
        outputChatBox("[CHAT] Najpierw wybierz postac.", source, 230, 90, 80)
        return
    end

    local text = cleanMessage(message)
    if text == "" then return end

    messageType = tonumber(messageType) or 0
    if messageType == 1 then
        outputChatBox("* " .. characterName(source) .. " " .. text, root, 190, 150, 220)
    elseif messageType == 2 then
        if not outputTeamChat(source, text) then
            outputChatBox("[TEAM] " .. characterName(source) .. ": " .. text, source, 160, 205, 255)
        end
    else
        outputChatBox(characterName(source) .. ": " .. text, root, 235, 235, 235)
    end
end)
