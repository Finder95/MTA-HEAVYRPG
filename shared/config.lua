HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Config = {
    name = "HeavyRPG",
    version = "0.1.0",
    debug = true,

    database = {
        -- File is created in this resource. Keep SQLite local to the gamemode.
        path = "data/heavyrpg.db",
        share = 0,
        schemaVersion = 2
    },

    modules = {
        order = { "auth", "character", "spawn" }
    },

    auth = {
        bcryptCost = 10,
        usernameMin = 3,
        usernameMax = 24,
        passwordMin = 8,
        passwordMax = 72,
        emailMax = 120,

        -- Rate limit per player and per action.
        rateLimits = {
            login = { limit = 6, windowSeconds = 60 },
            register = { limit = 3, windowSeconds = 120 },
            resume = { limit = 10, windowSeconds = 60 },
            character = { limit = 4, windowSeconds = 60 }
        },

        failedLoginLock = {
            attempts = 5,
            lockSeconds = 15 * 60
        },

        rememberSession = {
            enabled = false,
            days = 14
        },

        -- If true, new login kicks the old player using the same account.
        kickOldSession = true,

        spawn = {
            x = 1481.08,
            y = -1749.32,
            z = 15.45,
            rotation = 0,
            skin = 0,
            interior = 0,
            dimension = 0,
            startingMoney = 500
        }
    },

    character = {
        maxSlots = 3,
        defaultSkin = 46,
        skins = { 46, 47, 48, 60, 98, 101, 170, 171, 180, 184, 185, 186, 187, 188, 227, 240, 250, 261 },
        genders = {
            { id = "male", label = "Mezczyzna" },
            { id = "female", label = "Kobieta" },
            { id = "other", label = "Inna" }
        },
        age = { min = 18, max = 65, default = 24 },
        origins = {
            { id = "ls_native", label = "Los Santos", description = "Znasz ulice, kontakty i lokalne uklady." },
            { id = "red_county", label = "Red County", description = "Spokojniejsze zaplecze, praktyczne umiejetnosci i dystans do miasta." },
            { id = "sf_transfer", label = "San Fierro", description = "Nowy start po przeprowadzce, wiecej sprytu niz znajomosci." },
            { id = "lv_runner", label = "Las Venturas", description = "Ryzyko, szybkie decyzje i obycie z ciemniejsza strona biznesu." }
        },
        archetypes = {
            { id = "hustler", label = "Uliczny gracz", bonus = "Lepszy start w kontaktach i drobnych interesach." },
            { id = "worker", label = "Pracownik", bonus = "Stabilniejszy progres prac legalnych i wytrzymalosc." },
            { id = "driver", label = "Kierowca", bonus = "Naturalny kierunek pod transport, auta i szybkie zlecenia." },
            { id = "fixer", label = "Fixer", bonus = "Charyzma, uklady i latwiejsze wejscie w ekonomie graczy." },
            { id = "athlete", label = "Atleta", bonus = "Fizyczna przewaga pod akcje, poscigi i aktywny styl gry." }
        },
        stats = {
            points = 24,
            min = 1,
            max = 8,
            attributes = {
                { id = "strength", label = "Sila", description = "Walka, noszenie, fizyczne akcje i ciezkie prace." },
                { id = "endurance", label = "Wytrzymalosc", description = "Sprint, odpornosc, dluzsze zmiany i regeneracja." },
                { id = "agility", label = "Zrecznosc", description = "Prowadzenie, refleks, uniki i precyzyjne czynnosci." },
                { id = "intelligence", label = "Inteligencja", description = "Nauka systemow, crafting, analityka i specjalistyczne prace." },
                { id = "charisma", label = "Charyzma", description = "Negocjacje, reputacja, frakcje i interakcje z graczami." },
                { id = "focus", label = "Opanowanie", description = "Stabilnosc pod presja, ryzyko, stres i konsekwencje akcji." }
            }
        },
        preview = {
            -- Isolated LS City Hall scene: clean RPG-style character preview instead of the skybox.
            x = 1481.08,
            y = -1749.32,
            z = 15.45,
            rotation = 180,
            interior = 0,
            dimension = 65000,
            camera = { 1481.08, -1753.05, 16.65, 1481.08, -1749.32, 15.95 },
            animation = { block = "DEALER", name = "DEALER_IDLE" }
        }
    },

    ui = {
        url = "http://mta/local/html/auth/index.html",
        characterUrl = "http://mta/local/html/character/index.html",
        toggleDevToolsKey = "F10"
    }
}
