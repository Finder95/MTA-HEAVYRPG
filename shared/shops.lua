HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Config = HRP.Config or {}
HRP.Config.modules = HRP.Config.modules or { order = {} }

HRP.Config.shops = {
    enabled = true,
    key = "e",
    pickupModel = 1318,
    pickupZOffset = 1.35,
    promptDistance = 2.0,
    radar = {
        enabled = true,
        -- MTA defaultowe blipy nie przyjmuja wlasnych PNG, dlatego mini-radar dostaje customowy overlay DX.
        iconSize = 18,
        worldRange = 260.0,
        visibleDistance = 700.0,
        nearPulseDistance = 30.0,
        minimapX = 36,
        minimapBottom = 42,
        minimapSize = 190
    },
    interior = {
        id = "ls_24_7",
        label = "Sklep 24/7",
        interior = 18,
        dimension = 0,
        spawn = { x = -30.9, y = -91.5, z = 1003.5, rotation = 0 },
        exit = { x = -30.9, y = -91.5, z = 1002.4, radius = 1.8 },
        clerk = { x = -27.1, y = -91.9, z = 1003.5, rotation = 0, model = 201, radius = 2.3, name = "Sklepikarka" }
    },
    entrances = {
        {
            id = "sklep_1",
            label = "Sklep 1",
            x = 1832.7,
            y = -1842.6,
            z = 12.6,
            rotation = 90,
            interior = 0,
            dimension = 0,
            returnX = 1832.7,
            returnY = -1846.4,
            returnZ = 13.6,
            returnRotation = 180
        },
        {
            id = "sklep_2",
            label = "Sklep 2",
            x = 1930.0,
            y = -1776.4,
            z = 12.5,
            rotation = 90,
            interior = 0,
            dimension = 0,
            returnX = 1930.0,
            returnY = -1780.0,
            returnZ = 13.5,
            returnRotation = 180
        },
        {
            id = "sklep_3",
            label = "Sklep 3",
            x = 1352.3,
            y = -1758.4,
            z = 12.4,
            rotation = 90,
            interior = 0,
            dimension = 0,
            returnX = 1352.3,
            returnY = -1761.8,
            returnZ = 13.4,
            returnRotation = 180
        }
    },
    catalog = {
        categories = {
            { id = "food", label = "Jedzenie" },
            { id = "drinks", label = "Napoje" },
            { id = "medical", label = "Apteczka" },
            { id = "utility", label = "Uzytkowe" },
            { id = "paper", label = "Papier" }
        },
        offers = {
            { id = "water", itemId = "water_bottle", category = "drinks", price = 12, maxQuantity = 12, stock = -1 },
            { id = "sandwich", itemId = "sandwich", category = "food", price = 18, maxQuantity = 8, stock = -1 },
            { id = "bandage", itemId = "bandage", category = "medical", price = 45, maxQuantity = 5, stock = -1 },
            { id = "painkillers", itemId = "painkillers", category = "medical", price = 65, maxQuantity = 4, stock = -1 },
            { id = "cigarettes", itemId = "cigarette_pack", category = "utility", price = 28, maxQuantity = 6, stock = -1 },
            { id = "notebook", itemId = "notebook", category = "paper", price = 35, maxQuantity = 1, stock = -1 },
            { id = "note_page", itemId = "note_page", category = "paper", price = 4, maxQuantity = 10, stock = -1 },
            { id = "phone", itemId = "phone", category = "utility", price = 250, maxQuantity = 1, stock = -1 }
        }
    }
}

local function hasModule(name)
    for _, existing in ipairs(HRP.Config.modules.order or {}) do
        if existing == name then return true end
    end
    return false
end

if not hasModule("shops") then
    HRP.Config.modules.order[#HRP.Config.modules.order + 1] = "shops"
end
