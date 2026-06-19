HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Character = HRP.Character or {}
HRP.Character.Repository = HRP.Character.Repository or {}

local Character = HRP.Character
local Repo = Character.Repository

local function isAllowedSkin(skin)
    skin = tonumber(skin)
    if not skin then return false end

    for _, allowed in ipairs(HRP.Config.character.skins or {}) do
        if tonumber(allowed) == skin then
            return true
        end
    end

    return false
end

local function cleanName(value)
    value = HRP.Utils.trim(value or "")
    value = value:gsub("[^A-Za-z]", "")
    return value:sub(1, 18)
end

local function validatePayload(payload)
    if type(payload) ~= "table" then
        return false, "Niepoprawne dane postaci."
    end

    local firstname = cleanName(payload.firstname)
    local lastname = cleanName(payload.lastname)
    local skin = tonumber(payload.skin) or HRP.Config.character.defaultSkin

    if #firstname < 3 then
        return false, "Imie musi miec minimum 3 litery."
    end

    if #lastname < 3 then
        return false, "Nazwisko musi miec minimum 3 litery."
    end

    if not isAllowedSkin(skin) then
        return false, "Wybrany skin nie jest dostepny."
    end

    return true, nil, {
        firstname = firstname,
        lastname = lastname,
        skin = skin
    }
end

local function publicCharacter(row)
    if not row then return nil end
    return {
        id = tonumber(row.id),
        accountId = tonumber(row.account_id),
        firstname = row.firstname,
        lastname = row.lastname,
        age = tonumber(row.age) or 18,
        cash = tonumber(row.cash) or 0,
        bank = tonumber(row.bank) or 0,
        skin = tonumber(row.skin) or HRP.Config.character.defaultSkin,
        x = tonumber(row.pos_x) or HRP.Config.auth.spawn.x,
        y = tonumber(row.pos_y) or HRP.Config.auth.spawn.y,
        z = tonumber(row.pos_z) or HRP.Config.auth.spawn.z,
        rotation = tonumber(row.rotation) or HRP.Config.auth.spawn.rotation,
        interior = tonumber(row.interior) or HRP.Config.auth.spawn.interior,
        dimension = tonumber(row.dimension) or HRP.Config.auth.spawn.dimension
    }
end

function Repo.findByAccountId(accountId, callback)
    HRP.DB.query([[SELECT * FROM characters
        WHERE account_id = ?
        ORDER BY id ASC
        LIMIT 1]], { tonumber(accountId) or 0 }, function(rows)
        callback(rows and rows[1] or nil)
    end)
end

function Repo.create(accountId, payload, callback)
    local cfg = HRP.Config.auth.spawn
    local now = HRP.Utils.now()

    local created = HRP.DB.exec([[INSERT INTO characters
        (account_id, firstname, lastname, age, cash, bank, skin, pos_x, pos_y, pos_z, rotation, interior, dimension, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            tonumber(accountId),
            payload.firstname,
            payload.lastname,
            18,
            cfg.startingMoney or 500,
            0,
            payload.skin,
            cfg.x,
            cfg.y,
            cfg.z,
            cfg.rotation,
            cfg.interior,
            cfg.dimension,
            now,
            now
        })

    if not created then
        callback(false, nil)
        return
    end

    Repo.findByAccountId(accountId, function(character)
        callback(character ~= nil, character)
    end)
end

function Character.getPublic(row)
    return publicCharacter(row)
end

function Character.showCreator(player, account)
    if not isElement(player) then return end
    triggerClientEvent(player, "HeavyRPG:Character:showCreator", resourceRoot, {
        account = account or HRP.Auth.Session.getAccount(player),
        skins = HRP.Config.character.skins,
        defaultSkin = HRP.Config.character.defaultSkin,
        preview = HRP.Config.character.preview
    })
end

addEvent("HeavyRPG:Character:create", true)
addEventHandler("HeavyRPG:Character:create", resourceRoot, function(payload)
    local player = client
    if not isElement(player) then return end

    local accountId = HRP.Auth.Session.getAccountId(player)
    if not accountId then
        triggerClientEvent(player, "HeavyRPG:Character:response", resourceRoot, false, "Najpierw musisz sie zalogowac.")
        return
    end

    local allowed, rateReason = HRP.Security.checkRateLimit(player, "character")
    if not allowed then
        triggerClientEvent(player, "HeavyRPG:Character:response", resourceRoot, false, rateReason)
        return
    end

    local valid, reason, data = validatePayload(payload)
    if not valid then
        triggerClientEvent(player, "HeavyRPG:Character:response", resourceRoot, false, reason)
        return
    end

    Repo.findByAccountId(accountId, function(existing)
        if not isElement(player) then return end
        if existing then
            triggerClientEvent(player, "HeavyRPG:Character:hideCreator", resourceRoot)
            triggerEvent("HeavyRPG:Character:onPlayerReady", resourceRoot, player, publicCharacter(existing))
            return
        end

        Repo.create(accountId, data, function(created, character)
            if not isElement(player) then return end
            if not created or not character then
                triggerClientEvent(player, "HeavyRPG:Character:response", resourceRoot, false, "Nie udalo sie utworzyc postaci.")
                return
            end

            local public = publicCharacter(character)
            triggerClientEvent(player, "HeavyRPG:Character:response", resourceRoot, true, "Postac utworzona.", public)
            triggerClientEvent(player, "HeavyRPG:Character:hideCreator", resourceRoot)
            triggerEvent("HeavyRPG:Character:onPlayerReady", resourceRoot, player, public)
        end)
    end)
end)

addEvent("HeavyRPG:Character:onPlayerReady", false)

local module = {}
function module.onStart()
    HRP.Logger.info("character", "Kreator postaci gotowy.")
end

HRP.Modules.register("character", module)
