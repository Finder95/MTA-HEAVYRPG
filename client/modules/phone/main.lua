HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientPhone = HRP.ClientPhone or {
    browser = nil,
    ready = false,
    visible = false,
    renderPaused = false,
    pendingPayload = nil,
    sx = 0,
    sy = 0,
    x = 0,
    y = 0,
    w = 390,
    h = 780,
    lastCursorX = 0,
    lastCursorY = 0,
    selfieSource = nil,
    cameraMode = false,
    cameraKind = "photo",
    cameraZoom = 1,
    oldAlpha = nil
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

local function clamp(v, a, b)
    v = tonumber(v) or a
    if v < a then return a end
    if v > b then return b end
    return v
end

local function isInside(absX, absY)
    return absX >= Phone.x and absX <= Phone.x + Phone.w and absY >= Phone.y and absY <= Phone.y + Phone.h
end

local function toBrowserPoint(absX, absY)
    return absX - Phone.x, absY - Phone.y
end

local function renderPhone()
    if Phone.visible and not Phone.renderPaused and Phone.browser then
        dxDrawImage(Phone.x, Phone.y, Phone.w, Phone.h, Phone.browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
    end
end

local function cursorMove(_, _, absX, absY)
    if not Phone.visible or Phone.renderPaused or not Phone.browser then return end
    Phone.lastCursorX, Phone.lastCursorY = absX, absY
    if not isInside(absX, absY) then return end
    local bx, by = toBrowserPoint(absX, absY)
    injectBrowserMouseMove(Phone.browser, bx, by)
end

local function cursorClick(button, state, absX, absY)
    if not Phone.visible or Phone.renderPaused or not Phone.browser then return end
    if button ~= "left" and button ~= "right" and button ~= "middle" then return end
    if not isInside(absX, absY) then return end
    if state == "down" then focusBrowser(Phone.browser) end
    local bx, by = toBrowserPoint(absX, absY)
    injectBrowserMouseMove(Phone.browser, bx, by)
    if state == "down" then injectBrowserMouseDown(Phone.browser, button) else injectBrowserMouseUp(Phone.browser, button) end
end

local function mouseWheel(key)
    if not Phone.visible or Phone.renderPaused or not Phone.browser then return end
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

local function cameraPayload(payload)
    payload = type(payload) == "string" and fromJSON(payload) or payload
    payload = type(payload) == "table" and payload or {}
    return tostring(payload.mode or Phone.cameraKind or "photo"), clamp(payload.zoom or Phone.cameraZoom or 1, 1, 4)
end

local function selfieStatus(ok, message, path)
    emit("phone:selfieStatus", { ok = ok == true, message = tostring(message or ""), path = tostring(path or "") })
end

local function restorePlayerAlpha()
    if Phone.oldAlpha ~= nil and isElement(localPlayer) then setElementAlpha(localPlayer, Phone.oldAlpha) end
    Phone.oldAlpha = nil
end

local function stopSelfieCamera()
    if not Phone.cameraMode then restorePlayerAlpha() return end
    Phone.cameraMode = false
    Phone.cameraKind = "photo"
    restorePlayerAlpha()
    setCameraTarget(localPlayer)
end

local function applyPhotoCamera(kind, zoom)
    if not isElement(localPlayer) then return end
    kind = kind == "selfie" and "selfie" or "photo"
    zoom = clamp(zoom, 1, 4)
    Phone.cameraKind = kind
    Phone.cameraZoom = zoom

    local px, py, pz = getElementPosition(localPlayer)
    local _, _, rz = getElementRotation(localPlayer)
    local rad = math.rad(rz or 0)
    local forwardX = -math.sin(rad)
    local forwardY = math.cos(rad)
    local fov = clamp(72 - ((zoom - 1) * 14), 30, 72)

    if kind == "selfie" then
        restorePlayerAlpha()
        setCameraMatrix(px + forwardX * 2.25, py + forwardY * 2.25, pz + 0.92, px, py, pz + 0.72, 0, fov)
        selfieStatus(true, "Tryb selfie aktywny. Zoom: " .. string.format("%.2f", zoom) .. "x.")
    else
        if Phone.oldAlpha == nil then Phone.oldAlpha = getElementAlpha(localPlayer) end
        setElementAlpha(localPlayer, 0)
        setCameraMatrix(px + forwardX * 0.42, py + forwardY * 0.42, pz + 0.78, px + forwardX * 12.0, py + forwardY * 12.0, pz + 0.84, 0, fov)
        selfieStatus(true, "Tryb zdjecia aktywny. Twoja postac jest ukryta w kadrze. Zoom: " .. string.format("%.2f", zoom) .. "x.")
    end
    Phone.cameraMode = true
end

local function startSelfieCamera(payload)
    local kind, zoom = cameraPayload(payload)
    applyPhotoCamera(kind, zoom)
end

local function setVisible(state)
    state = state == true
    if Phone.visible == state then return end
    Phone.visible = state
    Phone.renderPaused = false
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
    stopSelfieCamera()
    setVisible(false)
end

local function captureSelfieNow()
    local sx, sy = guiGetScreenSize()
    if Phone.selfieSource and isElement(Phone.selfieSource) then destroyElement(Phone.selfieSource) end
    Phone.selfieSource = dxCreateScreenSource(sx, sy)
    if not Phone.selfieSource then Phone.renderPaused = false selfieStatus(false, "Aparat nie mogl utworzyc zrodla obrazu.") return end

    dxUpdateScreenSource(Phone.selfieSource, true)
    local pixels = dxGetTexturePixels(Phone.selfieSource)
    if not pixels then Phone.renderPaused = false selfieStatus(false, "Aparat nie mogl pobrac obrazu. Sprawdz ustawienia screen upload.") return end

    local jpeg = dxConvertPixels(pixels, "jpeg", 88)
    if not jpeg then Phone.renderPaused = false selfieStatus(false, "Aparat nie mogl zapisac JPEG.") return end

    local timestamp = getRealTime().timestamp or getTickCount()
    local prefix = Phone.cameraKind == "selfie" and "phone_selfie_" or "phone_photo_"
    local path = prefix .. tostring(timestamp) .. "_" .. tostring(getTickCount()) .. ".jpg"
    local file = fileCreate(path)
    if not file then Phone.renderPaused = false selfieStatus(false, "Nie udalo sie utworzyc pliku zdjecia.") return end
    fileWrite(file, jpeg)
    fileClose(file)
    Phone.renderPaused = false
    selfieStatus(true, "Zdjecie zapisane: " .. path, path)
end

local function takeSelfie(payload)
    local kind, zoom = cameraPayload(payload)
    applyPhotoCamera(kind, zoom)
    Phone.renderPaused = true
    selfieStatus(true, "Chowam telefon i robie zdjecie...")
    setTimer(captureSelfieNow, 180, 1)
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

addEvent("HeavyRPG:UI:phone:cameraStart", true)
addEventHandler("HeavyRPG:UI:phone:cameraStart", root, startSelfieCamera)

addEvent("HeavyRPG:UI:phone:cameraStop", true)
addEventHandler("HeavyRPG:UI:phone:cameraStop", root, stopSelfieCamera)

addEvent("HeavyRPG:UI:phone:selfie", true)
addEventHandler("HeavyRPG:UI:phone:selfie", root, function(payload) takeSelfie(decodePayload(payload)) end)

bindKey("backspace", "down", function()
    if Phone.visible then emit("phone:back", {}) cancelEvent() end
end)

bindKey("escape", "down", function()
    if Phone.visible then closePhone() cancelEvent() end
end)

bindKey(HRP.Config.ui.toggleDevToolsKey, "down", function()
    if Phone.browser and Phone.visible then toggleBrowserDevTools(Phone.browser, true) end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    stopSelfieCamera()
    if Phone.selfieSource and isElement(Phone.selfieSource) then destroyElement(Phone.selfieSource) end
end)