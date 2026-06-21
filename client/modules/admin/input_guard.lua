HeavyRPG = HeavyRPG or {}

local Guard = {
    active = false,
    chatVisible = true,
    originalSetVisible = nil
}

local function panelVisible()
    return HeavyRPG.ClientAdmin and HeavyRPG.ClientAdmin.visible == true
end

local function setChatBlocked(state)
    state = state == true
    if Guard.active == state then return end

    if state then
        Guard.chatVisible = isChatVisible and isChatVisible() or true
        unbindKey("t", "down", "chatbox")
        unbindKey("y", "down", "chatbox")
        if showChat then showChat(false) end
        Guard.active = true
    else
        bindKey("t", "down", "chatbox", "say")
        bindKey("y", "down", "chatbox", "teamsay")
        if showChat then showChat(Guard.chatVisible ~= false) end
        Guard.active = false
    end
end

local function syncGuard()
    setChatBlocked(panelVisible())
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

addEventHandler("onClientResourceStop", resourceRoot, function()
    setChatBlocked(false)
end)
