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
        order = { "auth", "spawn" }
    },

    auth = {
        bcryptCost = 12,
        usernameMin = 3,
        usernameMax = 24,
        passwordMin = 8,
        passwordMax = 72,
        emailMax = 120,

        -- Limit how many accounts may be created from one GTA serial.
        maxAccountsPerSerial = 2,

        -- Rate limit per player and per action.
        rateLimits = {
            login = { limit = 6, windowSeconds = 60 },
            register = { limit = 3, windowSeconds = 120 },
            resume = { limit = 10, windowSeconds = 60 }
        },

        failedLoginLock = {
            attempts = 5,
            lockSeconds = 15 * 60
        },

        rememberSession = {
            enabled = true,
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

    ui = {
        url = "http://mta/local/html/auth/index.html",
        toggleDevToolsKey = "F10"
    }
}
