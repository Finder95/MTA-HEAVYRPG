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
local placementDepths = { 3.0, 5.0, 8.0, 12.0 }

local function color(r, g, b, a) return tocolor(r, g, b, a or 255) end
local function clamp(value, minValue, maxValue) value = tonumber(value) or minValue if value < minValue then return minValue end if value > maxValue then return maxValue end return value end

local function noteActionOpen()
    local action = Inv.action
    return action and action.item and tostring(action.item.itemId) == "note_page"
end

local function screenPoint()
    local sx, sy = guiGetScreenSize()
    if isCursorShowing() then
        local cx, cy = getCursorPosition()
        if cx and cy then return cx * sx, cy * sy, sx, sy end
    end
    return sx / 2, sy / 2, sx, sy
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

local function matrixPoint(matrix, lx, ly, lz)
    return lx * matrix[1][1] + ly * matrix[2][1] + lz * matrix[3][1] + matrix[4][1],
        lx * matrix[1][2] + ly * matrix[2][2] + lz * matrix[3][2] + matrix[4][2],
        lx * matrix[1][3] + ly * matrix[2][3] + lz * matrix[3][3] + matrix[4][3]
end

local function vehicleCandidatePoint(vehicle, cursorX, cursorY)
    local minX, minY, minZ, maxX, maxY, maxZ = getElementBoundingBox(vehicle)
    local matrix = getElementMatrix(vehicle)
    if not minX or not matrix then
        local vx, vy, vz = getElementPosition(vehicle)
        return vx, vy, vz + 1.05, 999
    end

    local z = minZ + (maxZ - minZ) * 0.70
    local candidates = {
        { 0, maxY * 0.62, z },
        { minX * 0.34, maxY * 0.62, z },
        { maxX * 0.34, maxY * 0.62, z },
        { 0, minY * 0.62, z },
        { minX * 0.34, minY * 0.62, z },
        { maxX * 0.34, minY * 0.62, z },
        { 0, maxY * 0.35, minZ + (maxZ - minZ) * 0.52 },
        { 0, minY * 0.35, minZ + (maxZ - minZ) * 0.52 }
    }

    local bestX, bestY, bestZ, bestScreenDistance = nil, nil, nil, 99999
    for _, candidate in ipairs(candidates) do
        local wx, wy, wz = matrixPoint(matrix, candidate[1], candidate[2], candidate[3])
        local sx, sy = getScreenFromWorldPosition(wx, wy, wz, 0.1, true)
        local screenDistance = sx and math.sqrt((sx - cursorX) * (sx - cursorX) + (sy - cursorY) * (sy - cursorY)) or 9999
        if screenDistance < bestScreenDistance then
            bestX, bestY, bestZ, bestScreenDistance = wx, wy, wz, screenDistance
        end
    end

    return bestX, bestY, bestZ, bestScreenDistance
end

local function vehicleScreenFallback(cursorX, cursorY, screenX, screenY)
    if not placing or placing.mode ~= "vehicle" then return false end

    local px, py, pz = getElementPosition(localPlayer)
    local threshold = clamp(math.min(screenX, screenY) * 0.12, 130, 220)
    local best = nil

    for _, vehicle in ipairs(getElementsWithinRange(px, py, pz, 7.0, "vehicle")) do
        if isElement(vehicle) and isElementStreamedIn(vehicle) then
            local wx, wy, wz, screenDistance = vehicleCandidatePoint(vehicle, cursorX, cursorY)
            local vx, vy, vz = getElementPosition(vehicle)
            local vehicleDistance = getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz)
            local pointDistance = wx and getDistanceBetweenPoints3D(px, py, pz, wx, wy, wz) or vehicleDistance
            if vehicleDistance <= 6.5 and pointDistance <= 7.0 then
                local score = screenDistance + vehicleDistance * 10
                if (screenDistance <= threshold or vehicleDistance <= 3.8) and (not best or score < best.score) then
                    best = { score = score, x = wx or vx, y = wy or vy, z = wz or (vz + 1.05), vehicle = vehicle }
                end
            end
        end
    end

    if best then return true, best.x, best.y, best.z, best.vehicle, 0, 0, 1 end
    return false
end

local function cursorHit()
    local px, py, sx, sy = screenPoint()
    local camX, camY, camZ = getCameraMatrix()

    for _, distance in ipairs(placementDepths) do
        local tx, ty, tz = rayTarget(px, py, distance)
        local hit, x, y, z, element, nx, ny, nz = rawProcessLineOfSight(camX, camY, camZ, tx, ty, tz, true, true, true, true, true, false, false, false, localPlayer)
        if hit then
            if not placing or placing.mode ~= "vehicle" then return true, x, y, z, element, nx, ny, nz end
            if isElement(element) and getElementType(element) == "vehicle" then return true, x, y, z, element, nx, ny, nz end
        end
    end

    if placing and placing.mode == "vehicle" then
        return vehicleScreenFallback(px, py, sx, sy)
    end

    return false
end

local function placementValid(hit, element)
    if not placing or not hit then return false end
    if placing.mode == "vehicle" then return isElement(element) and getElementType(element) == "vehicle" end
    return true
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
    placing = { uid = uid, mode = tostring(mode or "world") }
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
    local hit, x, y, z, element = cursorHit()
    local ok = placementValid(hit, element)
    local mx, my, sx, sy = screenPoint()
    local accent = ok and color(176, 222, 150, 245) or color(230, 90, 80, 245)
    local shadow = color(0, 0, 0, 170)
    local label = ok and "LPM - zostaw kartke przy pojezdzie" or (placing.mode == "vehicle" and "Podejdz do pojazdu i wskaz jego przod/szybe" or "Wskaz miejsce pod kursorem")

    dxDrawLine(mx - 18, my, mx - 6, my, shadow, 4, true)
    dxDrawLine(mx + 6, my, mx + 18, my, shadow, 4, true)
    dxDrawLine(mx, my - 18, mx, my - 6, shadow, 4, true)
    dxDrawLine(mx, my + 6, mx, my + 18, shadow, 4, true)
    dxDrawLine(mx - 18, my, mx - 6, my, accent, 2, true)
    dxDrawLine(mx + 6, my, mx + 18, my, accent, 2, true)
    dxDrawLine(mx, my - 18, mx, my - 6, accent, 2, true)
    dxDrawLine(mx, my + 6, mx, my + 18, accent, 2, true)
    dxDrawText(label, mx - 260, my + 26, mx + 260, my + 54, shadow, 0.82, "default-bold", "center", "center", false, false, true)
    dxDrawText(label, mx - 260, my + 25, mx + 260, my + 53, accent, 0.82, "default-bold", "center", "center", false, false, true)
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
    if not placementValid(hit, element) then
        outputChatBox(placing.mode == "vehicle" and "[EQ] Podejdz blizej do pojazdu i wskaz jego przod albo szybe." or "[EQ] Wskaz miejsce pod kursorem.", 230, 90, 80)
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

addEventHandler("onClientResourceStop", resourceRoot, function()
    if placing then stopPlacement("") end
end)