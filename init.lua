-- init.lua
local BASE_URL = "https://raw.githubusercontent.com/displaynameroblox/displayoptiy"

-- Simple require-from-web
local function requireFromUrl(file)
    local source = game:HttpGet(BASE_URL .. file)
    return loadstring(source)()
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

-- Boot UI
UIManager.init(MusicPlayer)

return MusicPlayer
