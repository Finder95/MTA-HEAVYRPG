HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientAdmin = HRP.ClientAdmin or {
    browser = nil,
    ready = false,
    visible = false,
    pending = nil,
    sx = 0,
    sy = 0,
    x = 0,
    y = 0,
    w = 1480,
    h = 860,
    lastX = 0,
    lastY = 0,
    spectating = false
}

local Panel = HRP.ClientAdmin

local function decodePayload(payload)
    if type(payload) == "table" then return payload end
    if type(payload) == "string" then local data = fromJSON(payload) if type(data) == "table" then return data end end
    return {}
end

local function updateBounds()
    Panel.sx, Panel.sy = guiGetScreenSize()
    local baseW, baseH = 1480, 860
    local scale = math.min(Panel.sx / 1600, Panel.sy / 940)
    if scale < 0.72 then scale = 0.72 end
    if scale > 1.08 then scale = 1.08 end
    Panel.w = math.floor(baseW * scale)
    Panel.h = math.floor(baseH * scale)
    if Panel.w > Panel.sx - 48 then Panel.w = Panel.sx - 48 end
    if Panel.h > Panel.sy - 48 then Panel.h = Panel.sy - 48 end
    Panel.x = math.floor((Panel.sx - Panel.w) / 2)
    Panel.y = math.floor((Panel.sy - Panel.h) / 2)
end

local function inside(x, y) return x >= Panel.x and x <= Panel.x + Panel.w and y >= Panel.y and y <= Panel.y + Panel.h end
local function browserPoint(x, y) return x - Panel.x, y - Panel.y end

local function call(fn, payload)
    if not Panel.browser or not Panel.ready then return false end
    return executeBrowserJavascript(Panel.browser, tostring(fn) .. "(" .. (toJSON(payload or {}, true) or "{}") .. ");")
end

local function emit(name, detail)
    return call("window.HeavyRPGAdmin && window.HeavyRPGAdmin.receive", { name = name, detail = detail or {} })
end

local function render()
    if not Panel.visible or not Panel.browser then return end
    dxDrawRectangle(0, 0, Panel.sx, Panel.sy, tocolor(5, 7, 8, 150), true)
    dxDrawImage(Panel.x, Panel.y, Panel.w, Panel.h, Panel.browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
end

local function cursorMove(_, _, x, y)
    if not Panel.visible or not Panel.browser then return end
    Panel.lastX, Panel.lastY = x, y
    if not inside(x, y) then return end
    local bx, by = browserPoint(x, y)
    injectBrowserMouseMove(Panel.browser, bx, by)
end

local function cursorClick(button, state, x, y)
    if not Panel.visible or not Panel.browser then return end
    if button ~= "left" and button ~= "right" and button ~= "middle" then return end
    if not inside(x, y) then return end
    local bx, by = browserPoint(x, y)
    injectBrowserMouseMove(Panel.browser, bx, by)
    if state == "down" then focusBrowser(Panel.browser) injectBrowserMouseDown(Panel.browser, button) else injectBrowserMouseUp(Panel.browser, button) end
    cancelEvent()
end

local function wheel(key)
    if not Panel.visible or not Panel.browser then return end
    if not inside(Panel.lastX, Panel.lastY) then return end
    injectBrowserMouseWheel(Panel.browser, key == "mouse_wheel_up" and 1 or -1, 0)
end

local function setVisible(state)
    state = state == true
    if Panel.visible == state then return end
    Panel.visible = state
    showCursor(state)
    if Panel.browser then focusBrowser(state and Panel.browser or nil) end
    if state then
        updateBounds()
        addEventHandler("onClientRender", root, render)
        addEventHandler("onClientCursorMove", root, cursorMove)
        addEventHandler("onClientClick", root, cursorClick)
        bindKey("mouse_wheel_up", "down", wheel)
        bindKey("mouse_wheel_down", "down", wheel)
    else
        removeEventHandler("onClientRender", root, render)
        removeEventHandler("onClientCursorMove", root, cursorMove)
        removeEventHandler("onClientClick", root, cursorClick)
        unbindKey("mouse_wheel_up", "down", wheel)
        unbindKey("mouse_wheel_down", "down", wheel)
    end
end

local function ensureBrowser(callback)
    if Panel.browser and Panel.ready then if callback then callback() end return true end
    updateBounds()
    if not Panel.browser then
        Panel.browser = createBrowser(math.max(1, Panel.w), math.max(1, Panel.h), true, true)
        if not Panel.browser then outputDebugString("[HeavyRPG:Admin] Nie udalo sie utworzyc CEF adminpanelu.", 1) return false end
        addEventHandler("onClientBrowserCreated", Panel.browser, function() loadBrowserURL(source, "http://mta/local/html/admin/index.html") end)
        addEventHandler("onClientBrowserDocumentReady", Panel.browser, function()
            Panel.ready = true
            if Panel.pending then emit("admin:open", Panel.pending) end
            if callback then callback() end
        end)
    end
    return true
end

local function openPanel(payload)
    Panel.pending = payload or {}
    if ensureBrowser(function() emit("admin:open", Panel.pending) end) then
        setVisible(true)
        triggerServerEvent("HeavyRPG:Admin:request", resourceRoot)
        triggerServerEvent("HeavyRPG:Admin:advancedRequest", resourceRoot)
    end
end

local function closePanel() setVisible(false) end

addEvent("HeavyRPG:Admin:open", true)
addEventHandler("HeavyRPG:Admin:open", resourceRoot, openPanel)

addEvent("HeavyRPG:Admin:data", true)
addEventHandler("HeavyRPG:Admin:data", resourceRoot, function(payload) emit("admin:data", payload or {}) end)

addEvent("HeavyRPG:Admin:advancedData", true)
addEventHandler("HeavyRPG:Admin:advancedData", resourceRoot, function(payload) emit("admin:advancedData", payload or {}) end)

addEvent("HeavyRPG:Admin:spectate", true)
addEventHandler("HeavyRPG:Admin:spectate", resourceRoot, function(target)
    if isElement(target) then
        Panel.spectating = true
        setCameraTarget(target)
        setVisible(false)
        outputChatBox("[APANEL] Spectate aktywny. Otworz /apanel lub uzyj Stop spectate, aby wrocic.", 210, 198, 164)
    else
        Panel.spectating = false
        setCameraTarget(localPlayer)
    end
end)

addEvent("HeavyRPG:UI:admin:close", true)
addEventHandler("HeavyRPG:UI:admin:close", root, closePanel)

addEvent("HeavyRPG:UI:admin:request", true)
addEventHandler("HeavyRPG:UI:admin:request", root, function()
    triggerServerEvent("HeavyRPG:Admin:request", resourceRoot)
    triggerServerEvent("HeavyRPG:Admin:advancedRequest", resourceRoot)
end)

addEvent("HeavyRPG:UI:admin:action", true)
addEventHandler("HeavyRPG:UI:admin:action", root, function(action, payload)
    triggerServerEvent("HeavyRPG:Admin:action", resourceRoot, tostring(action or ""), decodePayload(payload))
end)

addEvent("HeavyRPG:UI:admin:advanced", true)
addEventHandler("HeavyRPG:UI:admin:advanced", root, function(action, payload)
    triggerServerEvent("HeavyRPG:Admin:advanced", resourceRoot, tostring(action or ""), decodePayload(payload))
end)

bindKey("escape", "down", function() if Panel.visible then closePanel() cancelEvent() end end)

bindKey(HRP.Config.ui and HRP.Config.ui.toggleDevToolsKey or "F6", "down", function()
    if Panel.visible and Panel.browser then toggleBrowserDevTools(Panel.browser, true) end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if Panel.spectating then setCameraTarget(localPlayer) end
    setVisible(false)
end)
