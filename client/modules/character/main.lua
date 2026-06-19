HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientCharacter = HRP.ClientCharacter or {
    browser = nil,
    ready = false,
    visible = false,
    pendingPayload = nil,
    previewPed = nil,
    previewConfig = nil,
    envApplied = false,
    oldHour = nil,
    oldMinute = nil,
    oldWeather = nil,
    oldChatVisible = nil,
    sx = 0,
    sy = 0,
    x = 0,
    y = 0,
    w = 420,
    h = 640,
    lastCursorX = 0,
    lastCursorY = 0,
    skins = {},
    selectedSkin = nil
}

local Creator = HRP.ClientCharacter
local chatKeys = { t = true, y = true, u = true, f6 = true }

local function decodePayload(jsonPayload)
    if type(jsonPayload) ~= "string" then return {} end
    local data = fromJSON(jsonPayload)
    if type(data) ~= "table" then return {} end
    return data
end

local function normalizeSkins(value, fallback)
    local list = {}

    if type(value) == "table" then
        for key, skin in pairs(value) do
            local numericKey = tonumber(key) or 0
            list[#list + 1] = { order = numericKey, skin = tonumber(skin) }
        end
    end

    table.sort(list, function(a, b) return a.order < b.order end)

    local normalized = {}
    for _, entry in ipairs(list) do
        if entry.skin and entry.skin >= 0 then
            normalized[#normalized + 1] = entry.skin
        end
    end

    if #normalized == 0 then
        normalized[1] = tonumber(fallback) or HRP.Config.character.defaultSkin or 46
    end

    return normalized
end

local function updateBounds()
    Creator.sx, Creator.sy = guiGetScreenSize()
    Creator.w = math.min(420, math.max(320, Creator.sx - 48))
    Creator.h = math.min(640, math.max(440, Creator.sy - 48))
    Creator.x = math.floor(Creator.sx - Creator.w - 42)
    Creator.y = math.floor((Creator.sy - Creator.h) / 2)

    if Creator.x < 24 then Creator.x = 24 end
end

local function isInsidePanel(absX, absY)
    return absX >= Creator.x and absX <= Creator.x + Creator.w and absY >= Creator.y and absY <= Creator.y + Creator.h
end

local function toBrowserPoint(absX, absY)
    return absX - Creator.x, absY - Creator.y
end

local function applyPreviewAnimation()
    if not Creator.previewPed or not isElement(Creator.previewPed) then return end

    local anim = (HRP.Config.character.preview and HRP.Config.character.preview.animation) or {}
    setPedAnimation(Creator.previewPed, anim.block or "DEALER", anim.name or "DEALER_IDLE", -1, true, false, false, false)
end

local function destroyPreviewPed()
    if Creator.previewPed and isElement(Creator.previewPed) then
        destroyElement(Creator.previewPed)
    end
    Creator.previewPed = nil
end

local function applyCreatorEnvironment()
    if Creator.envApplied then return end

    if getTime then
        Creator.oldHour, Creator.oldMinute = getTime()
    end

    if getWeather then
        Creator.oldWeather = getWeather()
    end

    if isChatVisible then
        Creator.oldChatVisible = isChatVisible()
    end

    Creator.envApplied = true
    setTime(12, 0)
    if setWeather then setWeather(0) end
    if showChat then showChat(false) end
    showPlayerHudComponent("radar", false)
    showPlayerHudComponent("area_name", false)
    showPlayerHudComponent("vehicle_name", false)

    if resetSkyGradient then resetSkyGradient() end
    if setCloudsEnabled then setCloudsEnabled(false) end
    if setFarClipDistance then setFarClipDistance(120) end
    if setFogDistance then setFogDistance(80) end
end

local function restoreCreatorEnvironment()
    if not Creator.envApplied then return end

    Creator.envApplied = false
    if showChat then showChat(Creator.oldChatVisible ~= false) end
    showPlayerHudComponent("radar", true)
    showPlayerHudComponent("area_name", true)
    showPlayerHudComponent("vehicle_name", true)

    if Creator.oldHour and Creator.oldMinute and setTime then
        setTime(Creator.oldHour, Creator.oldMinute)
    end

    if Creator.oldWeather and setWeather then
        setWeather(Creator.oldWeather)
    end

    if resetSkyGradient then resetSkyGradient() end
    if setCloudsEnabled then setCloudsEnabled(true) end
    if resetFarClipDistance then resetFarClipDistance() end
    if resetFogDistance then resetFogDistance() end

    Creator.oldHour = nil
    Creator.oldMinute = nil
    Creator.oldWeather = nil
    Creator.oldChatVisible = nil
end

local function createPreviewPed(skin)
    local preview = Creator.previewConfig or HRP.Config.character.preview
    skin = tonumber(skin) or Creator.selectedSkin or HRP.Config.character.defaultSkin
    Creator.selectedSkin = skin

    destroyPreviewPed()
    Creator.previewPed = createPed(skin, preview.x, preview.y, preview.z, preview.rotation or 0)
    if Creator.previewPed then
        setElementInterior(Creator.previewPed, preview.interior or 0)
        setElementDimension(Creator.previewPed, preview.dimension or 0)
        setElementRotation(Creator.previewPed, 0, 0, preview.rotation or 0)
        setElementFrozen(Creator.previewPed, true)
        applyPreviewAnimation()
    end
end

local function renderCreator()
    if Creator.visible and Creator.browser then
        dxDrawImage(Creator.x, Creator.y, Creator.w, Creator.h, Creator.browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
    end
end

local function cursorMove(_, _, absX, absY)
    if not Creator.visible or not Creator.browser then return end
    Creator.lastCursorX, Creator.lastCursorY = absX, absY
    if not isInsidePanel(absX, absY) then return end

    local browserX, browserY = toBrowserPoint(absX, absY)
    injectBrowserMouseMove(Creator.browser, browserX, browserY)
end

local function cursorClick(button, state, absX, absY)
    if not Creator.visible or not Creator.browser then return end
    if button ~= "left" and button ~= "right" and button ~= "middle" then return end
    if not isInsidePanel(absX, absY) then return end

    if state == "down" then
        focusBrowser(Creator.browser)
    end

    local browserX, browserY = toBrowserPoint(absX, absY)
    injectBrowserMouseMove(Creator.browser, browserX, browserY)
    if state == "down" then
        injectBrowserMouseDown(Creator.browser, button)
    else
        injectBrowserMouseUp(Creator.browser, button)
    end
end

local function mouseWheel(key)
    if not Creator.visible or not Creator.browser then return end
    if not isInsidePanel(Creator.lastCursorX, Creator.lastCursorY) then return end

    local delta = key == "mouse_wheel_up" and 1 or -1
    injectBrowserMouseWheel(Creator.browser, delta, 0)
end

local function suppressCreatorGameKeys(button, press)
    if not Creator.visible or not press then return end
    if chatKeys[tostring(button or ""):lower()] then
        cancelEvent()
    end
end

local function emit(name, detail)
    if not Creator.browser or not Creator.ready then return false end

    local json = toJSON(detail or {}, true) or "{}"
    local script = "window.HeavyRPGCharacter && window.HeavyRPGCharacter.receive(" .. HRP.Utils.jsQuote(name) .. ", " .. json .. ");"
    return executeBrowserJavascript(Creator.browser, script)
end

local function setPreviewSkin(skin)
    createPreviewPed(skin)
    emit("creator:setSkin", { skin = Creator.selectedSkin })
end

local function setupPreview(payload)
    local preview = payload.preview or HRP.Config.character.preview
    local camera = preview.camera or HRP.Config.character.preview.camera
    local skin = tonumber(payload.defaultSkin) or HRP.Config.character.defaultSkin

    Creator.previewConfig = preview
    Creator.skins = normalizeSkins(payload.skins or HRP.Config.character.skins, skin)
    Creator.selectedSkin = skin

    applyCreatorEnvironment()
    createPreviewPed(skin)

    setElementInterior(localPlayer, preview.interior or 0)
    setElementDimension(localPlayer, preview.dimension or 0)
    setElementPosition(localPlayer, preview.x, preview.y, preview.z - 20)
    setElementFrozen(localPlayer, true)
    setCameraInterior(preview.interior or 0)
    setCameraMatrix(camera[1], camera[2], camera[3], camera[4], camera[5], camera[6])
    fadeCamera(true, 0.5)
end

local function selectPreviewOffset(offset)
    if not Creator.visible or not Creator.skins or #Creator.skins == 0 then return end

    local currentIndex = 1
    for index, skin in ipairs(Creator.skins) do
        if tonumber(skin) == tonumber(Creator.selectedSkin) then
            currentIndex = index
            break
        end
    end

    local nextIndex = currentIndex + offset
    if nextIndex < 1 then nextIndex = #Creator.skins end
    if nextIndex > #Creator.skins then nextIndex = 1 end

    setPreviewSkin(Creator.skins[nextIndex])
end

local function previewPreviousSkin()
    selectPreviewOffset(-1)
end

local function previewNextSkin()
    selectPreviewOffset(1)
end

local function setVisible(state)
    state = state == true
    if Creator.visible == state then return end

    Creator.visible = state
    showCursor(state)

    if Creator.browser then
        focusBrowser(state and Creator.browser or nil)
    end

    if state then
        updateBounds()
        addEventHandler("onClientRender", root, renderCreator)
        addEventHandler("onClientCursorMove", root, cursorMove)
        addEventHandler("onClientClick", root, cursorClick)
        addEventHandler("onClientKey", root, suppressCreatorGameKeys)
        bindKey("mouse_wheel_up", "down", mouseWheel)
        bindKey("mouse_wheel_down", "down", mouseWheel)
        bindKey("arrow_l", "down", previewPreviousSkin)
        bindKey("arrow_r", "down", previewNextSkin)
    else
        removeEventHandler("onClientRender", root, renderCreator)
        removeEventHandler("onClientCursorMove", root, cursorMove)
        removeEventHandler("onClientClick", root, cursorClick)
        removeEventHandler("onClientKey", root, suppressCreatorGameKeys)
        unbindKey("mouse_wheel_up", "down", mouseWheel)
        unbindKey("mouse_wheel_down", "down", mouseWheel)
        unbindKey("arrow_l", "down", previewPreviousSkin)
        unbindKey("arrow_r", "down", previewNextSkin)
    end
end

local function ensureBrowser(callback)
    if Creator.browser and Creator.ready then
        if callback then callback() end
        return true
    end

    updateBounds()

    if not Creator.browser then
        Creator.browser = createBrowser(math.max(1, Creator.w), math.max(1, Creator.h), true, true)
        if not Creator.browser then
            outputDebugString("[HeavyRPG:Character] Nie udalo sie utworzyc CEF kreatora.", 1)
            return false
        end

        addEventHandler("onClientBrowserCreated", Creator.browser, function()
            loadBrowserURL(source, HRP.Config.ui.characterUrl)
        end)

        addEventHandler("onClientBrowserDocumentReady", Creator.browser, function()
            Creator.ready = true
            if Creator.pendingPayload then
                emit("creator:show", Creator.pendingPayload)
            end
            if callback then callback() end
        end)
    end

    return true
end

local function showCreator(payload)
    payload = payload or {}
    Creator.pendingPayload = payload
    setupPreview(payload)

    if ensureBrowser(function()
        emit("creator:show", payload)
    end) then
        setVisible(true)
    end
end

local function hideCreator()
    setVisible(false)
    destroyPreviewPed()
    restoreCreatorEnvironment()
    Creator.pendingPayload = nil
    Creator.previewConfig = nil
end

addEvent("HeavyRPG:UI:character:prevSkin", true)
addEventHandler("HeavyRPG:UI:character:prevSkin", root, previewPreviousSkin)

addEvent("HeavyRPG:UI:character:nextSkin", true)
addEventHandler("HeavyRPG:UI:character:nextSkin", root, previewNextSkin)

addEvent("HeavyRPG:UI:character:previewSkin", true)
addEventHandler("HeavyRPG:UI:character:previewSkin", root, function(jsonPayload)
    local payload = decodePayload(jsonPayload)
    setPreviewSkin(payload.skin)
end)

addEvent("HeavyRPG:UI:character:create", true)
addEventHandler("HeavyRPG:UI:character:create", root, function(jsonPayload)
    local payload = decodePayload(jsonPayload)
    if not payload.firstname or not payload.lastname then
        emit("creator:response", { ok = false, message = "Niepoprawne dane formularza. Sprobuj ponownie." })
        return
    end

    local sent = triggerServerEvent("HeavyRPG:Character:create", resourceRoot, payload)
    if sent == false then
        emit("creator:response", { ok = false, message = "Nie udalo sie wyslac danych do serwera." })
    end
end)

addEvent("HeavyRPG:Character:showCreator", true)
addEventHandler("HeavyRPG:Character:showCreator", resourceRoot, function(payload)
    showCreator(payload or {})
end)

addEvent("HeavyRPG:Character:hideCreator", true)
addEventHandler("HeavyRPG:Character:hideCreator", resourceRoot, function()
    hideCreator()
end)

addEvent("HeavyRPG:Character:response", true)
addEventHandler("HeavyRPG:Character:response", resourceRoot, function(ok, message, character)
    emit("creator:response", { ok = ok, message = message, character = character or {} })
end)

bindKey(HRP.Config.ui.toggleDevToolsKey, "down", function()
    if Creator.browser and Creator.visible then
        toggleBrowserDevTools(Creator.browser, true)
    end
end)
