HeavyRPG = HeavyRPG or {}
local HRP = HeavyRPG

HRP.LocalStorage = HRP.LocalStorage or {}
HRP.LocalStorage.path = "heavyrpg_session.json"

local function readAll(path)
    if not fileExists(path) then return nil end
    local f = fileOpen(path, true)
    if not f then return nil end
    local size = fileGetSize(f)
    local content = size > 0 and fileRead(f, size) or ""
    fileClose(f)
    return content
end

local function writeAll(path, content)
    if fileExists(path) then fileDelete(path) end
    local f = fileCreate(path)
    if not f then return false end
    fileWrite(f, content or "")
    fileClose(f)
    return true
end

function HRP.LocalStorage.getSessionToken()
    local content = readAll(HRP.LocalStorage.path)
    if not content or #content == 0 then return nil end
    local data = fromJSON(content)
    if type(data) ~= "table" then return nil end
    if type(data.token) ~= "string" then return nil end
    return data.token
end

function HRP.LocalStorage.setSessionToken(token)
    if type(token) ~= "string" or #token == 0 then return false end
    return writeAll(HRP.LocalStorage.path, toJSON({ token = token, savedAt = HRP.Utils.now() }, true))
end

function HRP.LocalStorage.clearSessionToken()
    if fileExists(HRP.LocalStorage.path) then
        fileDelete(HRP.LocalStorage.path)
    end
end
