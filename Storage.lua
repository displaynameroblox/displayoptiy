--[[
Displayoptiy / Storage.lua
Handles saving/loading playlists and settings.
Uses filesystem if executor supports it; otherwise falls back to in-memory store.
]]

return function(deps)
    local Util = deps.Util

    local Storage = {}

-- Configuration
Storage.FOLDER = "Displayoptiy"
Storage.PLAYLIST_FILE = "playlists.json"
Storage.SETTINGS_FILE = "settings.json"

-- In-memory cache fallback
local memoryCache = {
    playlists = {},
    settings = {}
}

-- Ensure folder for FS mode
if Util.hasFS() then
    Util.ensureFolder(Storage.FOLDER)
end

--//////////// Internal helpers ////////////--
local function safeWrite(path, data)
    if not Util.hasFS() then return false end
    local ok, err = pcall(function()
        writefile(path, data)
    end)
    return ok
end

local function safeRead(path)
    if not Util.hasFS() then return nil end
    local ok, content = pcall(function()
        return readfile(path)
    end)
    if ok then return content end
    return nil
end

--//////////// Playlists ////////////--
function Storage.savePlaylists(tbl)
    if Util.hasFS() then
        local json = Util.jsonEncode(tbl)
        safeWrite(Storage.FOLDER .. "/" .. Storage.PLAYLIST_FILE, json)
    else
        memoryCache.playlists = Util.deepClone(tbl)
    end
end

function Storage.loadPlaylists()
    if Util.hasFS() then
        local content = safeRead(Storage.FOLDER .. "/" .. Storage.PLAYLIST_FILE)
        if content then
            local data = Util.jsonDecode(content)
            if data then return data end
        end
        return {}
    else
        return Util.deepClone(memoryCache.playlists)
    end
end

--//////////// Settings ////////////--
function Storage.saveSettings(tbl)
    if Util.hasFS() then
        local json = Util.jsonEncode(tbl)
        safeWrite(Storage.FOLDER .. "/" .. Storage.SETTINGS_FILE, json)
    else
        memoryCache.settings = Util.deepClone(tbl)
    end
end

function Storage.loadSettings()
    if Util.hasFS() then
        local content = safeRead(Storage.FOLDER .. "/" .. Storage.SETTINGS_FILE)
        if content then
            local data = Util.jsonDecode(content)
            if data then return data end
        end
        return {}
    else
        return Util.deepClone(memoryCache.settings)
    end
end

--//////////// Clear ////////////--
function Storage.clearAll()
    if Util.hasFS() then
        pcall(function()
            delfile(Storage.FOLDER .. "/" .. Storage.PLAYLIST_FILE)
            delfile(Storage.FOLDER .. "/" .. Storage.SETTINGS_FILE)
        end)
    end
    memoryCache.playlists = {}
    memoryCache.settings = {}
end

return Storage
