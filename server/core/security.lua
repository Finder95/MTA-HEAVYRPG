HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Security = HRP.Security or {}
HRP.Security.buckets = setmetatable({}, { __mode = "k" })

local function cleanupBucket(bucket, now, windowMs)
    local i = 1
    while i <= #bucket do
        if now - bucket[i] > windowMs then
            table.remove(bucket, i)
        else
            i = i + 1
        end
    end
end

function HRP.Security.checkRateLimit(player, action)
    if not isElement(player) or getElementType(player) ~= "player" then
        return false, "invalid_player"
    end

    local config = HRP.Config.auth.rateLimits[action]
    if not config then return true end

    local now = getTickCount()
    local windowMs = (config.windowSeconds or 60) * 1000
    local limit = config.limit or 5

    HRP.Security.buckets[player] = HRP.Security.buckets[player] or {}
    local userBuckets = HRP.Security.buckets[player]
    userBuckets[action] = userBuckets[action] or {}
    local bucket = userBuckets[action]

    cleanupBucket(bucket, now, windowMs)

    if #bucket >= limit then
        return false, "Za duzo prob. Odczekaj chwile."
    end

    bucket[#bucket + 1] = now
    return true
end

function HRP.Security.audit(accountId, username, action, success, player, reason)
    local serial = isElement(player) and getPlayerSerial(player) or nil
    local ip = isElement(player) and getPlayerIP(player) or nil

    HRP.DB.exec([[INSERT INTO auth_audit(account_id, username, action, success, ip, serial, reason, created_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?)]], {
        accountId,
        username,
        action,
        success and 1 or 0,
        ip,
        serial,
        reason,
        HRP.Utils.now()
    })
end

addEventHandler("onPlayerQuit", root, function()
    HRP.Security.buckets[source] = nil
end)
