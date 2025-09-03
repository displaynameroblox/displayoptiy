-- PlaybackManager.lua
local PlaybackManager = {
    currentTrack = nil,
    repeatMode = "off", -- "off", "one", "all"
    shuffle = false,
    volume = 0.5
}

function PlaybackManager:play(track)
    if self.currentTrack then
        self.currentTrack:Stop()
    end
    self.currentTrack = Instance.new("Sound")
    self.currentTrack.SoundId = track
    self.currentTrack.Volume = self.volume
    self.currentTrack.Parent = game:GetService("SoundService")
    self.currentTrack:Play()
end

function PlaybackManager:pause()
    if self.currentTrack then
        self.currentTrack:Pause()
    end
end

function PlaybackManager:resume()
    if self.currentTrack then
        self.currentTrack:Resume()
    end
end

function PlaybackManager:setVolume(v)
    self.volume = math.clamp(v, 0, 1)
    if self.currentTrack then
        self.currentTrack.Volume = self.volume
    end
end

return PlaybackManager
