--[[
Displayoptiy / UIManager.lua
Builds and manages the player UI.
Connects PlaybackManager, PlaylistManager, ThemeManager.
]]

local Util = require(script.Parent.Util)
local ThemeManager = require(script.Parent.ThemeManager)
local PlaylistManager = require(script.Parent.PlaylistManager)

local UIManager = {}

UIManager.ScreenGui = nil

--//////////// Internal helpers ////////////--
local function makeButton(name, text, pos, size)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Text = text
    btn.Position = pos
    btn.Size = size
    btn.BackgroundColor3 = ThemeManager.getTheme().Secondary
    btn.TextColor3 = ThemeManager.getTheme().Foreground
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.AutoButtonColor = true
    return btn
end

local function applyThemeToGui(gui)
    local theme = ThemeManager.getTheme()
    for _,desc in ipairs(gui:GetDescendants()) do
        if desc:IsA("Frame") or desc:IsA("TextButton") or desc:IsA("TextLabel") then
            if desc:IsA("Frame") then
                desc.BackgroundColor3 = theme.Background
            else
                desc.BackgroundColor3 = theme.Secondary
                desc.TextColor3 = theme.Foreground
            end
        end
    end
end

--//////////// API ////////////--
function UIManager.init(App)
    -- ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name = "DisplayoptiyUI"
    sg.ResetOnSpawn = false
    sg.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    UIManager.ScreenGui = sg

    -- Main Frame
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 400, 0, 250)
    frame.Position = UDim2.new(0.5, -200, 0.5, -125)
    frame.BackgroundColor3 = ThemeManager.getTheme().Background
    frame.BorderSizePixel = 0
    frame.Parent = sg

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "Displayoptiy Player"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = ThemeManager.getTheme().Foreground
    title.Parent = frame

    -- Buttons
    local playBtn = makeButton("Play", "Play", UDim2.new(0,10,0,60), UDim2.new(0,100,0,40))
    playBtn.Parent = frame

    local pauseBtn = makeButton("Pause", "Pause", UDim2.new(0,120,0,60), UDim2.new(0,100,0,40))
    pauseBtn.Parent = frame

    local nextBtn = makeButton("Next", "Next", UDim2.new(0,230,0,60), UDim2.new(0,100,0,40))
    nextBtn.Parent = frame

    local prevBtn = makeButton("Prev", "Prev", UDim2.new(0,10,0,110), UDim2.new(0,100,0,40))
    prevBtn.Parent = frame

    -- Playlist dropdown (basic)
    local playlistBox = Instance.new("TextBox")
    playlistBox.Name = "PlaylistBox"
    playlistBox.PlaceholderText = "Playlist Name"
    playlistBox.Size = UDim2.new(0,200,0,30)
    playlistBox.Position = UDim2.new(0,10,0,170)
    playlistBox.BackgroundColor3 = ThemeManager.getTheme().Secondary
    playlistBox.TextColor3 = ThemeManager.getTheme().Foreground
    playlistBox.Font = Enum.Font.Gotham
    playlistBox.TextSize = 14
    playlistBox.Parent = frame

    local addPlaylistBtn = makeButton("AddPlaylist","Add",UDim2.new(0,220,0,170),UDim2.new(0,80,0,30))
    addPlaylistBtn.Parent = frame

    -- Hook up events later when PlaybackManager is loaded
    UIManager._elements = {
        Frame = frame,
        Play = playBtn,
        Pause = pauseBtn,
        Next = nextBtn,
        Prev = prevBtn,
        PlaylistBox = playlistBox,
        AddPlaylist = addPlaylistBtn
    }

    -- React to theme changes
    ThemeManager.OnThemeChanged:Connect(function()
        applyThemeToGui(frame)
    end)
end

function UIManager.getElements()
    return UIManager._elements or {}
end

return UIManager
