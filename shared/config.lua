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
        schemaVersion = 3
    },

    modules = {
        order = { "auth", "character", "spawn", "survival", "bank", "inventory" }
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

    survival = {
        tickMs = 60000,
        saveEveryTicks = 5,
        defaults = { hunger = 92, thirst = 88, energy = 86, hygiene = 75, stress = 8 },
        decay = { hunger = 1.10, thirst = 1.45, energy = 0.85, hygiene = 0.55, stress = -0.20 },
        sprintMultiplier = 1.6,
        vehicleEnergyMultiplier = 0.55,
        critical = { hunger = 8, thirst = 8, energy = 6, hygiene = 5, stress = 92 },
        damage = { hunger = 2, thirst = 4, energy = 1, stress = 1 },
        regeneration = { energyPerMinuteResting = 1.2, stressPerMinuteResting = -0.6 }
    },

    bank = {
        startingBalance = 0,
        transferTaxPercent = 1.5,
        maxTransfer = 250000,
        dailySoftLimit = 500000,
        commands = {
            balance = "bank",
            deposit = "wplac",
            withdraw = "wyplac",
            transfer = "przelew"
        }
    },

    inventory = {
        enabled = true,
        key = "i",
        slots = 48,
        maxWeight = 35,
        weightPerStrength = 1.5,
        seedStarterItems = true,
        commands = {
            open = "eq"
        },
        categories = {
            { id = "documents", label = "Dokumenty" },
            { id = "consumable", label = "Jedzenie" },
            { id = "medical", label = "Medyczne" },
            { id = "utility", label = "Uzytkowe" },
            { id = "illegal", label = "Nielegalne" },
            { id = "misc", label = "Inne" }
        },
        starterItems = {
            { itemId = "id_card", quantity = 1, slot = 1 },
            { itemId = "phone", quantity = 1, slot = 2 },
            { itemId = "water_bottle", quantity = 2, slot = 3 },
            { itemId = "sandwich", quantity = 2, slot = 4 },
            { itemId = "bandage", quantity = 1, slot = 5 },
            { itemId = "notebook", quantity = 1, slot = 6 }
        },
        items = {
            id_card = {
                label = "Dowod osobisty",
                category = "documents",
                weight = 0.05,
                stackable = false,
                usable = false,
                flags = "unique,document",
                description = "Podstawowy dokument postaci. Przydatny przy kontroli, urzedach i frakcjach porzadkowych."
            },
            phone = {
                label = "Telefon komorkowy",
                category = "utility",
                weight = 0.20,
                stackable = false,
                usable = false,
                flags = "device",
                description = "Stary, poobijany telefon. W przyszlosci posluzy do kontaktow, SMS i aplikacji RP."
            },
            water_bottle = {
                label = "Butelka wody",
                category = "consumable",
                weight = 0.50,
                stackable = true,
                usable = true,
                consume = true,
                effect = { needs = { thirst = 26 } },
                useMessage = "Wypiles butelke wody.",
                description = "Zwykla woda mineralna. Najprostszy sposob na pragnienie po dluzszym bieganiu."
            },
            sandwich = {
                label = "Kanapka",
                category = "consumable",
                weight = 0.35,
                stackable = true,
                usable = true,
                consume = true,
                effect = { needs = { hunger = 24, energy = 4 } },
                useMessage = "Zjadles kanapke.",
                description = "Prosty posilek na szybko. Nie jest luksusem, ale trzyma gracza przy zyciu."
            },
            bandage = {
                label = "Bandaz",
                category = "medical",
                weight = 0.18,
                stackable = true,
                usable = true,
                consume = true,
                effect = { health = 18 },
                useMessage = "Opatrzyles rany bandazem.",
                description = "Podstawowy opatrunek. Pomaga przy lekkich obrazeniach, ale nie zastapi medyka."
            },
            painkillers = {
                label = "Tabletki przeciwbolowe",
                category = "medical",
                weight = 0.10,
                stackable = true,
                usable = true,
                consume = true,
                effect = { health = 6, needs = { stress = -12 } },
                useMessage = "Wziales tabletki przeciwbolowe.",
                description = "Zmniejszaja bol i stres, ale nie powinny byc traktowane jak pelne leczenie."
            },
            cigarette_pack = {
                label = "Paczka papierosow",
                category = "utility",
                weight = 0.08,
                stackable = true,
                usable = true,
                consume = true,
                effect = { needs = { stress = -8, hygiene = -2 } },
                useMessage = "Odpaliles papierosa.",
                description = "Drobny klimatyczny item RP. Uspokaja, ale psuje higiene."
            },
            lockpick = {
                label = "Wytrych",
                category = "illegal",
                weight = 0.04,
                stackable = true,
                usable = false,
                flags = "contraband,tool",
                description = "Nielegalne narzedzie pod przyszle systemy wlaman, drzwi i pojazdow."
            },
            notebook = {
                label = "Notes",
                category = "misc",
                weight = 0.12,
                stackable = false,
                usable = false,
                description = "Zniszczony notes na kontakty, dlugi, adresy i prywatne notatki postaci."
            }
        },
        palette = {
            background = { 18, 16, 13, 232 },
            panel = { 31, 28, 23, 210 },
            row = { 45, 39, 31, 120 },
            rowAlt = { 37, 33, 27, 120 },
            rowActive = { 96, 78, 45, 205 },
            line = { 133, 112, 75, 180 },
            text = { 224, 213, 190 },
            muted = { 138, 130, 111 },
            accent = { 190, 157, 87 },
            danger = { 178, 62, 48 },
            barBack = { 8, 7, 6, 178 }
        }
    },

    hud = {
        enabled = true,
        style = "heavy_rp_bars",
        text = { 218, 211, 196 },
        muted = { 122, 117, 106 },
        background = { 0, 0, 0, 118 },
        barBack = { 18, 17, 15, 165 },
        health = { 154, 48, 42 },
        armor = { 108, 119, 126 },
        hunger = { 156, 117, 66 },
        thirst = { 77, 123, 151 },
        energy = { 181, 160, 92 },
        hygiene = { 118, 133, 118 },
        stress = { 112, 77, 82 },
        cash = { 190, 176, 124 },
        danger = { 185, 46, 42 }
    },

    ui = {
        url = "http://mta/local/html/auth/index.html",
        characterUrl = "http://mta/local/html/character/index.html",
        toggleDevToolsKey = "F10"
    }
}
