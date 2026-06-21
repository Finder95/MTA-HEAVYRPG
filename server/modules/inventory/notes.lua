HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

local placedNotes = {}
local MAX_BODY = 1200
local MAX_PAGES = 12
local DEFAULT_VEHICLE_ATTACH_X = 0
local DEFAULT_VEHICLE_ATTACH_Y = 1.25
local DEFAULT_VEHICLE_ATTACH_Z = 0.55

local function now() return HRP.Utils.now() end
local function getCharacterId(player) return tonumber(getElementData(player, "hrp:character:id")) end
local function getAccountId(player) return tonumber(getElementData(player, "hrp:account:id")) end
local function notify(player, message, r, g, b) if isElement(player) then outputChatBox("[EQ] " .. tostring(message), player, r or 210, g or 198, b or 164) end end
local function clamp(value, minValue, maxValue) value = math.floor(tonumber(value) or minValue) if value < minValue then return minValue end if value > maxValue then return maxValue end return value end
local function sanitize(text) text = tostring(text or "") if #text > MAX_BODY then text = text:sub(1, MAX_BODY) end return text end

local function findItem(player, uid, itemId)
    uid = tonumber(uid)
    for _, item in ipairs((HRP.Inventory and HRP.Inventory.getItems and HRP.Inventory.getItems(player)) or {}) do
        if uid and tonumber(item.uid) == uid then return item end
        if not uid and tostring(item.itemId) == tostring(itemId or "") then return item end
    end
    return nil
end

local function characterName(player)
    return tostring(getElementData(player, "hrp:character:name") or getPlayerName(player) or "Ktos")
end

local function sendMe(player, text)
    if not isElement(player) then return end
    local px, py, pz = getElementPosition(player)
    local message = "* " .. characterName(player) .. " " .. tostring(text or "")
    for _, target in ipairs(getElementsByType("player")) do
        if isElement(target) and getElementInterior(target) == getElementInterior(player) and getElementDimension(target) == getElementDimension(player) then
            local tx, ty, tz = getElementPosition(target)
            if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) <= 20.0 then
                outputChatBox(message, target, 190, 150, 220)
            end
        end
    end
end

local function matrixPoint(matrix, lx, ly, lz)
    return lx * matrix[1][1] + ly * matrix[2][1] + lz * matrix[3][1] + matrix[4][1],
        lx * matrix[1][2] + ly * matrix[2][2] + lz * matrix[3][2] + matrix[4][2],
        lx * matrix[1][3] + ly * matrix[2][3] + lz * matrix[3][3] + matrix[4][3]
end

local function vehicleNotePoint(vehicle)
    local vx, vy, vz = getElementPosition(vehicle)
    local matrix = getElementMatrix(vehicle)
    if not matrix then return vx, vy, vz + 1.05 end
    return matrixPoint(matrix, DEFAULT_VEHICLE_ATTACH_X, DEFAULT_VEHICLE_ATTACH_Y, DEFAULT_VEHICLE_ATTACH_Z)
end

local function normalizeNotebook(metadata)
    metadata = type(metadata) == "table" and metadata or {}
    local book = type(metadata.notebook) == "table" and metadata.notebook or {}
    local rawPages = type(book.pages) == "table" and book.pages or {}
    local pages, timestamp = {}, now()

    for i, page in ipairs(rawPages) do
        if #pages >= MAX_PAGES then break end
        page = type(page) == "table" and page or {}
        pages[#pages + 1] = {
            title = tostring(page.title or ("Strona " .. tostring(i))):sub(1, 32),
            body = sanitize(page.body),
            pinned = page.pinned == true,
            createdAt = tonumber(page.createdAt) or timestamp,
            updatedAt = tonumber(page.updatedAt) or timestamp
        }
    end

    if #pages == 0 then
        pages[1] = { title = "Strona 1", body = sanitize(metadata.note), pinned = false, createdAt = timestamp, updatedAt = timestamp }
    end

    book.title = tostring(book.title or "Notes"):sub(1, 32)
    book.pages = pages
    book.activePage = clamp(book.activePage or 1, 1, #pages)
    book.updatedAt = timestamp
    metadata.notebook = book
    metadata.note = nil
    return metadata, book
end

local function persistNotebook(player, item, metadata)
    local ok = HRP.DB.exec([[UPDATE character_inventory SET metadata_json = ?, updated_at = ? WHERE id = ? AND character_id = ?]], {
        toJSON(metadata, true) or "{}",
        now(),
        item.uid,
        getCharacterId(player)
    })
    if ok and HRP.Inventory and HRP.Inventory.load then HRP.Inventory.load(player, false) end
    return ok
end

local function notePageMetadata(page, source)
    page = type(page) == "table" and page or {}
    return {
        notePage = {
            title = tostring(page.title or "Wyrwana strona"):sub(1, 32),
            body = sanitize(page.body),
            source = tostring(source or "Wyrwana z notesu"):sub(1, 64),
            pinned = page.pinned == true,
            createdAt = tonumber(page.createdAt) or now(),
            tornAt = now()
        }
    }
end

local function noteBody(metadata)
    metadata = type(metadata) == "table" and metadata or {}
    local page = type(metadata.notePage) == "table" and metadata.notePage or metadata
    return tostring(page.body or page.text or "")
end

local function tearNotebookPage(player, uid, pageNo)
    local item = findItem(player, uid, "notebook")
    if not item or tostring(item.itemId) ~= "notebook" then return false, "Nie masz tego notesu." end

    local metadata, book = normalizeNotebook(item.metadata)
    pageNo = clamp(pageNo or book.activePage or 1, 1, #book.pages)
    local page = book.pages[pageNo]
    local pageMetadata = notePageMetadata(page, "Notes #" .. tostring(item.uid))

    local added, addMessage = HRP.Inventory.add(player, "note_page", 1, pageMetadata, 100)
    if not added then return false, addMessage or "Nie udalo sie wyrwac strony." end

    if #book.pages <= 1 then
        book.pages[1] = { title = "Strona 1", body = "", pinned = false, createdAt = now(), updatedAt = now() }
        book.activePage = 1
    else
        table.remove(book.pages, pageNo)
        book.activePage = clamp(pageNo, 1, #book.pages)
    end

    if not persistNotebook(player, item, metadata) then return false, "Strona zostala wyrwana, ale notes nie odswiezyl sie poprawnie." end
    return true, "Wyrwano strone z notesu. Trafila do ekwipunku jako osobna kartka."
end

local function makePlacedNoteId(player)
    return table.concat({ "note", tostring(now()), tostring(getTickCount()), tostring(math.random(100000, 999999)), tostring(getCharacterId(player) or 0) }, "_")
end

local function notePosition(note)
    if note and note.marker and isElement(note.marker) then return getElementPosition(note.marker) end
    return note.x, note.y, note.z
end

local function isVehicleNote(note)
    return type(note) == "table" and (tostring(note.placeType or "") == "vehicle_windshield" or (note.vehicle and isElement(note.vehicle) and getElementType(note.vehicle) == "vehicle"))
end

local function worldToElementLocal(element, wx, wy, wz)
    local matrix = isElement(element) and getElementMatrix(element)
    if not matrix then return nil end
    local dx, dy, dz = wx - matrix[4][1], wy - matrix[4][2], wz - matrix[4][3]
    return dx * matrix[1][1] + dy * matrix[1][2] + dz * matrix[1][3],
        dx * matrix[2][1] + dy * matrix[2][2] + dz * matrix[2][3],
        dx * matrix[3][1] + dy * matrix[3][2] + dz * matrix[3][3]
end

local function destroyPlacedNote(noteId)
    local note = placedNotes[tostring(noteId)]
    if not note then return end
    if note.marker and isElement(note.marker) then
        if HRP.InventoryNoteVisual and HRP.InventoryNoteVisual.destroy then HRP.InventoryNoteVisual.destroy(note.marker) end
        destroyElement(note.marker)
    end
    placedNotes[tostring(noteId)] = nil
end

local function createPlacedNote(note)
    if not note or not note.id or note.id == "" then return false end
    note.placeType = tostring(note.placeType or "world")
    destroyPlacedNote(note.id)
    note.marker = createMarker(note.x, note.y, note.z, "corona", 0.55, 230, 210, 145, 120)
    if note.marker and isElement(note.marker) then
        setElementInterior(note.marker, note.interior or 0)
        setElementDimension(note.marker, note.dimension or 0)
        setElementData(note.marker, "hrp:placed_note:id", note.id, false)
        setElementData(note.marker, "hrp:placed_note:place_type", note.placeType, false)
        if note.vehicle and isElement(note.vehicle) then
            attachElements(note.marker, note.vehicle, note.attachX or DEFAULT_VEHICLE_ATTACH_X, note.attachY or DEFAULT_VEHICLE_ATTACH_Y, note.attachZ or DEFAULT_VEHICLE_ATTACH_Z, 0, 0, 0)
        end
        if HRP.InventoryNoteVisual then
            if isVehicleNote(note) and HRP.InventoryNoteVisual.destroy then
                HRP.InventoryNoteVisual.destroy(note.marker)
            elseif HRP.InventoryNoteVisual.ensure then
                HRP.InventoryNoteVisual.ensure(note.marker, note)
            end
        end
        addEventHandler("onMarkerHit", note.marker, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                local x, y, z = notePosition(note)
                triggerClientEvent(hitElement, "HeavyRPG:Inventory:nearPlacedNote", resourceRoot, true, { id = note.id, x = x, y = y, z = z, placeType = note.placeType })
            end
        end)
        addEventHandler("onMarkerLeave", note.marker, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                triggerClientEvent(hitElement, "HeavyRPG:Inventory:nearPlacedNote", resourceRoot, false, { id = note.id })
            end
        end)
    end
    placedNotes[note.id] = note
    return true
end

local function ensureSchema()
    return HRP.DB.exec([[CREATE TABLE IF NOT EXISTS world_placed_notes (
        id TEXT PRIMARY KEY,
        place_type TEXT NOT NULL DEFAULT 'world',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        pos_x REAL NOT NULL,
        pos_y REAL NOT NULL,
        pos_z REAL NOT NULL,
        interior INTEGER NOT NULL DEFAULT 0,
        dimension INTEGER NOT NULL DEFAULT 0,
        placed_by_character_id INTEGER,
        placed_by_account_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )]], {}) and HRP.DB.exec([[CREATE INDEX IF NOT EXISTS idx_world_placed_notes_place ON world_placed_notes(dimension, interior)]], {})
end

local function persistPlacedNote(note)
    return HRP.DB.exec([[INSERT INTO world_placed_notes
        (id, place_type, metadata_json, pos_x, pos_y, pos_z, interior, dimension, placed_by_character_id, placed_by_account_id, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            note.id,
            note.placeType,
            toJSON(note.metadata or {}, true) or "{}",
            note.x,
            note.y,
            note.z,
            note.interior,
            note.dimension,
            note.placedByCharacterId,
            note.placedByAccountId,
            note.createdAt,
            note.updatedAt
        })
end

local function removePlacedNote(noteId)
    return HRP.DB.exec([[DELETE FROM world_placed_notes WHERE id = ?]], { tostring(noteId) })
end

local function loadPlacedNotes()
    if not ensureSchema() then return false end
    return HRP.DB.query([[SELECT * FROM world_placed_notes ORDER BY created_at ASC]], {}, function(rows)
        for _, row in ipairs(rows or {}) do
            local metadata = {}
            if type(row.metadata_json) == "string" then
                local decoded = fromJSON(row.metadata_json)
                if type(decoded) == "table" then metadata = decoded end
            end
            createPlacedNote({
                id = tostring(row.id or ""),
                placeType = tostring(row.place_type or "world"),
                metadata = metadata,
                x = tonumber(row.pos_x) or 0,
                y = tonumber(row.pos_y) or 0,
                z = tonumber(row.pos_z) or 0,
                interior = tonumber(row.interior) or 0,
                dimension = tonumber(row.dimension) or 0,
                placedByCharacterId = tonumber(row.placed_by_character_id),
                placedByAccountId = tonumber(row.placed_by_account_id),
                createdAt = tonumber(row.created_at) or now(),
                updatedAt = tonumber(row.updated_at) or now()
            })
        end
        if HRP.Logger and HRP.Logger.info then HRP.Logger.info("inventory", "Odtworzono przyklejone notatki: " .. tostring(#(rows or {})) .. ".") end
    end)
end

local function placeNote(player, uid, placeType, x, y, z, target)
    if not isElement(player) or not getCharacterId(player) then return false, "Brak aktywnej postaci." end
    local item = findItem(player, uid)
    if not item or tostring(item.itemId) ~= "note_page" then return false, "Musisz miec wyrwana kartke w ekwipunku." end

    placeType = tostring(placeType or "world")
    if placeType ~= "vehicle" then placeType = "world" end
    if placeType == "vehicle" and (not isElement(target) or getElementType(target) ~= "vehicle") then return false, "Kartke za wycieraczka mozna zostawic tylko na pojezdzie." end

    local px, py, pz = getElementPosition(player)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)

    if placeType == "vehicle" then
        local vx, vy, vz = getElementPosition(target)
        if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) > 5.2 then return false, "Podejdz blizej do pojazdu." end
        if not x or not y or not z then
            x, y, z = vehicleNotePoint(target)
        elseif getDistanceBetweenPoints3D(vx, vy, vz, x, y, z) > 6.5 then
            return false, "Nie udalo sie ustalic miejsca za wycieraczka. Podejdz blizej do przodu pojazdu."
        end
    elseif not x or not y or not z or getDistanceBetweenPoints3D(px, py, pz, x, y, z) > 5.0 then
        return false, "Jestes za daleko od miejsca przyklejenia."
    end

    local timestamp = now()
    local noteZ = z + 0.05
    local attachX, attachY, attachZ
    if placeType == "vehicle" then
        attachX, attachY, attachZ = worldToElementLocal(target, x, y, noteZ)
        if not attachX then
            attachX, attachY, attachZ = DEFAULT_VEHICLE_ATTACH_X, DEFAULT_VEHICLE_ATTACH_Y, DEFAULT_VEHICLE_ATTACH_Z
        end
    end

    local note = {
        id = makePlacedNoteId(player),
        placeType = placeType == "vehicle" and "vehicle_windshield" or "world",
        metadata = item.metadata or {},
        x = x,
        y = y,
        z = noteZ,
        interior = getElementInterior(player),
        dimension = getElementDimension(player),
        vehicle = placeType == "vehicle" and target or nil,
        attachX = attachX,
        attachY = attachY,
        attachZ = attachZ,
        placedByCharacterId = getCharacterId(player),
        placedByAccountId = getAccountId(player),
        createdAt = timestamp,
        updatedAt = timestamp
    }

    local taken, takeMessage = HRP.Inventory.take(player, item.uid, 1)
    if not taken then return false, takeMessage or "Nie udalo sie zabrac kartki z ekwipunku." end
    if not persistPlacedNote(note) then
        HRP.Inventory.add(player, "note_page", 1, item.metadata, item.quality)
        return false, "Nie udalo sie zapisac przyklejonej notatki."
    end
    createPlacedNote(note)
    if placeType == "vehicle" then sendMe(player, "zostawia kartke za wycieraczka pojazdu.") end
    return true, placeType == "vehicle" and "Zostawiono kartke za wycieraczka." or "Przyklejono kartke w wybranym miejscu."
end

local function readPlacedNote(player, noteId)
    local note = placedNotes[tostring(noteId or "")]
    if not note then return false, "Ta notatka juz zniknela." end
    local px, py, pz = getElementPosition(player)
    local x, y, z = notePosition(note)
    if getDistanceBetweenPoints3D(px, py, pz, x, y, z) > 4.0 then return false, "Jestes za daleko od notatki." end
    triggerClientEvent(player, "HeavyRPG:Inventory:placedNotePanel", resourceRoot, { id = note.id, body = noteBody(note.metadata), placeType = note.placeType })
    return true, "Czytasz notatke."
end

local function placedNoteAction(player, action, noteId)
    local note = placedNotes[tostring(noteId or "")]
    if not note then return false, "Ta notatka juz zniknela." end
    local px, py, pz = getElementPosition(player)
    local x, y, z = notePosition(note)
    if getDistanceBetweenPoints3D(px, py, pz, x, y, z) > 4.0 then return false, "Jestes za daleko od notatki." end

    action = tostring(action or "")
    if action == "take" then
        local added, addMessage = HRP.Inventory.add(player, "note_page", 1, note.metadata, 100)
        if not added then return false, addMessage or "Nie udalo sie zabrac kartki." end
    elseif action ~= "destroy" then
        return false, "Nieznana akcja notatki."
    end

    if not removePlacedNote(note.id) then return false, "Nie udalo sie usunac notatki ze swiata." end
    destroyPlacedNote(note.id)
    triggerClientEvent(player, "HeavyRPG:Inventory:nearPlacedNote", resourceRoot, false, { id = note.id })
    return true, action == "take" and "Zabrano kartke." or "Zerwano i zniszczono kartke."
end

addEvent("HeavyRPG:Inventory:notebookTearPage", true)
addEventHandler("HeavyRPG:Inventory:notebookTearPage", resourceRoot, function(uid, pageNo)
    local ok, message = tearNotebookPage(client, uid, pageNo)
    notify(client, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)

addEvent("HeavyRPG:Inventory:destroyNotePage", true)
addEventHandler("HeavyRPG:Inventory:destroyNotePage", resourceRoot, function(uid)
    local item = findItem(client, uid)
    if not item or tostring(item.itemId) ~= "note_page" then notify(client, "Nie znaleziono kartki.", 230, 90, 80) return end
    local ok, message = HRP.Inventory.take(client, item.uid, 1)
    notify(client, ok and "Zniszczono kartke." or message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)

addEvent("HeavyRPG:Inventory:placeNote", true)
addEventHandler("HeavyRPG:Inventory:placeNote", resourceRoot, function(uid, placeType, x, y, z, target)
    local ok, message = placeNote(client, uid, placeType, x, y, z, target)
    notify(client, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)

addEvent("HeavyRPG:Inventory:readPlacedNote", true)
addEventHandler("HeavyRPG:Inventory:readPlacedNote", resourceRoot, function(noteId)
    local ok, message = readPlacedNote(client, noteId)
    notify(client, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)

addEvent("HeavyRPG:Inventory:placedNoteAction", true)
addEventHandler("HeavyRPG:Inventory:placedNoteAction", resourceRoot, function(action, noteId)
    local ok, message = placedNoteAction(client, action, noteId)
    notify(client, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    ensureSchema()
    loadPlacedNotes()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for noteId in pairs(placedNotes) do destroyPlacedNote(noteId) end
end)
