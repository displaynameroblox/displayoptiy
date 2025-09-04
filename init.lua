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
local PlaybackManager = requireFromUrl("PlaybackManager.lua")
local UIManager = requireFromUrl("UIManager.lua")
local PlaylistManager = requireFromUrl("PlaylistManager.lua")
local ThemeManager = requireFromUrl("ThemeManager.lua")

-- Initialize system
local MusicPlayer = {}
MusicPlayer.Playback = PlaybackManager
MusicPlayer.UI = UIManager
MusicPlayer.Playlist = PlaylistManager
MusicPlayer.Theme = ThemeManager

-- Boot UI (only if UIManager loaded successfully)
if MusicPlayer.UI and MusicPlayer.UI.init then
    MusicPlayer.UI.init(MusicPlayer)
else
    warn("UIManager failed to load or 'init' missing")
end

return MusicPlayer
