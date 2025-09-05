-- PlaybackManager.lua
return function(deps)
    local Util = deps.Util
    local PlaylistManager = deps.PlaylistManager

    local PlaybackManager = {
        currentSound = nil,
        currentPlaylist = nil,
        currentIndex = 0,
    }

    PlaybackManager.OnTrackChanged = Instance.new("BindableEvent").Event
    PlaybackManager.OnPlayStateChanged = Instance.new("BindableEvent").Event

    function PlaybackManager.play(playlistName, index)
        local tracks = PlaylistManager.getTracks(playlistName)
        if not tracks[index] then return end

        if PlaybackManager.currentSound then
            PlaybackManager.currentSound:Destroy()
        end

        local sound = Instance.new("Sound")
        sound.SoundId = tracks[index].id
        sound.Looped = false
        sound.Parent = game:GetService("SoundService")
        sound:Play()

        PlaybackManager.currentSound = sound
        PlaybackManager.currentPlaylist = playlistName
        PlaybackManager.currentIndex = index

        PlaybackManager.OnTrackChanged:Fire(tracks[index])
        PlaybackManager.OnPlayStateChanged:Fire(true)

        sound.Ended:Connect(function()
            PlaybackManager.next()
        end)
    end

    function PlaybackManager.pause()
        if PlaybackManager.currentSound then
            PlaybackManager.currentSound:Pause()
            PlaybackManager.OnPlayStateChanged:Fire(false)
        end
    end

    function PlaybackManager.resume()
        if PlaybackManager.currentSound then
            PlaybackManager.currentSound:Resume()
            PlaybackManager.OnPlayStateChanged:Fire(true)
        end
    end

    function PlaybackManager.stop()
        if PlaybackManager.currentSound then
            PlaybackManager.currentSound:Stop()
            PlaybackManager.OnPlayStateChanged:Fire(false)
        end
    end

    function PlaybackManager.next()
        if not PlaybackManager.currentPlaylist then return end
        local tracks = PlaylistManager.getTracks(PlaybackManager.currentPlaylist)
        local newIndex = PlaybackManager.currentIndex + 1
        if newIndex > #tracks then newIndex = 1 end
        PlaybackManager.play(PlaybackManager.currentPlaylist, newIndex)
    end

    function PlaybackManager.prev()
        if not PlaybackManager.currentPlaylist then return end
        local tracks = PlaylistManager.getTracks(PlaybackManager.currentPlaylist)
        local newIndex = PlaybackManager.currentIndex - 1
        if newIndex < 1 then newIndex = #tracks end
        PlaybackManager.play(PlaybackManager.currentPlaylist, newIndex)
    end

    return PlaybackManager
end
