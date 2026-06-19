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
        schemaVersion = 1
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
        defaultSkin = 46,
        skins = { 46, 47, 48, 60, 98, 101, 170, 171, 180, 184, 185, 186, 187, 188, 227, 240, 250, 261 },
        preview = {
            x = 0,
            y = 0,
            z = 3000,
            rotation = 0,
            interior = 0,
            dimension = 65000,
            camera = { 0, 3.35, 3001.18, 0, 0, 3000.86 },
            animation = { block = "DEALER", name = "DEALER_IDLE" }
        }
    },

    ui = {
        url = "http://mta/local/html/auth/index.html",
        characterUrl = "http://mta/local/html/character/index.html",
        toggleDevToolsKey = "F10"
    }
}
