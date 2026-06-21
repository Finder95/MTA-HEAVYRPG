HeavyRPG = HeavyRPG or {}

local Guard = {
    active = false,
    chatVisible = true,
    originalSetVisible = nil
}

local chatKeys = {
    t = true,
    y = true,
    u = true
}

local function panelVisible()
    return HeavyRPG.ClientAdmin and HeavyRPG.ClientAdmin.visible == true
end

local function setChatHidden(state)
    state = state == true
    if Guard.active == state then return end

    if state then
        Guard.chatVisible = isChatVisible and isChatVisible() or true
        if showChat then showChat(false) end
        Guard.active = true
    else
        if showChat then showChat(Guard.chatVisible ~= false) end
        Guard.active = false
    end
end

local function syncGuard()
    setChatHidden(panelVisible())
end

local function blockChatKeys(button, press)
    if not press or not panelVisible() then return end
    local key = tostring(button or ""):lower()
    if chatKeys[key] then cancelEvent() end
end

setTimer(function()
    if Guard.originalSetVisible or type(setVisible) ~= "function" then return end

    Guard.originalSetVisible = setVisible
    function setVisible(state)
        local result = Guard.originalSetVisible(state)
        syncGuard()
        return result
    end
end, 0, 1)

addEventHandler("onClientRender", root, syncGuard)
addEventHandler("onClientKey", root, blockChatKeys, true, "high+999")

addEventHandler("onClientResourceStop", resourceRoot, function()
    setChatHidden(false)
end)
