HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.ClientInventory = HRP.ClientInventory or {}

if not HRP.ClientInventory.rawProcessLineOfSight then
    HRP.ClientInventory.rawProcessLineOfSight = processLineOfSight
end

local rawProcessLineOfSight = HRP.ClientInventory.rawProcessLineOfSight
local placementDepths = { 3.0, 5.0, 8.0, 12.0 }

local function cameraRayTarget(distance)
    local sx, sy = guiGetScreenSize()
    local wx, wy, wz = getWorldFromScreenPosition(sx / 2, sy / 2, distance)
    if wx and wy and wz then return wx, wy, wz end

    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    local dx, dy, dz = lx - cx, ly - cy, lz - cz
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length <= 0.001 then return lx, ly, lz end

    return cx + dx / length * distance, cy + dy / length * distance, cz + dz / length * distance
end

local function shouldRetryForInventoryPlacement(checkBuildings, checkVehicles, checkPeds, checkObjects, checkDummies, ignoredElement)
    return ignoredElement == localPlayer
        and checkBuildings == true
        and checkVehicles == true
        and checkPeds == true
        and checkObjects == true
        and checkDummies == true
end

function processLineOfSight(startX, startY, startZ, endX, endY, endZ, checkBuildings, checkVehicles, checkPeds, checkObjects, checkDummies, seeThroughStuff, ignoreSomeObjectsForCamera, shootThroughStuff, ignoredElement, ...)
    local hit, x, y, z, element, nx, ny, nz, material, lighting, piece, worldModelId, worldModelPositionX, worldModelPositionY, worldModelPositionZ, worldModelRotationX, worldModelRotationY, worldModelRotationZ, worldLODModelId = rawProcessLineOfSight(startX, startY, startZ, endX, endY, endZ, checkBuildings, checkVehicles, checkPeds, checkObjects, checkDummies, seeThroughStuff, ignoreSomeObjectsForCamera, shootThroughStuff, ignoredElement, ...)

    if hit or not shouldRetryForInventoryPlacement(checkBuildings, checkVehicles, checkPeds, checkObjects, checkDummies, ignoredElement) then
        return hit, x, y, z, element, nx, ny, nz, material, lighting, piece, worldModelId, worldModelPositionX, worldModelPositionY, worldModelPositionZ, worldModelRotationX, worldModelRotationY, worldModelRotationZ, worldLODModelId
    end

    local cx, cy, cz = getCameraMatrix()
    for _, distance in ipairs(placementDepths) do
        local tx, ty, tz = cameraRayTarget(distance)
        hit, x, y, z, element, nx, ny, nz, material, lighting, piece, worldModelId, worldModelPositionX, worldModelPositionY, worldModelPositionZ, worldModelRotationX, worldModelRotationY, worldModelRotationZ, worldLODModelId = rawProcessLineOfSight(cx, cy, cz, tx, ty, tz, checkBuildings, checkVehicles, checkPeds, checkObjects, checkDummies, seeThroughStuff, ignoreSomeObjectsForCamera, shootThroughStuff, ignoredElement, ...)
        if hit then
            return hit, x, y, z, element, nx, ny, nz, material, lighting, piece, worldModelId, worldModelPositionX, worldModelPositionY, worldModelPositionZ, worldModelRotationX, worldModelRotationY, worldModelRotationZ, worldLODModelId
        end
    end

    return false
end