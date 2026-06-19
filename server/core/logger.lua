HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.Logger = HRP.Logger or {}

local function line(level, scope, message)
    outputDebugString(string.format("[HeavyRPG:%s][%s] %s", level, tostring(scope or "core"), tostring(message or "")), level == "ERROR" and 1 or level == "WARN" and 2 or 3)
end

function HRP.Logger.info(scope, message)
    line("INFO", scope, message)
end

function HRP.Logger.warn(scope, message)
    line("WARN", scope, message)
end

function HRP.Logger.error(scope, message)
    line("ERROR", scope, message)
end
