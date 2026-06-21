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
local noteObjects = {}

local function isPlacedNoteMarker(markerType, size, r, g, b)
    return tostring(markerType or "") == "corona"
        and tonumber(size) == 0.55
        and tonumber(r) == 230
        and tonumber(g) == 210
        and tonumber(b) == 145
end

local function objectFor(element)
    return noteObjects[element]
end

function createMarker(x, y, z, markerType, size, r, g, b, a, ...)
    if not isPlacedNoteMarker(markerType, size, r, g, b) then
        return rawCreateMarker(x, y, z, markerType, size, r, g, b, a, ...)
    end

    local marker = rawCreateMarker(x, y, z, "cylinder", NOTE_MARKER_SIZE, 0, 0, 0, 0, ...)
    if marker and isElement(marker) then
        local object = rawCreateObject(NOTE_MODEL, x, y, z + 0.10, 0, 0, 0)
        if object and isElement(object) then
            noteObjects[marker] = object
            rawSetElementCollisionsEnabled(object, false)
            if rawSetObjectScale then rawSetObjectScale(object, 0.45) end
        end
    end
    return marker
end

function destroyElement(element)
    local object = objectFor(element)
    if object and isElement(object) then rawDestroyElement(object) end
    noteObjects[element] = nil
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
        rawAttachElements(object, attachTo, x or 0, y or 0, (z or 0) + 0.12, rx or 0, ry or 0, rz or 0, ...)
    end
    return result
end