HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Browser = HRP.Browser or {
    element = nil,
    ready = false,
    visible = false,
    sx = 0,
    sy = 0,
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    lastCursorX = 0,
    lastCursorY = 0
}

local Browser = HRP.Browser

local function updatePanelBounds()
    Browser.sx, Browser.sy = guiGetScreenSize()
    Browser.w = math.min(520, math.max(320, Browser.sx - 48))
    Browser.h = math.min(640, math.max(420, Browser.sy - 48))
    Browser.x = math.floor((Browser.sx - Browser.w) / 2)
    Browser.y = math.floor((Browser.sy - Browser.h) / 2)
end

local function isInsidePanel(absX, absY)
    return absX >= Browser.x and absX <= Browser.x + Browser.w and absY >= Browser.y and absY <= Browser.y + Browser.h
end

local function toBrowserPoint(absX, absY)
    return absX - Browser.x, absY - Browser.y
end

local function renderBrowser()
    if Browser.visible and Browser.element then
        dxDrawImage(Browser.x, Browser.y, Browser.w, Browser.h, Browser.element, 0, 0, 0, tocolor(255, 255, 255, 255), true)
    end
end

local function cursorMove(_, _, absX, absY)
    if not Browser.visible or not Browser.element then return end
    Browser.lastCursorX, Browser.lastCursorY = absX, absY

    if not isInsidePanel(absX, absY) then return end

    local browserX, browserY = toBrowserPoint(absX, absY)
    injectBrowserMouseMove(Browser.element, browserX, browserY)
end

local function cursorClick(button, state, absX, absY)
    if not Browser.visible or not Browser.element then return end
    if button ~= "left" and button ~= "right" and button ~= "middle" then return end
    if not isInsidePanel(absX, absY) then return end

    local browserX, browserY = toBrowserPoint(absX, absY)
    injectBrowserMouseMove(Browser.element, browserX, browserY)
    if state == "down" then
        injectBrowserMouseDown(Browser.element, button)
    else
        injectBrowserMouseUp(Browser.element, button)
    end
end

local function mouseWheel(key)
    if not Browser.visible or not Browser.element then return end
    if not isInsidePanel(Browser.lastCursorX, Browser.lastCursorY) then return end

    local delta = key == "mouse_wheel_up" and 1 or -1
    injectBrowserMouseWheel(Browser.element, delta, 0)
end

function Browser.init(callback)
    updatePanelBounds()
    Browser.element = createBrowser(math.max(1, Browser.w), math.max(1, Browser.h), true, true)

    if not Browser.element then
        outputDebugString("[HeavyRPG:UI] Nie udalo sie utworzyc CEF browsera.", 1)
        return false
    end

    addEventHandler("onClientBrowserCreated", Browser.element, function()
        loadBrowserURL(source, HRP.Config.ui.url)
    end)

    addEventHandler("onClientBrowserDocumentReady", Browser.element, function()
        Browser.ready = true
        Browser.call("window.HeavyRPG && window.HeavyRPG.setConfig", {
            serverName = HRP.Config.name,
            minPassword = HRP.Config.auth.passwordMin,
            usernameMin = HRP.Config.auth.usernameMin,
            usernameMax = HRP.Config.auth.usernameMax
        })
        if callback then callback() end
    end)

    return true
end

function Browser.setVisible(state)
    state = state == true
    if Browser.visible == state then return end

    Browser.visible = state
    showCursor(state)

    if Browser.element then
        focusBrowser(state and Browser.element or nil)
    end

    if state then
        updatePanelBounds()
        addEventHandler("onClientRender", root, renderBrowser)
        addEventHandler("onClientCursorMove", root, cursorMove)
        addEventHandler("onClientClick", root, cursorClick)
        bindKey("mouse_wheel_up", "down", mouseWheel)
        bindKey("mouse_wheel_down", "down", mouseWheel)
    else
        removeEventHandler("onClientRender", root, renderBrowser)
        removeEventHandler("onClientCursorMove", root, cursorMove)
        removeEventHandler("onClientClick", root, cursorClick)
        unbindKey("mouse_wheel_up", "down", mouseWheel)
        unbindKey("mouse_wheel_down", "down", mouseWheel)
    end
end

function Browser.call(functionName, payload)
    if not Browser.element or not Browser.ready then return false end

    local script
    if payload == nil then
        script = tostring(functionName) .. "();"
    else
        local json = toJSON(payload, true) or "{}"
        script = tostring(functionName) .. "(" .. json .. ");"
    end

    return executeBrowserJavascript(Browser.element, script)
end

function Browser.emit(name, detail)
    return Browser.call("window.HeavyRPG && window.HeavyRPG.receive", { name = name, detail = detail or {} })
end

bindKey(HRP.Config.ui.toggleDevToolsKey, "down", function()
    if Browser.element and Browser.visible then
        toggleBrowserDevTools(Browser.element, true)
    end
end)
