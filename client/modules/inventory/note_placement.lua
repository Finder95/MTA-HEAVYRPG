HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientInventory = HRP.ClientInventory or {}
local Inv = HRP.ClientInventory

if not Inv.rawProcessLineOfSight then Inv.rawProcessLineOfSight = processLineOfSight end
if not Inv.rawTriggerServerEvent then Inv.rawTriggerServerEvent = triggerServerEvent end

local rawProcessLineOfSight = Inv.rawProcessLineOfSight
local rawTriggerServerEvent = Inv.rawTriggerServerEvent
local placing = nil
local clickAttached = false
local keyAttached = false
local renderAttached = false
local enterInterceptAttached = false
local placementDepths = { 3.0, 5.0, 8.0, 12.0 }

local function color(r, g, b, a) return tocolor(r, g, b, a or 255) end

local function noteActionOpen()
    local action = Inv.action
    return action and action.item and tostring(action.item.itemId) == "note_page"
end

local function selectedNoteAction()
    local action = Inv.action
    if not action or not action.actions then return nil end
    local selected = tonumber(action.selected) or 1
    return action.actions[selected]
end

local function screenPoint()
    local sx, sy = guiGetScreenSize()
    if isCursorShowing() then
        local cx, cy = getCursorPosition()
        if cx and cy then return cx * sx, cy * sy, sx, sy end
    end
    return sx / 2, sy / 2, sx, sy
end

local function matrixPoint(matrix, lx, ly, lz)
    return lx * matrix[1][1] + ly * matrix[2][1] + lz * matrix[3][1] + matrix[4][1],
        lx * matrix[1][2] + ly * matrix[2][2] + lz * matrix[3][2] + matrix[4][2],
        lx * matrix[1][3] + ly * matrix[2][3] + lz * matrix[3][3] + matrix[4][3]
end

local function vehicleNotePoint(vehicle)
    local vx, vy, vz = getElementPosition(vehicle)
    local minX, minY, minZ, maxX, maxY, maxZ = getElementBoundingBox(vehicle)
    local matrix = getElementMatrix(vehicle)
    if not minX or not matrix then return vx, vy, vz + 1.05 end

    local px, py, pz = getElementPosition(localPlayer)
    local z = minZ + (maxZ - minZ) * 0.68
    local candidates = {
        { 0, maxY * 0.56, z },
        { minX * 0.28, maxY * 0.56, z },
        { maxX * 0.28, maxY * 0.56, z },
        { 0, minY * 0.56, z },
        { minX * 0.28, minY * 0.56, z },
        { maxX * 0.28, minY * 0.56, z }
    }

    local best = nil
    for _, candidate in ipairs(candidates) do
        local wx, wy, wz = matrixPoint(matrix, candidate[1], candidate[2], candidate[3])
        local distance = getDistanceBetweenPoints3D(px, py, pz, wx, wy, wz)
        if not best or distance < best.distance then best = { x = wx, y = wy, z = wz, distance = distance } end
    end

    if best then return best.x, best.y, best.z end
    return vx, vy, vz + 1.05
end

local function nearestVehicle(maxDistance)
    local px, py, pz = getElementPosition(localPlayer)
    local best = nil
    for _, vehicle in ipairs(getElementsWithinRange(px, py, pz, maxDistance or 4.5, "vehicle")) do
        if isElement(vehicle) and isElementStreamedIn(vehicle) then
            local vx, vy, vz = getElementPosition(vehicle)
            local distance = getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz)
            if not best or distance < best.distance then best = { vehicle = vehicle, distance = distance } end
        end
    end
    return best and best.vehicle or nil
end

local function clearActionPanel()
    Inv.action = nil
    Inv.actionScroll = 0
    Inv.prompt = nil
    Inv.editing = false
    Inv.editText = ""
    Inv.actionBounds = {}
end

local function autoPlaceVehicleNote(uid)
    local vehicle = nearestVehicle(4.8)
    if not vehicle then
        outputChatBox("[EQ] Podejdz do pojazdu, zeby zostawic kartke za wycieraczka.", 230, 90, 80)
        return false
    end

    clearActionPanel()
    triggerEvent("HeavyRPG:Inventory:close", resourceRoot)
    local x, y, z = vehicleNotePoint(vehicle)
    rawTriggerServerEvent("HeavyRPG:Inventory:placeNote", resourceRoot, uid, "vehicle", x, y, z, vehicle)
    return true
end

local function handleVehicleNoteEnter(button, press)
    if not press or tostring(button or ""):lower() ~= "enter" then return end
    if not noteActionOpen() or Inv.prompt or Inv.editing then return end
    local selected = selectedNoteAction()
    if not selected or tostring(selected.id or "") ~= "note_page_place_vehicle" then return end
    local item = Inv.action and Inv.action.item
    if not item then return end
    autoPlaceVehicleNote(item.uid)
    cancelEvent()
end

local function rayTarget(px, py, distance)
    local wx, wy, wz = getWorldFromScreenPosition(px, py, distance)
    if wx and wy and wz then return wx, wy, wz end

    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    local dx, dy, dz = lx - cx, ly - cy, lz - cz
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length <= 0.001 then return lx, ly, lz end
    return cx + dx / length * distance, cy + dy / length * distance, cz + dz / length * distance
end

local function cursorHit()
    local px, py = screenPoint()
    local camX, camY, camZ = getCameraMatrix()

    for _, distance in ipairs(placementDepths) do
        local tx, ty, tz = rayTarget(px, py, distance)
        local hit, x, y, z, element, nx, ny, nz = rawProcessLineOfSight(camX, camY, camZ, tx, ty, tz, true, true, true, true, true, false, false, false, localPlayer)
        if hit then return true, x, y, z, element, nx, ny, nz end
    end

    return false
end

local function placementValid(hit)
    return placing and hit == true
end

local function stopPlacement(message)
    if renderAttached then removeEventHandler("onClientRender", root, Inv.drawNotePlacement) renderAttached = false end
    if clickAttached then removeEventHandler("onClientClick", root, Inv.handleNotePlacementClick) clickAttached = false end
    if keyAttached then removeEventHandler("onClientKey", root, Inv.handleNotePlacementKey) keyAttached = false end
    placing = nil
    showCursor(false)
    if message and message ~= "" then outputChatBox("[EQ] " .. tostring(message), 210, 198, 164) end
end

local function startPlacement(uid, mode)
    mode = tostring(mode or "world")
    if mode == "vehicle" then
        autoPlaceVehicleNote(uid)
        return
    end

    placing = { uid = uid, mode = "world" }
    triggerEvent("HeavyRPG:Inventory:close", resourceRoot)
    setTimer(function()
        if not placing then return end
        showCursor(true)
    end, 50, 1)

    if not renderAttached then addEventHandler("onClientRender", root, Inv.drawNotePlacement) renderAttached = true end
    if not clickAttached then addEventHandler("onClientClick", root, Inv.handleNotePlacementClick) clickAttached = true end
    if not keyAttached then addEventHandler("onClientKey", root, Inv.handleNotePlacementKey) keyAttached = true end
    outputChatBox("[EQ] Wybierz miejsce kursorem. LPM - przyklej, PPM/ESC - anuluj.", 210, 198, 164)
end

function Inv.drawNotePlacement()
    if not placing then return end
    local hit, x, y, z = cursorHit()
    local ok = placementValid(hit)
    local mx, my, sx, sy = screenPoint()
    local accent = ok and color(176, 222, 150, 245) or color(230, 90, 80, 245)
    local shadow = color(0, 0, 0, 170)
    local label = ok and "LPM - przyklej kartke tutaj" or "Wskaz miejsce pod kursorem"

    dxDrawLine(mx - 18, my, mx - 6, my, shadow, 4, true)
    dxDrawLine(mx + 6, my, mx + 18, my, shadow, 4, true)
    dxDrawLine(mx, my - 18, mx, my - 6, shadow, 4, true)
    dxDrawLine(mx, my + 6, mx, my + 18, shadow, 4, true)
    dxDrawLine(mx - 18, my, mx - 6, my, accent, 2, true)
    dxDrawLine(mx + 6, my, mx + 18, my, accent, 2, true)
    dxDrawLine(mx, my - 18, mx, my - 6, accent, 2, true)
    dxDrawLine(mx, my + 6, mx, my + 18, accent, 2, true)
    dxDrawText(label, mx - 220, my + 26, mx + 220, my + 54, shadow, 0.82, "default-bold", "center", "center", false, false, true)
    dxDrawText(label, mx - 220, my + 25, mx + 220, my + 53, accent, 0.82, "default-bold", "center", "center", false, false, true)
    dxDrawText("PPM / ESC - anuluj", 0, sy - 92, sx, sy - 62, color(232, 229, 219, 230), 0.78, "default-bold", "center", "center", false, false, true)

    if ok and x and y and z then
        local px, py = getScreenFromWorldPosition(x, y, z + 0.12)
        if px and py then
            dxDrawRectangle(px - 18, py - 12, 36, 24, color(236, 228, 190, 215), true)
            dxDrawRectangle(px - 18, py - 12, 36, 2, color(120, 96, 58, 220), true)
            dxDrawText("kartka", px - 44, py + 14, px + 44, py + 36, color(232, 229, 219, 230), 0.62, "default-bold", "center", "top", false, false, true)
        end
    end
end

function Inv.handleNotePlacementClick(button, state)
    if not placing or state ~= "down" then return end
    if button == "right" then stopPlacement("Anulowano przyklejanie kartki.") cancelEvent() return end
    if button ~= "left" then return end

    local hit, x, y, z, element = cursorHit()
    if not placementValid(hit) then
        outputChatBox("[EQ] Wskaz miejsce pod kursorem.", 230, 90, 80)
        cancelEvent()
        return
    end

    rawTriggerServerEvent("HeavyRPG:Inventory:placeNote", resourceRoot, placing.uid, placing.mode, x, y, z, element)
    stopPlacement("")
    cancelEvent()
end

function Inv.handleNotePlacementKey(button, press)
    if not placing or not press then return end
    button = tostring(button or ""):lower()
    if button == "escape" then stopPlacement("Anulowano przyklejanie kartki.") cancelEvent() end
end

local originalHandleClick = Inv.handleClick
function Inv.handleClick(button, state, ax, ay)
    if button == "left" and state == "down" and noteActionOpen() and not Inv.prompt then
        for _, bound in ipairs(Inv.actionBounds or {}) do
            if ax >= bound.x and ax <= bound.x + bound.w and ay >= bound.y and ay <= bound.y + bound.h then
                local action = Inv.action
                local selected = (action.actions or {})[bound.index]
                if selected and (selected.id == "note_page_place_world" or selected.id == "note_page_place_vehicle") then
                    startPlacement(action.item.uid, selected.id == "note_page_place_vehicle" and "vehicle" or "world")
                    cancelEvent()
                    return
                end
            end
        end
    end

    if originalHandleClick then return originalHandleClick(button, state, ax, ay) end
end

function processLineOfSight(startX, startY, startZ, endX, endY, endZ, checkBuildings, checkVehicles, checkPeds, checkObjects, checkDummies, seeThroughStuff, ignoreSomeObjectsForCamera, shootThroughStuff, ignoredElement, ...)
    if noteActionOpen() and ignoredElement == localPlayer and checkBuildings == true and checkVehicles == true and checkPeds == true and checkObjects == true and checkDummies == true then
        local px, py, pz = getElementPosition(localPlayer)
        return true, px, py, pz + 1.0, nil, 0, 0, 0
    end

    return rawProcessLineOfSight(startX, startY, startZ, endX, endY, endZ, checkBuildings, checkVehicles, checkPeds, checkObjects, checkDummies, seeThroughStuff, ignoreSomeObjectsForCamera, shootThroughStuff, ignoredElement, ...)
end

function triggerServerEvent(eventName, attachedTo, uid, mode, x, y, z, element, ...)
    if eventName == "HeavyRPG:Inventory:placeNote" and noteActionOpen() then
        startPlacement(uid, mode)
        return true
    end

    return rawTriggerServerEvent(eventName, attachedTo, uid, mode, x, y, z, element, ...)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    if not enterInterceptAttached then
        addEventHandler("onClientKey", root, handleVehicleNoteEnter, true, "high+10")
        enterInterceptAttached = true
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if placing then stopPlacement("") end
    if enterInterceptAttached then removeEventHandler("onClientKey", root, handleVehicleNoteEnter) enterInterceptAttached = false end
end)
