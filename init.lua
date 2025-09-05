-- init.lua (GitHub dynamic loader version)

local repoUser = "displaynameroblox"
local repoName = "displayoptiy"
local branch = "main"
local base = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(repoUser, repoName, branch)

local function import(name)
    local url = base .. name .. ".lua"
    local ok, source = pcall(game.HttpGet, game, url)
    if not ok then
        error("❌ Failed to fetch " .. url .. ": " .. tostring(source))
    end

    local fn, err = loadstring(source)
    if not fn then
        error("❌ Failed to compile " .. name .. ": " .. tostring(err))
    end

    local success, result = pcall(fn)
    if not success then
        error("❌ Error while running " .. name .. ": " .. tostring(result))
    end

    return result
end

-- import all modules
local Util = import("Util")
local Storage = import("Storage")({ Util = Util })
local ThemeManager = import("ThemeManager")({ Util = Util, Storage = Storage })
local PlaylistManager = import("PlaylistManager")({ Util = Util, Storage = Storage })
local UIManager = import("UIManager")({ Util = Util, ThemeManager = ThemeManager })
local PlaybackManager = import("PlaybackManager")({ Util = Util, PlaylistManager = PlaylistManager })
local Main = import("Main")({
    Util = Util,
    Storage = Storage,
    ThemeManager = ThemeManager,
    PlaylistManager = PlaylistManager,
    UIManager = UIManager,
    PlaybackManager = PlaybackManager
})
print("working!")
