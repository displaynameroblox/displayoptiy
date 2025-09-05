-- Displayoptiy / Main.lua
-- Main entrypoint. Auto-inits on require.

local Util = require(script.Util)
local Storage = require(script.Storage)
local ThemeManager = require(script.ThemeManager)
local PlaylistManager = require(script.PlaylistManager)
local UIManager = require(script.UIManager)
local PlaybackManager = require(script.PlaybackManager)

local Main = {}

function Main.init()
    UIManager.init()
    local ui = UIManager.getElements()

    -- Buttons
    ui.Play.MouseButton1Click:Connect(function()
        if not PlaybackManager.currentPlaylist then
            local pls = PlaylistManager.listPlaylists()
            if #pls > 0 then
                PlaybackManager.play(pls[1], 1)
            end
        else
            PlaybackManager.resume()
        end
    end)

    ui.Pause.MouseButton1Click:Connect(function()
        PlaybackManager.pause()
    end)

    ui.Next.MouseButton1Click:Connect(function()
        PlaybackManager.next()
    end)

    ui.Prev.MouseButton1Click:Connect(function()
        PlaybackManager.prev()
    end)

    ui.AddPlaylist.MouseButton1Click:Connect(function()
        local name = ui.PlaylistBox.Text
        if name ~= \"\" then
            PlaylistManager.create(name)
            ui.PlaylistBox.Text = \"\"
        end
    end)

    -- Event reactions
    PlaybackManager.OnTrackChanged:Connect(function(track)
        print(\"Now playing:\", track.title)
    end)

    PlaybackManager.OnPlayStateChanged:Connect(function(isPlaying)
        print(\"Playing state:\", isPlaying)
    end)

    ThemeManager.OnThemeChanged:Connect(function(theme)
        print(\"Theme switched to\", ThemeManager.Name)
    end)

    -- Seed default playlist
    if #PlaylistManager.listPlaylists() == 0 then
        PlaylistManager.create(\"Default\")
        PlaylistManager.addTrack(\"Default\", \"rbxassetid://1843522\", \"Test Track\")
    end

    print(\"Displayoptiy Player initialized.\")
end

-- Auto-run
Main.init()

return Main
