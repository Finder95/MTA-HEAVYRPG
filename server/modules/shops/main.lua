HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Shops = HRP.Shops or {}
local Shops = HRP.Shops

local entranceById = {}
local offerById = {}
local playerReturns = setmetatable({}, { __mode = "k" })
local elements = { pickups = {}, cols = {}, clerk = nil, clerkCol = nil, exitPickup = nil, exitCol = nil }

local function cfg() return HRP.Config.shops or {} end
local function inventoryCfg() return HRP.Config.inventory or {} end
local function itemDefinitions() return inventoryCfg().items or {} end
local function now() return HRP.Utils.now() end

local function trim(value)
    value = tostring(value or "")
    if HRP.Utils and HRP.Utils.trim then return HRP.Utils.trim(value) end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function money(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then return 0 end
    return value
end

local function quantity(value, fallback)
    value = math.floor(tonumber(value) or fallback or 1)
    if value < 1 then return 1 end
    if value > 99 then return 99 end
    return value
end

local function notify(player, message, r, g, b)
    if isElement(player) then
        outputChatBox("[SKLEP] " .. tostring(message), player, r or 210, g or 198, b or 164)
    end
end

local function sendResponse(player, ok, message, extra)
    extra = type(extra) == "table" and extra or {}
    extra.ok = ok == true
    extra.message = tostring(message or "")
    extra.cash = isElement(player) and money(getPlayerMoney(player)) or 0
    triggerClientEvent(player, "HeavyRPG:Shops:response", resourceRoot, extra)
    notify(player, extra.message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end

local function placeElement(element, place)
    if not element or not isElement(element) or type(place) ~= "table" then return end
    setElementInterior(element, tonumber(place.interior) or 0)
    setElementDimension(element, tonumber(place.dimension) or 0)
end

local function pointDistance(player, point)
    if not isElement(player) or type(point) ~= "table" then return 9999 end
    if getElementInterior(player) ~= (tonumber(point.interior) or 0) then return 9999 end
    if getElementDimension(player) ~= (tonumber(point.dimension) or 0) then return 9999 end
    local px, py, pz = getElementPosition(player)
    return getDistanceBetweenPoints3D(px, py, pz, tonumber(point.x) or 0, tonumber(point.y) or 0, tonumber(point.z) or 0)
end

local function isNear(player, point, radius)
    return pointDistance(player, point) <= (tonumber(radius) or cfg().promptDistance or 2.0)
end

local function entranceByCol(col)
    local id = isElement(col) and getElementData(col, "hrp:shop:entrance", false)
    return id and entranceById[id] or nil
end

local function buildPickup(point)
    local z = (tonumber(point.z) or 0) + (tonumber(cfg().pickupZOffset) or 0.72)
    local pickup = createPickup(point.x, point.y, z, 3, tonumber(cfg().pickupModel) or 1318, 0)
    if pickup and isElement(pickup) then
        placeElement(pickup, point)
        addEventHandler("onPickupHit", pickup, function() cancelEvent() end)
        return pickup
    end

    local object = createObject(tonumber(cfg().pickupModel) or 1318, point.x, point.y, z)
    if object and isElement(object) then
        placeElement(object, point)
        setElementCollisionsEnabled(object, false)
    end
    return object
end

local function buildCol(point, radius)
    local col = createColSphere(point.x, point.y, (tonumber(point.z) or 0) + 1.0, tonumber(radius) or cfg().promptDistance or 2.0)
    if col and isElement(col) then placeElement(col, point) end
    return col
end

local function publicOffer(offer)
    local def = itemDefinitions()[tostring(offer.itemId or "")] or {}
    local maxQty = tonumber(offer.maxQuantity) or 1
    if def.stackable == false then maxQty = 1 end

    return {
        id = tostring(offer.id or offer.itemId),
        itemId = tostring(offer.itemId or ""),
        category = tostring(offer.category or def.category or "misc"),
        label = tostring(offer.label or def.label or offer.itemId or "Towar"),
        description = tostring(offer.description or def.description or ""),
        price = money(offer.price),
        maxQuantity = math.max(1, maxQty),
        stock = tonumber(offer.stock) or -1,
        weight = tonumber(def.weight) or 0,
        stackable = def.stackable ~= false
    }
end

local function buildCatalog()
    local public = {}
    for _, offer in ipairs((cfg().catalog and cfg().catalog.offers) or {}) do
        local itemId = tostring(offer.itemId or "")
        if itemDefinitions()[itemId] then
            public[#public + 1] = publicOffer(offer)
        end
    end

    return {
        name = (cfg().interior and cfg().interior.label) or "Sklep",
        key = cfg().key or "e",
        categories = (cfg().catalog and cfg().catalog.categories) or {},
        offers = public
    }
end

local function saveCharacterCash(player)
    local characterId = tonumber(getElementData(player, "hrp:character:id"))
    if not characterId then return false end
    return HRP.DB.exec([[UPDATE characters SET cash = ?, updated_at = ? WHERE id = ?]], { money(getPlayerMoney(player)), now(), characterId })
end

local function syncAfterMoneyChange(player)
    saveCharacterCash(player)
    if HRP.Bank and HRP.Bank.sync then HRP.Bank.sync(player) end
    if HRP.Inventory and HRP.Inventory.sync then HRP.Inventory.sync(player) end
end

local function entranceReturnPoint(entrance)
    return {
        x = tonumber(entrance.returnX) or tonumber(entrance.x) or 0,
        y = tonumber(entrance.returnY) or tonumber(entrance.y) or 0,
        z = tonumber(entrance.returnZ) or ((tonumber(entrance.z) or 0) + 1.0),
        rotation = tonumber(entrance.returnRotation) or tonumber(entrance.rotation) or 0,
        interior = tonumber(entrance.interior) or 0,
        dimension = tonumber(entrance.dimension) or 0
    }
end

local function teleportPlayer(player, point)
    fadeCamera(player, false, 0.35)
    setTimer(function(target, targetPoint)
        if not isElement(target) then return end
        setElementInterior(target, tonumber(targetPoint.interior) or 0)
        setElementDimension(target, tonumber(targetPoint.dimension) or 0)
        setElementPosition(target, targetPoint.x, targetPoint.y, targetPoint.z)
        setElementRotation(target, 0, 0, tonumber(targetPoint.rotation) or 0)
        setCameraTarget(target, target)
        fadeCamera(target, true, 0.45)
    end, 420, 1, player, point)
end

function Shops.enter(player, entranceId)
    local entrance = entranceById[tostring(entranceId or "")]
    if not entrance then return false, "Nieznane wejscie do sklepu." end
    if not isNear(player, entrance, cfg().promptDistance) then return false, "Podejdz blizej wejscia." end
    if getPedOccupiedVehicle(player) then return false, "Najpierw wysiadz z pojazdu." end

    local interior = cfg().interior or {}
    local spawn = interior.spawn or {}
    playerReturns[player] = entranceReturnPoint(entrance)
    teleportPlayer(player, {
        x = tonumber(spawn.x) or -30.9,
        y = tonumber(spawn.y) or -91.5,
        z = tonumber(spawn.z) or 1003.5,
        rotation = tonumber(spawn.rotation) or 0,
        interior = tonumber(interior.interior) or 18,
        dimension = tonumber(interior.dimension) or 0
    })
    triggerClientEvent(player, "HeavyRPG:Shops:close", resourceRoot)
    return true, "Wchodzisz do sklepu. Podejdz do sklepikarki i nacisnij E."
end

function Shops.exit(player)
    local interior = cfg().interior or {}
    local exitPoint = interior.exit or {}
    exitPoint.interior = tonumber(interior.interior) or 18
    exitPoint.dimension = tonumber(interior.dimension) or 0

    if not isNear(player, exitPoint, exitPoint.radius or cfg().promptDistance) then return false, "Podejdz blizej wyjscia." end

    local returnPoint = playerReturns[player] or entranceReturnPoint((cfg().entrances or {})[1] or {})
    playerReturns[player] = nil
    teleportPlayer(player, returnPoint)
    triggerClientEvent(player, "HeavyRPG:Shops:close", resourceRoot)
    return true, "Wychodzisz ze sklepu."
end

function Shops.open(player)
    local interior = cfg().interior or {}
    local clerk = interior.clerk or {}
    clerk.interior = tonumber(interior.interior) or 18
    clerk.dimension = tonumber(interior.dimension) or 0

    if not tonumber(getElementData(player, "hrp:character:id")) then return false, "Najpierw wybierz postac." end
    if not isNear(player, clerk, clerk.radius or cfg().promptDistance) then return false, "Podejdz do sklepikarki." end

    local payload = buildCatalog()
    payload.cash = money(getPlayerMoney(player))
    payload.clerkName = tostring(clerk.name or "Sklepikarka")
    triggerClientEvent(player, "HeavyRPG:Shops:open", resourceRoot, payload)
    return true
end

function Shops.buy(player, offerId, amount)
    if not tonumber(getElementData(player, "hrp:character:id")) then return false, "Najpierw wybierz postac." end

    local interior = cfg().interior or {}
    local clerk = interior.clerk or {}
    clerk.interior = tonumber(interior.interior) or 18
    clerk.dimension = tonumber(interior.dimension) or 0
    if not isNear(player, clerk, clerk.radius or cfg().promptDistance + 0.6) then return false, "Jestes za daleko od sprzedawcy." end

    local offer = offerById[tostring(offerId or "")]
    if not offer then return false, "Ten towar nie jest dostepny." end

    local def = itemDefinitions()[tostring(offer.itemId or "")]
    if not def then return false, "Ten towar nie ma definicji itemu." end

    local qty = quantity(amount, 1)
    local maxQty = tonumber(offer.maxQuantity) or 1
    if def.stackable == false then maxQty = 1 end
    if qty > maxQty then qty = maxQty end

    local stock = tonumber(offer.stock) or -1
    if stock == 0 then return false, "Towar jest chwilowo niedostepny." end
    if stock > 0 and qty > stock then qty = stock end

    local total = money(offer.price) * qty
    if total < 1 then return false, "Niepoprawna cena towaru." end
    if money(getPlayerMoney(player)) < total then return false, "Nie masz wystarczajacej gotowki przy sobie." end
    if not HRP.Inventory or not HRP.Inventory.add then return false, "Ekwipunek nie jest gotowy." end

    local ok, reason = HRP.Inventory.add(player, offer.itemId, qty, offer.metadata, offer.quality or 100)
    if not ok then return false, reason or "Nie udalo sie dodac towaru do ekwipunku." end

    takePlayerMoney(player, total)
    syncAfterMoneyChange(player)
    triggerEvent("HeavyRPG:Shops:onPurchased", resourceRoot, player, offer.itemId, qty, total)

    local label = tostring(offer.label or def.label or offer.itemId)
    return true, "Kupiono: " .. label .. " x" .. tostring(qty) .. " za $" .. tostring(total) .. ".", { offerId = tostring(offer.id), quantity = qty }
end

local function handleInteraction(player, kind, id)
    if kind == "entrance" then
        local ok, message = Shops.enter(player, id)
        if message then notify(player, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80) end
        return
    end
    if kind == "exit" then
        local ok, message = Shops.exit(player)
        if message then notify(player, message, ok and 180 or 230, ok and 220 or 90, ok and 170 or 80) end
        return
    end
    if kind == "clerk" then
        local ok, message = Shops.open(player)
        if not ok and message then notify(player, message, 230, 90, 80) end
    end
end

local function handleBuy(player, offerId, qty)
    local ok, message, extra = Shops.buy(player, offerId, qty)
    sendResponse(player, ok, message, extra)
end

local function sendNear(player, state, payload)
    if isElement(player) then
        triggerClientEvent(player, "HeavyRPG:Shops:nearPoint", resourceRoot, state == true, payload or {})
    end
end

local function createEntrance(entrance)
    entrance.interior = tonumber(entrance.interior) or 0
    entrance.dimension = tonumber(entrance.dimension) or 0
    entranceById[entrance.id] = entrance

    local pickup = buildPickup(entrance)
    local col = buildCol(entrance, cfg().promptDistance)
    elements.pickups[#elements.pickups + 1] = pickup
    elements.cols[#elements.cols + 1] = col

    if col and isElement(col) then
        setElementData(col, "hrp:shop:entrance", entrance.id, false)
        addEventHandler("onColShapeHit", col, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                sendNear(hitElement, true, { kind = "entrance", id = entrance.id, label = entrance.label, action = "Wejdz do sklepu", key = cfg().key or "e" })
            end
        end)
        addEventHandler("onColShapeLeave", col, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                sendNear(hitElement, false, { kind = "entrance", id = entrance.id })
            end
        end)
    end
end

local function createInterior()
    local interior = cfg().interior or {}
    local base = { interior = tonumber(interior.interior) or 18, dimension = tonumber(interior.dimension) or 0 }
    local exitPoint = interior.exit or {}
    exitPoint.interior, exitPoint.dimension = base.interior, base.dimension
    local clerk = interior.clerk or {}
    clerk.interior, clerk.dimension = base.interior, base.dimension

    elements.exitPickup = buildPickup(exitPoint)
    elements.exitCol = buildCol(exitPoint, exitPoint.radius or cfg().promptDistance)
    if elements.exitCol and isElement(elements.exitCol) then
        addEventHandler("onColShapeHit", elements.exitCol, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                sendNear(hitElement, true, { kind = "exit", id = "exit", label = interior.label or "Sklep", action = "Wyjdz ze sklepu", key = cfg().key or "e" })
            end
        end)
        addEventHandler("onColShapeLeave", elements.exitCol, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                sendNear(hitElement, false, { kind = "exit", id = "exit" })
            end
        end)
    end

    elements.clerk = createPed(tonumber(clerk.model) or 201, clerk.x, clerk.y, clerk.z, tonumber(clerk.rotation) or 0)
    if elements.clerk and isElement(elements.clerk) then
        placeElement(elements.clerk, clerk)
        setElementFrozen(elements.clerk, true)
        setElementData(elements.clerk, "hrp:shop:clerk", true, false)
        setElementData(elements.clerk, "hrp:shop:clerk:name", tostring(clerk.name or "Sklepikarka"), true)
        if setPedAnimation then setPedAnimation(elements.clerk, "COP_AMBIENT", "Coplook_loop", -1, true, false, false, false) end
    end

    elements.clerkCol = buildCol(clerk, clerk.radius or cfg().promptDistance)
    if elements.clerkCol and isElement(elements.clerkCol) then
        addEventHandler("onColShapeHit", elements.clerkCol, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                sendNear(hitElement, true, { kind = "clerk", id = "clerk", label = tostring(clerk.name or "Sklepikarka"), action = "Porozmawiaj i kup towar", key = cfg().key or "e" })
            end
        end)
        addEventHandler("onColShapeLeave", elements.clerkCol, function(hitElement, matchingDimension)
            if matchingDimension and isElement(hitElement) and getElementType(hitElement) == "player" then
                sendNear(hitElement, false, { kind = "clerk", id = "clerk" })
                triggerClientEvent(hitElement, "HeavyRPG:Shops:close", resourceRoot)
            end
        end)
    end
end

local function indexOffers()
    offerById = {}
    for _, offer in ipairs((cfg().catalog and cfg().catalog.offers) or {}) do
        if offer.id and offer.itemId then offerById[tostring(offer.id)] = offer end
    end
end

local function cleanup()
    for _, element in ipairs(elements.pickups or {}) do if element and isElement(element) then destroyElement(element) end end
    for _, element in ipairs(elements.cols or {}) do if element and isElement(element) then destroyElement(element) end end
    for _, element in ipairs({ elements.clerk, elements.clerkCol, elements.exitPickup, elements.exitCol }) do if element and isElement(element) then destroyElement(element) end end
    elements = { pickups = {}, cols = {}, clerk = nil, clerkCol = nil, exitPickup = nil, exitCol = nil }
    entranceById = {}
    offerById = {}
end

addEvent("HeavyRPG:Shops:interact", true)
addEventHandler("HeavyRPG:Shops:interact", resourceRoot, function(kind, id)
    if client and isElement(client) then handleInteraction(client, tostring(kind or ""), tostring(id or "")) end
end)

addEvent("HeavyRPG:Shops:buy", true)
addEventHandler("HeavyRPG:Shops:buy", resourceRoot, function(offerId, qty)
    if client and isElement(client) then handleBuy(client, tostring(offerId or ""), qty) end
end)

addCommandHandler("sklep", function(player)
    if not isElement(player) then return end
    local ok, message = Shops.open(player)
    if not ok and message then notify(player, message, 230, 90, 80) end
end)

addEvent("HeavyRPG:Shops:onPurchased", false)

local module = {}
function module.onStart()
    if cfg().enabled == false then
        HRP.Logger.info("shops", "System sklepow wylaczony w konfiguracji.")
        return
    end

    indexOffers()
    for _, entrance in ipairs(cfg().entrances or {}) do createEntrance(entrance) end
    createInterior()
    HRP.Logger.info("shops", "System sklepow gotowy: " .. tostring(#(cfg().entrances or {})) .. " wejsc, " .. tostring(#((cfg().catalog and cfg().catalog.offers) or {})) .. " towarow.")
end

addEventHandler("onPlayerQuit", root, function() playerReturns[source] = nil end)
addEventHandler("onResourceStop", resourceRoot, cleanup)

HRP.Modules.register("shops", module)
