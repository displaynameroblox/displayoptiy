-- init.lua

local REPO_PATH = "displaynameroblox/displayoptiy/main/"

local BASE_URL = "https://raw.githubusercontent.com/"

-- Simple require-from-web
local function requireFromUrl(file)
    local url = BASE_URL .. REPO_PATH .. file
    local success, source = pcall(function() return game:HttpGet(url) end)
    if not success or not source then
        warn("Failed to load " .. file .. " from " .. url)
        return nil
    end
    local loaded = loadstring(source)
    if not loaded then
        warn("Failed to loadstring for " .. file)
        return nil
    end
    return loaded()
end

-- Load modules
local Util = require(root.Util)
local Storage = require(root.Storage)
local ThemeManager = require(root.ThemeManager)
local PlaylistManager = require(root.PlaylistManager)
local UIManager = require(root.UIManager)
local PlaybackManager = require(root.PlaybackManager)
local Main = require(root.Main) -- this auto-runs

return {
    Util = Util,
    Storage = Storage,
    ThemeManager = ThemeManager,
    PlaylistManager = PlaylistManager,
    UIManager = UIManager,
    PlaybackManager = PlaybackManager,
    Main = Main
}
