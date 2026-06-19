HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Character = HRP.Character or {}
HRP.Character.Repository = HRP.Character.Repository or {}

local Character = HRP.Character
local Repo = Character.Repository

local function unwrapPayload(value)
    if type(value) == "table" and type(value[1]) == "table" and not value.firstname and not value.id then
        return value[1]
    end
    return value
end

local function sendCharacterResponse(player, ok, message, character)
    if not isElement(player) then return end
    triggerClientEvent(player, "HeavyRPG:Character:response", resourceRoot, ok == true, message, character or {})
end

local function sendUnexpectedError(player, err)
    HRP.Logger.error("character", "Blad systemu postaci: " .. tostring(err))
    sendCharacterResponse(player, false, "Blad systemu postaci. Sprawdz konsole serwera.")
end

local function listHasId(list, id)
    if type(list) ~= "table" then return false end
    for _, entry in ipairs(list) do
        if type(entry) == "table" and entry.id == id then return true end
        if entry == id then return true end
    end
    return false
end

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

local function normalizeStats(value)
    local cfg = HRP.Config.character.stats or {}
    local attrs = cfg.attributes or {}
    local minValue = tonumber(cfg.min) or 1
    local maxValue = tonumber(cfg.max) or 8
    local total = tonumber(cfg.points) or 24
    local stats = {}
    local sum = 0

    value = unwrapPayload(value)
    if type(value) ~= "table" then value = {} end

    for _, attr in ipairs(attrs) do
        local id = attr.id
        local amount = tonumber(value[id]) or minValue
        amount = math.floor(amount)
        if amount < minValue then amount = minValue end
        if amount > maxValue then amount = maxValue end
        stats[id] = amount
        sum = sum + amount
    end

    if sum ~= total then
        return false, "Rozdziel dokladnie " .. tostring(total) .. " punktow statystyk. Aktualnie: " .. tostring(sum) .. "."
    end

    return true, nil, stats
end

local function validatePayload(payload)
    local cfg = HRP.Config.character
    payload = unwrapPayload(payload)
    if type(payload) ~= "table" then
        return false, "Niepoprawne dane postaci."
    end

    local firstname = cleanName(payload.firstname)
    local lastname = cleanName(payload.lastname)
    local skin = tonumber(payload.skin) or cfg.defaultSkin
    local gender = tostring(payload.gender or "male")
    local age = math.floor(tonumber(payload.age) or (cfg.age and cfg.age.default) or 24)
    local origin = tostring(payload.origin or "ls_native")
    local archetype = tostring(payload.archetype or "worker")
    local statsOk, statsReason, stats = normalizeStats(payload.stats)

    if #firstname < 3 then
        return false, "Imie musi miec minimum 3 litery."
    end

    if #lastname < 3 then
        return false, "Nazwisko musi miec minimum 3 litery."
    end

    if not isAllowedSkin(skin) then
        return false, "Wybrany skin nie jest dostepny."
    end

    if not listHasId(cfg.genders, gender) then
        return false, "Wybierz poprawna plec postaci."
    end

    if age < (cfg.age.min or 18) or age > (cfg.age.max or 65) then
        return false, "Wiek postaci musi byc w zakresie " .. tostring(cfg.age.min or 18) .. "-" .. tostring(cfg.age.max or 65) .. "."
    end

    if not listHasId(cfg.origins, origin) then
        return false, "Wybierz poprawne pochodzenie postaci."
    end

    if not listHasId(cfg.archetypes, archetype) then
        return false, "Wybierz poprawny archetyp postaci."
    end

    if not statsOk then
        return false, statsReason
    end

    return true, nil, {
        firstname = firstname,
        lastname = lastname,
        gender = gender,
        age = age,
        origin = origin,
        archetype = archetype,
        skin = skin,
        stats = stats
    }
end

local function publicCharacter(row)
    if not row then return nil end
    return {
        id = tonumber(row.id),
        accountId = tonumber(row.account_id),
        firstname = row.firstname,
        lastname = row.lastname,
        gender = row.gender or "male",
        age = tonumber(row.age) or 18,
        origin = row.origin or "ls_native",
        archetype = row.archetype or "worker",
        stats = {
            strength = tonumber(row.strength) or 4,
            endurance = tonumber(row.endurance) or 4,
            agility = tonumber(row.agility) or 4,
            intelligence = tonumber(row.intelligence) or 4,
            charisma = tonumber(row.charisma) or 4,
            focus = tonumber(row.focus) or 4
        },
        statPoints = tonumber(row.stat_points) or ((HRP.Config.character.stats and HRP.Config.character.stats.points) or 24),
        cash = tonumber(row.cash) or 0,
        bank = tonumber(row.bank) or 0,
        skin = tonumber(row.skin) or HRP.Config.character.defaultSkin,
        x = tonumber(row.pos_x) or HRP.Config.auth.spawn.x,
        y = tonumber(row.pos_y) or HRP.Config.auth.spawn.y,
        z = tonumber(row.pos_z) or HRP.Config.auth.spawn.z,
        rotation = tonumber(row.rotation) or HRP.Config.auth.spawn.rotation,
        interior = tonumber(row.interior) or HRP.Config.auth.spawn.interior,
        dimension = tonumber(row.dimension) or HRP.Config.auth.spawn.dimension,
        playtime = tonumber(row.playtime) or 0,
        lastPlayedAt = tonumber(row.last_played_at) or 0,
        createdAt = tonumber(row.created_at) or 0,
        updatedAt = tonumber(row.updated_at) or 0
    }
end

local function publicCharacterList(rows)
    local list = {}
    for _, row in ipairs(rows or {}) do
        list[#list + 1] = publicCharacter(row)
    end
    return list
end

function Repo.findByAccountId(accountId, callback)
    local started = HRP.DB.query([[SELECT * FROM characters
        WHERE account_id = ?
        ORDER BY id ASC
        LIMIT 1]], { tonumber(accountId) or 0 }, function(rows)
        callback(rows and rows[1] or nil)
    end)

    if started == false then
        callback(nil)
    end
end

function Repo.listByAccountId(accountId, callback)
    local started = HRP.DB.query([[SELECT * FROM characters
        WHERE account_id = ?
        ORDER BY updated_at DESC, id ASC]], { tonumber(accountId) or 0 }, function(rows)
        callback(rows or {})
    end)

    if started == false then
        callback({})
    end
end

function Repo.findByIdForAccount(accountId, characterId, callback)
    local started = HRP.DB.query([[SELECT * FROM characters
        WHERE account_id = ? AND id = ?
        LIMIT 1]], { tonumber(accountId) or 0, tonumber(characterId) or 0 }, function(rows)
        callback(rows and rows[1] or nil)
    end)

    if started == false then
        callback(nil)
    end
end

function Repo.touch(characterId)
    HRP.DB.exec([[UPDATE characters SET last_played_at = ?, updated_at = ? WHERE id = ?]], {
        HRP.Utils.now(),
        HRP.Utils.now(),
        tonumber(characterId) or 0
    })
end

function Repo.create(accountId, payload, callback)
    local cfg = HRP.Config.auth.spawn
    local now = HRP.Utils.now()
    local stats = payload.stats or {}

    local created = HRP.DB.exec([[INSERT INTO characters
        (account_id, firstname, lastname, gender, age, origin, archetype,
        strength, endurance, agility, intelligence, charisma, focus, stat_points,
        cash, bank, skin, pos_x, pos_y, pos_z, rotation, interior, dimension, playtime, last_played_at, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            tonumber(accountId),
            payload.firstname,
            payload.lastname,
            payload.gender,
            payload.age,
            payload.origin,
            payload.archetype,
            stats.strength,
            stats.endurance,
            stats.agility,
            stats.intelligence,
            stats.charisma,
            stats.focus,
            (HRP.Config.character.stats and HRP.Config.character.stats.points) or 24,
            cfg.startingMoney or 500,
            0,
            payload.skin,
            cfg.x,
            cfg.y,
            cfg.z,
            cfg.rotation,
            cfg.interior,
            cfg.dimension,
            0,
            now,
            now,
            now
        })

    if not created then
        callback(false, nil)
        return
    end

    local started = HRP.DB.query([[SELECT * FROM characters
        WHERE account_id = ?
        ORDER BY id DESC
        LIMIT 1]], { tonumber(accountId) or 0 }, function(rows)
        local character = rows and rows[1] or nil
        callback(character ~= nil, character)
    end)

    if started == false then
        callback(false, nil)
    end
end

function Character.getPublic(row)
    return publicCharacter(row)
end

function Character.showCreator(player, account)
    if not isElement(player) then return end

    local accountId = HRP.Auth.Session.getAccountId(player)
    if not accountId then
        sendCharacterResponse(player, false, "Najpierw musisz sie zalogowac.")
        return
    end

    Repo.listByAccountId(accountId, function(rows)
        if not isElement(player) then return end
        local characters = publicCharacterList(rows)
        triggerClientEvent(player, "HeavyRPG:Character:showCreator", resourceRoot, {
            account = account or HRP.Auth.Session.getAccount(player),
            characters = characters,
            maxSlots = HRP.Config.character.maxSlots or 3,
            canCreate = #characters < (HRP.Config.character.maxSlots or 3),
            skins = HRP.Config.character.skins,
            defaultSkin = HRP.Config.character.defaultSkin,
            genders = HRP.Config.character.genders,
            age = HRP.Config.character.age,
            origins = HRP.Config.character.origins,
            archetypes = HRP.Config.character.archetypes,
            stats = HRP.Config.character.stats,
            preview = HRP.Config.character.preview
        })
    end)
end

local function enterCharacter(player, row, message)
    local public = publicCharacter(row)
    if not public then
        sendCharacterResponse(player, false, "Nie znaleziono postaci.")
        return
    end

    Repo.touch(public.id)
    sendCharacterResponse(player, true, message or "Wchodzisz do gry.", public)
    triggerClientEvent(player, "HeavyRPG:Character:hideCreator", resourceRoot)
    triggerEvent("HeavyRPG:Character:onPlayerReady", resourceRoot, player, public)
end

local function handleCreateCharacter(player, payload)
    if not isElement(player) then return end
    payload = unwrapPayload(payload)

    local accountId = HRP.Auth.Session.getAccountId(player)
    if not accountId then
        sendCharacterResponse(player, false, "Najpierw musisz sie zalogowac.")
        return
    end

    local allowed, rateReason = HRP.Security.checkRateLimit(player, "character")
    if not allowed then
        sendCharacterResponse(player, false, rateReason)
        return
    end

    local valid, reason, data = validatePayload(payload)
    if not valid then
        sendCharacterResponse(player, false, reason)
        return
    end

    Repo.listByAccountId(accountId, function(existingRows)
        if not isElement(player) then return end
        if #(existingRows or {}) >= (HRP.Config.character.maxSlots or 3) then
            sendCharacterResponse(player, false, "Osiagnieto limit slotow postaci.")
            Character.showCreator(player)
            return
        end

        Repo.create(accountId, data, function(created, character)
            if not isElement(player) then return end
            if not created or not character then
                sendCharacterResponse(player, false, "Nie udalo sie utworzyc postaci. Sprawdz SQL w konsoli serwera.")
                return
            end

            enterCharacter(player, character, "Postac utworzona.")
        end)
    end)
end

local function handleSelectCharacter(player, characterId)
    if not isElement(player) then return end
    local accountId = HRP.Auth.Session.getAccountId(player)
    if not accountId then
        sendCharacterResponse(player, false, "Najpierw musisz sie zalogowac.")
        return
    end

    Repo.findByIdForAccount(accountId, characterId, function(character)
        if not isElement(player) then return end
        if not character then
            sendCharacterResponse(player, false, "Ta postac nie nalezy do twojego konta.")
            Character.showCreator(player)
            return
        end

        enterCharacter(player, character, "Wybrano postac.")
    end)
end

addEvent("HeavyRPG:Character:create", true)
addEventHandler("HeavyRPG:Character:create", resourceRoot, function(payload)
    local player = client
    local ok, err = pcall(handleCreateCharacter, player, payload)
    if not ok then
        sendUnexpectedError(player, err)
    end
end)

addEvent("HeavyRPG:Character:select", true)
addEventHandler("HeavyRPG:Character:select", resourceRoot, function(characterId)
    local player = client
    local ok, err = pcall(handleSelectCharacter, player, tonumber(characterId) or 0)
    if not ok then
        sendUnexpectedError(player, err)
    end
end)

addEvent("HeavyRPG:Character:onPlayerReady", false)

local module = {}
function module.onStart()
    HRP.Logger.info("character", "Zaawansowany system postaci gotowy.")
end

HRP.Modules.register("character", module)
