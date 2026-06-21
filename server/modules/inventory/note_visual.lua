HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

if not HRP.InventoryNoteVisual then HRP.InventoryNoteVisual = {} end
local Visual = HRP.InventoryNoteVisual

if Visual.installed then return end
Visual.installed = true

local rawCreateMarker = createMarker
local rawCreateObject = createObject
local rawDestroyElement = destroyElement
local rawSetElementInterior = setElementInterior
local rawSetElementDimension = setElementDimension
local rawSetElementCollisionsEnabled = setElementCollisionsEnabled
local rawSetObjectScale = setObjectScale
local rawAttachElements = attachElements

local NOTE_MODEL = 2059
local NOTE_MARKER_SIZE = 4.0
local NOTE_SCALE = 0.62
local NOTE_WORLD_Z_OFFSET = 0.10
local NOTE_VEHICLE_Z_OFFSET = 0.08
local NOTE_VEHICLE_RX = 68
local noteObjects = {}

local function isPlacedNoteMarker(markerType, size, r, g, b)
    return tostring(markerType or "") == "corona"
        and tonumber(size) == 0.55
        and tonumber(r) == 230
        and tonumber(g) == 210
        and tonumber(b) == 145
end

local function isVehicle(element)
    return isElement(element) and getElementType(element) == "vehicle"
end

local function objectFor(element)
    return noteObjects[element]
end

local function vehicleWindshieldOffset(vehicle)
    local minX, minY, minZ, maxX, maxY, maxZ = getElementBoundingBox(vehicle)
    if not minX then return 0, 1.25, 0.55, NOTE_VEHICLE_RX, 0, 0 end

    local length = math.max(0.1, maxY - minY)
    local height = math.max(0.1, maxZ - minZ)
    local y = maxY - math.max(0.35, length * 0.20)
    local z = minZ + height * 0.64 + NOTE_VEHICLE_Z_OFFSET
    return 0, y, z, NOTE_VEHICLE_RX, 0, 0
end

local function syncObjectBase(marker, object)
    if not object or not isElement(object) then return end
    if marker and isElement(marker) then
        rawSetElementInterior(object, getElementInterior(marker) or 0)
        rawSetElementDimension(object, getElementDimension(marker) or 0)
    end
    rawSetElementCollisionsEnabled(object, false)
    if rawSetObjectScale then rawSetObjectScale(object, NOTE_SCALE) end
end

local function attachObjectToVehicle(object, vehicle)
    if not object or not isElement(object) or not isVehicle(vehicle) then return false end
    local x, y, z, rx, ry, rz = vehicleWindshieldOffset(vehicle)
    rawAttachElements(object, vehicle, x, y, z, rx, ry, rz)
    return true
end

local function moveObjectToMarker(marker, object)
    if not marker or not isElement(marker) or not object or not isElement(object) then return end
    local x, y, z = getElementPosition(marker)
    setElementPosition(object, x, y, z + NOTE_WORLD_Z_OFFSET)
end

function Visual.ensure(marker, note)
    if not marker or not isElement(marker) then return nil end

    local object = objectFor(marker)
    if not object or not isElement(object) then
        local x, y, z = getElementPosition(marker)
        object = rawCreateObject(NOTE_MODEL, x, y, z + NOTE_WORLD_Z_OFFSET, 0, 0, 0)
        if not object or not isElement(object) then return nil end
        noteObjects[marker] = object
    end

    syncObjectBase(marker, object)

    if note and isVehicle(note.vehicle) then
        attachObjectToVehicle(object, note.vehicle)
    else
        moveObjectToMarker(marker, object)
    end

    return object
end

function Visual.destroy(marker)
    local object = objectFor(marker)
    if object and isElement(object) then rawDestroyElement(object) end
    noteObjects[marker] = nil
end

function createMarker(x, y, z, markerType, size, r, g, b, a, ...)
    if not isPlacedNoteMarker(markerType, size, r, g, b) then
        return rawCreateMarker(x, y, z, markerType, size, r, g, b, a, ...)
    end

    local marker = rawCreateMarker(x, y, z, "cylinder", NOTE_MARKER_SIZE, 0, 0, 0, 0, ...)
    if marker and isElement(marker) then Visual.ensure(marker) end
    return marker
end

function destroyElement(element)
    Visual.destroy(element)
    return rawDestroyElement(element)
end

function setElementInterior(element, interior, ...)
    local result = rawSetElementInterior(element, interior, ...)
    local object = objectFor(element)
    if object and isElement(object) then rawSetElementInterior(object, interior, ...) end
    return result
end

function setElementDimension(element, dimension)
    local result = rawSetElementDimension(element, dimension)
    local object = objectFor(element)
    if object and isElement(object) then rawSetElementDimension(object, dimension) end
    return result
end

function attachElements(element, attachTo, x, y, z, rx, ry, rz, ...)
    local result = rawAttachElements(element, attachTo, x, y, z, rx, ry, rz, ...)
    local object = objectFor(element)
    if object and isElement(object) then
        if isVehicle(attachTo) then
            attachObjectToVehicle(object, attachTo)
        else
            rawAttachElements(object, attachTo, x or 0, y or 0, (z or 0) + NOTE_WORLD_Z_OFFSET, rx or 0, ry or 0, rz or 0, ...)
        end
    end
    return result
end