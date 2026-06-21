HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Phone = HRP.Phone or {}
local Phone = HRP.Phone

local schema = {
    [[CREATE TABLE IF NOT EXISTS phone_numbers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character_id INTEGER NOT NULL UNIQUE,
        phone_number TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'active',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )]],
    [[CREATE INDEX IF NOT EXISTS idx_phone_numbers_number ON phone_numbers(phone_number)]],
    [[CREATE TABLE IF NOT EXISTS phone_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_character_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )]],
    [[CREATE INDEX IF NOT EXISTS idx_phone_contacts_owner ON phone_contacts(owner_character_id)]],
    [[CREATE TABLE IF NOT EXISTS phone_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_character_id INTEGER NOT NULL,
        sender_number TEXT NOT NULL,
        receiver_number TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        read_at INTEGER
    )]],
    [[CREATE INDEX IF NOT EXISTS idx_phone_messages_receiver ON phone_messages(receiver_number, created_at)]]
}

local function now() return HRP.Utils.now() end
local function getCharacterId(player) return tonumber(getElementData(player, "hrp:character:id")) end

local function notify(player, message, r, g, b)
    if isElement(player) then outputChatBox("[TEL] " .. tostring(message), player, r or 180, g or 210, b or 190) end
end

local function ensureSchema()
    for _, sql in ipairs(schema) do
        if not HRP.DB.exec(sql) then
            HRP.Logger.error("phone", "Nie udalo sie przygotowac tabel telefonu: " .. tostring(sql))
            return false
        end
    end
    return true
end

local function generateNumber(characterId)
    return "555" .. tostring(100000 + ((tonumber(characterId) or 0) % 899999))
end

local function sendInventoryPanel(player, title, lines)
    triggerClientEvent(player, "HeavyRPG:Inventory:action", resourceRoot, {
        title = title,
        lines = lines or {},
        footer = "ESC - zamknij"
    })
end

function Phone.ensureNumber(player, callback)
    local characterId = getCharacterId(player)
    if not characterId then if callback then callback(false, "Brak aktywnej postaci.") end return false end
    return HRP.DB.query([[SELECT * FROM phone_numbers WHERE character_id = ? LIMIT 1]], { characterId }, function(rows)
        if not isElement(player) then return end
        if rows and rows[1] then
            if callback then callback(true, rows[1].phone_number, rows[1]) end
            return
        end

        local number = generateNumber(characterId)
        local timestamp = now()
        local ok = HRP.DB.exec([[INSERT INTO phone_numbers (character_id, phone_number, status, created_at, updated_at) VALUES(?, ?, 'active', ?, ?)]], {
            characterId,
            number,
            timestamp,
            timestamp
        })
        if callback then callback(ok == true, ok and number or "Nie udalo sie przypisac numeru.") end
    end)
end

function Phone.findOnlineByNumber(number)
    number = tostring(number or "")
    for _, player in ipairs(getElementsByType("player")) do
        if tostring(getElementData(player, "hrp:phone:number") or "") == number then return player end
    end
    return nil
end

function Phone.openPanel(player)
    Phone.ensureNumber(player, function(ok, number)
        if not ok then notify(player, number, 230, 90, 80) return end
        setElementData(player, "hrp:phone:number", number, false)
        HRP.DB.query([[SELECT COUNT(*) AS count FROM phone_contacts WHERE owner_character_id = ?]], { getCharacterId(player) }, function(contactRows)
            HRP.DB.query([[SELECT COUNT(*) AS count FROM phone_messages WHERE receiver_number = ? AND read_at IS NULL]], { number }, function(messageRows)
                local contacts = tonumber(contactRows and contactRows[1] and contactRows[1].count) or 0
                local unread = tonumber(messageRows and messageRows[1] and messageRows[1].count) or 0
                sendInventoryPanel(player, "TELEFON", {
                    "Numer: " .. tostring(number),
                    "Status: aktywny",
                    "Kontakty: " .. tostring(contacts),
                    "Nieprzeczytane SMS: " .. tostring(unread),
                    "Komendy: /sms <numer> <tresc>, /kontakt <nazwa> <numer>, /kontakty"
                })
            end)
        end)
    end)
    return true, "Otworzono telefon."
end

function Phone.openContacts(player)
    local characterId = getCharacterId(player)
    if not characterId then return false, "Brak aktywnej postaci." end
    HRP.DB.query([[SELECT name, phone_number FROM phone_contacts WHERE owner_character_id = ? ORDER BY name ASC LIMIT 8]], { characterId }, function(rows)
        local lines = {}
        for _, row in ipairs(rows or {}) do lines[#lines + 1] = tostring(row.name) .. " - " .. tostring(row.phone_number) end
        if #lines == 0 then lines[1] = "Brak kontaktow. Dodaj: /kontakt <nazwa> <numer>" end
        sendInventoryPanel(player, "KONTAKTY", lines)
    end)
    return true, "Otworzono kontakty."
end

local function handlePhoneCommand(player)
    Phone.openPanel(player)
end

local function handleContactsCommand(player)
    local ok, message = Phone.openContacts(player)
    if not ok then notify(player, message, 230, 90, 80) end
end

local function handleAddContact(player, _, name, number)
    local characterId = getCharacterId(player)
    if not characterId or not name or not number then notify(player, "Uzycie: /kontakt <nazwa> <numer>", 230, 90, 80) return end
    name = tostring(name):sub(1, 32)
    number = tostring(number):gsub("%D", ""):sub(1, 12)
    if #number < 3 then notify(player, "Podaj poprawny numer.", 230, 90, 80) return end
    local timestamp = now()
    local ok = HRP.DB.exec([[INSERT INTO phone_contacts (owner_character_id, name, phone_number, created_at, updated_at) VALUES(?, ?, ?, ?, ?)]], {
        characterId,
        name,
        number,
        timestamp,
        timestamp
    })
    notify(player, ok and "Dodano kontakt: " .. name .. "." or "Nie udalo sie dodac kontaktu.", ok and 180 or 230, ok and 220 or 90, ok and 170 or 80)
end

local function handleSmsCommand(player, _, number, ...)
    local body = HRP.Utils.trim(table.concat({ ... }, " "))
    number = tostring(number or ""):gsub("%D", "")
    if #number < 3 or #body < 1 then notify(player, "Uzycie: /sms <numer> <tresc>", 230, 90, 80) return end
    if #body > 160 then body = body:sub(1, 160) end

    Phone.ensureNumber(player, function(ok, senderNumber)
        if not ok then notify(player, senderNumber, 230, 90, 80) return end
        local timestamp = now()
        local saved = HRP.DB.exec([[INSERT INTO phone_messages (sender_character_id, sender_number, receiver_number, body, created_at) VALUES(?, ?, ?, ?, ?)]], {
            getCharacterId(player),
            senderNumber,
            number,
            body,
            timestamp
        })
        if not saved then notify(player, "Nie udalo sie wyslac SMS.", 230, 90, 80) return end
        notify(player, "Wyslano SMS do " .. number .. ".", 180, 220, 170)
        local target = Phone.findOnlineByNumber(number)
        if target then notify(target, "SMS od " .. senderNumber .. ": " .. body, 180, 220, 170) end
    end)
end

local function attachPlayer(player)
    Phone.ensureNumber(player, function(ok, number)
        if ok then setElementData(player, "hrp:phone:number", number, false) end
    end)
end

local module = {}
function module.onStart()
    if not ensureSchema() then return end
    addEventHandler("HeavyRPG:Character:onPlayerReady", resourceRoot, attachPlayer)
    addCommandHandler("telefon", handlePhoneCommand)
    addCommandHandler("kontakty", handleContactsCommand)
    addCommandHandler("kontakt", handleAddContact)
    addCommandHandler("sms", handleSmsCommand)
    HRP.Logger.info("phone", "Modul telefonow SQLite gotowy.")
end

HRP.Modules.register("phone", module)