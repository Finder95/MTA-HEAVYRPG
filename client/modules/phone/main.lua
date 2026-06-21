HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientPhone = HRP.ClientPhone or {
    browser = nil,
    ready = false,
    visible = false,
    pendingPayload = nil,
    sx = 0,
    sy = 0,
    x = 0,
    y = 0,
    w = 390,
    h = 780,
    lastCursorX = 0,
    lastCursorY = 0
}

local Phone = HRP.ClientPhone

local function decodePayload(jsonPayload)
    if type(jsonPayload) ~= "string" then return {} end
    local data = fromJSON(jsonPayload)
    return type(data) == "table" and data or {}
end

local function updateBounds()
    Phone.sx, Phone.sy = guiGetScreenSize()
    local scale = math.min(Phone.sx / 1920, Phone.sy / 1080)
    if scale < 0.70 then scale = 0.70 end
    if scale > 0.92 then scale = 0.92 end
    Phone.w = math.floor(390 * scale)
    Phone.h = math.floor(780 * scale)
    local margin = math.floor(34 * scale)
    Phone.x = math.floor(Phone.sx - Phone.w - margin)
    Phone.y = math.floor(Phone.sy - Phone.h - margin)
    if Phone.x < 18 then Phone.x = math.floor((Phone.sx - Phone.w) / 2) end
    if Phone.y < 18 then Phone.y = 18 end
end

local function isInside(absX, absY)
    return absX >= Phone.x and absX <= Phone.x + Phone.w and absY >= Phone.y and absY <= Phone.y + Phone.h
end

local function toBrowserPoint(absX, absY)
    return absX - Phone.x, absY - Phone.y
end

local function renderPhone()
    if Phone.visible and Phone.browser then
        dxDrawImage(Phone.x, Phone.y, Phone.w, Phone.h, Phone.browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
    end
end

local function cursorMove(_, _, absX, absY)
    if not Phone.visible or not Phone.browser then return end
    Phone.lastCursorX, Phone.lastCursorY = absX, absY
    if not isInside(absX, absY) then return end
    local bx, by = toBrowserPoint(absX, absY)
    injectBrowserMouseMove(Phone.browser, bx, by)
end

local function cursorClick(button, state, absX, absY)
    if not Phone.visible or not Phone.browser then return end
    if button ~= "left" and button ~= "right" and button ~= "middle" then return end
    if not isInside(absX, absY) then return end
    if state == "down" then focusBrowser(Phone.browser) end
    local bx, by = toBrowserPoint(absX, absY)
    injectBrowserMouseMove(Phone.browser, bx, by)
    if state == "down" then injectBrowserMouseDown(Phone.browser, button) else injectBrowserMouseUp(Phone.browser, button) end
end

local function mouseWheel(key)
    if not Phone.visible or not Phone.browser then return end
    if not isInside(Phone.lastCursorX, Phone.lastCursorY) then return end
    injectBrowserMouseWheel(Phone.browser, key == "mouse_wheel_up" and 1 or -1, 0)
end

local function call(functionName, payload)
    if not Phone.browser or not Phone.ready then return false end
    local json = toJSON(payload or {}, true) or "{}"
    return executeBrowserJavascript(Phone.browser, tostring(functionName) .. "(" .. json .. ");")
end

local function emit(name, detail)
    return call("window.HeavyRPGPhone && window.HeavyRPGPhone.receive", { name = name, detail = detail or {} })
end

local function setVisible(state)
    state = state == true
    if Phone.visible == state then return end
    Phone.visible = state
    showCursor(state)
    if Phone.browser then focusBrowser(state and Phone.browser or nil) end
    if state then
        updateBounds()
        addEventHandler("onClientRender", root, renderPhone)
        addEventHandler("onClientCursorMove", root, cursorMove)
        addEventHandler("onClientClick", root, cursorClick)
        bindKey("mouse_wheel_up", "down", mouseWheel)
        bindKey("mouse_wheel_down", "down", mouseWheel)
    else
        removeEventHandler("onClientRender", root, renderPhone)
        removeEventHandler("onClientCursorMove", root, cursorMove)
        removeEventHandler("onClientClick", root, cursorClick)
        unbindKey("mouse_wheel_up", "down", mouseWheel)
        unbindKey("mouse_wheel_down", "down", mouseWheel)
    end
end

local function ensureBrowser(callback)
    if Phone.browser and Phone.ready then if callback then callback() end return true end
    updateBounds()
    if not Phone.browser then
        Phone.browser = createBrowser(math.max(1, Phone.w), math.max(1, Phone.h), true, true)
        if not Phone.browser then outputDebugString("[HeavyRPG:Phone] Nie udalo sie utworzyc CEF telefonu.", 1) return false end
        addEventHandler("onClientBrowserCreated", Phone.browser, function()
            loadBrowserURL(source, HRP.Config.ui.phoneUrl or "http://mta/local/html/phone/index.html")
        end)
        addEventHandler("onClientBrowserDocumentReady", Phone.browser, function()
            Phone.ready = true
            if Phone.pendingPayload then emit("phone:open", Phone.pendingPayload) end
            if callback then callback() end
        end)
    end
    return true
end

local function openPhone(payload)
    Phone.pendingPayload = payload or {}
    if ensureBrowser(function() emit("phone:open", Phone.pendingPayload) end) then setVisible(true) end
end

local function closePhone()
    setVisible(false)
end

addEvent("HeavyRPG:Phone:open", true)
addEventHandler("HeavyRPG:Phone:open", resourceRoot, function(payload) openPhone(payload or {}) end)

addEvent("HeavyRPG:Phone:data", true)
addEventHandler("HeavyRPG:Phone:data", resourceRoot, function(payload)
    Phone.pendingPayload = payload or Phone.pendingPayload or {}
    emit("phone:data", Phone.pendingPayload)
end)

addEvent("HeavyRPG:Phone:callStatus", true)
addEventHandler("HeavyRPG:Phone:callStatus", resourceRoot, function(payload)
    emit("phone:callStatus", payload or {})
end)

addEvent("HeavyRPG:UI:phone:close", true)
addEventHandler("HeavyRPG:UI:phone:close", root, closePhone)

addEvent("HeavyRPG:UI:phone:request", true)
addEventHandler("HeavyRPG:UI:phone:request", root, function() triggerServerEvent("HeavyRPG:Phone:request", resourceRoot) end)

addEvent("HeavyRPG:UI:phone:addContact", true)
addEventHandler("HeavyRPG:UI:phone:addContact", root, function(jsonPayload)
    triggerServerEvent("HeavyRPG:Phone:addContact", resourceRoot, decodePayload(jsonPayload))
end)

addEvent("HeavyRPG:UI:phone:sendSms", true)
addEventHandler("HeavyRPG:UI:phone:sendSms", root, function(jsonPayload)
    triggerServerEvent("HeavyRPG:Phone:sendSms", resourceRoot, decodePayload(jsonPayload))
end)

addEvent("HeavyRPG:UI:phone:call", true)
addEventHandler("HeavyRPG:UI:phone:call", root, function(jsonPayload)
    triggerServerEvent("HeavyRPG:Phone:call", resourceRoot, decodePayload(jsonPayload))
end)

bindKey("backspace", "down", function()
    if Phone.visible then emit("phone:back", {}) cancelEvent() end
end)

bindKey("escape", "down", function()
    if Phone.visible then closePhone() cancelEvent() end
end)

bindKey(HRP.Config.ui.toggleDevToolsKey, "down", function()
    if Phone.browser and Phone.visible then toggleBrowserDevTools(Phone.browser, true) end
end)