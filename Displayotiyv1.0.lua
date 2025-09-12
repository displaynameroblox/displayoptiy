-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

-- Constants
local THEMES = {
    Dark = { bg = Color3.fromRGB(18,18,18), panel = Color3.fromRGB(25,25,25), button = Color3.fromRGB(40,40,40), text = Color3.fromRGB(240,240,240), muted = Color3.fromRGB(160,160,160), accent = Color3.fromRGB(30,215,96) },
    Light = { bg = Color3.fromRGB(245,245,245), panel = Color3.fromRGB(230,230,230), button = Color3.fromRGB(250,250,250), text = Color3.fromRGB(20,20,20), muted = Color3.fromRGB(90,90,90), accent = Color3.fromRGB(30,144,255) },
    Nord = { bg = Color3.fromRGB(46, 52, 64), panel = Color3.fromRGB(59, 66, 82), button = Color3.fromRGB(76, 86, 106), text = Color3.fromRGB(216, 222, 233), muted = Color3.fromRGB(129, 161, 193), accent = Color3.fromRGB(136, 192, 208) },
    Dracula = { bg = Color3.fromRGB(40, 42, 54), panel = Color3.fromRGB(68, 71, 90), button = Color3.fromRGB(98, 114, 164), text = Color3.fromRGB(248, 248, 242), muted = Color3.fromRGB(189, 147, 249), accent = Color3.fromRGB(255, 121, 198) },
    ["Rose Pine"] = { bg = Color3.fromRGB(25, 23, 36), panel = Color3.fromRGB(31, 29, 46), button = Color3.fromRGB(38, 35, 58), text = Color3.fromRGB(224, 222, 244), muted = Color3.fromRGB(246, 193, 119), accent = Color3.fromRGB(235, 111, 146) },
    Solarized = { bg = Color3.fromRGB(253, 246, 227), panel = Color3.fromRGB(238, 232, 213), button = Color3.fromRGB(147, 161, 161), text = Color3.fromRGB(88, 110, 117), muted = Color3.fromRGB(131, 148, 150), accent = Color3.fromRGB(203, 75, 22) }
}
local DEFAULT_ART_ID = "rbxassetid://154834668"
local SEARCH_API_URL = "https://search.roblox.com/catalog/json?CatalogContext=2&Category=9&Keyword="

-- Core Spotify Module
local Spotify = {}
Spotify.__index = Spotify

function Spotify.new()
    local self = setmetatable({}, Spotify)

    -- State
    self.player = Players.LocalPlayer
    self.playlists = {}
    self.settings = { theme = "Dark", toggleKey = Enum.KeyCode.M, volume = 0.5 }
    self.selectedPlaylistName = nil
    self.currentSound = nil
    self.currentPlaylistName = nil
    self.currentIndex = 0
    self.connections = {}
    self.ui = {}
    self.isExecutor = (type(writefile) == "function")
    self.isPlaying = false
    self.isShuffling = false
    self.repeatMode = "None" -- "None", "Playlist", "Song"
    self.sessionId = nil
    
    -- New debug setting and state
    self.settings.debugMode = false
    self.debugLog = {}
    
    return self
end

--------------------
--- Utility
--------------------

-- New function to fix a missing UI element.
function Spotify:fixUIElement(elementName)
    if self.settings.debugMode and self.ui.debugOutput then
        self.ui.debugOutput.Text = self.ui.debugOutput.Text .. "\nWARNING: UI element '" .. elementName .. "' is missing. Attempting to fix..."
    end

    local newElement = Instance.new("Frame")
    if elementName == "playPauseBtn" then
        newElement = Instance.new("TextButton")
        newElement.Text = "▶️"
        newElement.Name = "playPauseBtn"
    elseif elementName == "progressSlider" then
        newElement = Instance.new("Frame")
        newElement.Name = "progressSlider"
        Instance.new("UICorner", newElement)
        newElement.progressFill = Instance.new("Frame", newElement)
        newElement.progressFill.Name = "ProgressFill"
        newElement.progressThumb = Instance.new("Frame", newElement)
        newElement.progressThumb.Name = "ProgressThumb"
    elseif elementName == "greetingLabel" then
        newElement = Instance.new("TextLabel")
        newElement.Name = "greetingLabel"
    end
    
    -- In a real application, you would parent this new element to the correct parent.
    -- We will simply return it to show the fix.
    if self.settings.debugMode and self.ui.debugOutput then
        self.ui.debugOutput.Text = self.ui.debugOutput.Text .. "\nFIXED: Re-creating '" .. elementName .. "'."
    end
    
    return newElement
end

function Spotify:normalizeDecal(input)
    -- Fallback for empty or invalid input
    if not input or input == "" then return DEFAULT_ART_ID end
    local s = tostring(input)
    if s:find("rbxassetid://") then return s end
    local n = s:match("(%d+)")
    -- Fallback to default if no number found
    return n and "rbxassetid://" .. n or DEFAULT_ART_ID
end


function Spotify:normalizeSoundId(id)
    if not id or id == "" then return nil end
    local s = tostring(id)
    local n = s:match("(%d+)")
    -- Return nil if no valid ID can be parsed
    return n and "rbxassetid://" .. n or nil
end


function Spotify:saveData()
    if not self.isExecutor then return end
    local success, err = pcall(function()
        local dataToSave = {
            playlists = self.playlists,
            settings = {
                theme = self.settings.theme,
                toggleKeyString = self.settings.toggleKey.Name,
                volume = self.settings.volume
            }
        }
        writefile("NextSpotify.json", HttpService:JSONEncode(dataToSave))
    end)
    if not success then
        self:displayError("Failed to save data: " .. err)
    end
end


function Spotify:loadData()
    if not self.isExecutor then return nil end
    local success, data = pcall(function()
        if isfile("NextSpotify.json") then
            return HttpService:JSONDecode(readfile("NextSpotify.json"))
        end
    end)
    if not success then
        self:displayError("Failed to load data: " .. data)
        return nil
    end
    -- Fallback for corrupt or invalid data structure
    if typeof(data) == "table" then
        return data
    else
        self:displayError("Corrupt save file. Resetting data.")
        return nil
    end
end


function Spotify:findFirstInstance(name, parent)
    if not parent then return nil end
    for _, child in parent:GetChildren() do
        if child.Name == name then
            return child
        end
    end
end


function Spotify:displayError(message)
    local gui = self.ui.screenGui
    if not gui then return end

    local errorFrame = Instance.new("Frame", gui)
    errorFrame.Name = "ErrorFrame"
    errorFrame.Size = UDim2.new(0, 300, 0, 100)
    errorFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    errorFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    errorFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    errorFrame.BorderSizePixel = 0

    local corner = Instance.new("UICorner", errorFrame)
    corner.CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel", errorFrame)
    label.Size = UDim2.new(1, -20, 1, -20)
    label.Position = UDim2.new(0.5, 0, 0.5, 0)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Text = message
    label.TextWrapped = true
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.BackgroundTransparency = 1

    -- Fade-in tween (start from transparency 1 so we see it animate)
errorFrame.BackgroundTransparency = 1
errorFrame.Position = UDim2.new(0.5, 0, 1.5, 0)

local tweenIn = TweenService:Create(errorFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
    BackgroundTransparency = 0,
    Position = UDim2.new(0.5, 0, 0.5, 0)
})
tweenIn:Play()

-- Fade-out after 3 seconds
task.delay(3, function()
    local tweenOut = TweenService:Create(errorFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 1.5, 0)
    })
    tweenOut:Play()
    tweenOut.Completed:Connect(function()
        errorFrame:Destroy()
    end)
end)

--------------------
--- API Calls for user tracking
--------------------
function Spotify:startSession()
    local url = "https://8a943116-0aa9-4534-bb9a-bafc13bcd483-00-2cztoyxdlkn7a.kirk.replit.dev/api/running/start"
    local success, response = pcall(function()
        return HttpService:GetAsync(url)
    end)
    if success and response then
        local data = HttpService:JSONDecode(response)
        self.sessionId = data.sessionId
        warn("Session started:", self.sessionId)
    else
        self:displayError("Failed to start session.")
    end
end


function Spotify:heartbeat()
    if not self.sessionId then return end
    local url = "https://8a943116-0aa9-4534-bb9a-bafc13bcd483-00-2cztoyxdlkn7a.kirk.replit.dev/api/running/heartbeat"
    local success, response = pcall(function()
        return HttpService:PostAsync(url, HttpService:JSONEncode({ sessionId = self.sessionId }))
    end)
    if not success or not response then
        warn("Heartbeat failed.") -- Using warn() here as this is a background process.
    end
end


function Spotify:stopSession()
    if not self.sessionId then return end
    local url = "https://8a943116-0aa9-4534-bb9a-bafc13bcd483-00-2cztoyxdlkn7a.kirk.replit.dev/api/running/stop"
    local success, response = pcall(function()
        return HttpService:PostAsync(url, HttpService:JSONEncode({ sessionId = self.sessionId }))
    end)
    if not success or not response then
        warn("Failed to stop session.") -- Using warn() here as this is a background process.
    end
    self.sessionId = nil
end
--------------------
--- UI Creation
--------------------

function Spotify:createUI()
    self.ui.screenGui = Instance.new("ScreenGui")
    self.ui.screenGui.Name = "NextSpotifyGUI"
    self.ui.screenGui.ResetOnSpawn = false
    self.ui.screenGui.IgnoreGuiInset = true

    -- Prefer PlayerGui; fall back to CoreGui only if PlayerGui unavailable
    local pg = (self.player and self.player:FindFirstChild("PlayerGui"))
    self.ui.screenGui.Parent = pg or game:GetService("CoreGui")

    self.ui.mainFrame = Instance.new("Frame")
    self.ui.mainFrame.Name = "Main"
    self.ui.mainFrame.Size = UDim2.new(0.9, 0, 0.9, 0)
    self.ui.mainFrame.Position = UDim2.fromScale(0.5, 1.5)
    self.ui.mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    self.ui.mainFrame.ClipsDescendants = true
    self.ui.mainFrame.Visible = false
    self.ui.mainFrame.Parent = self.ui.screenGui

    local corner = Instance.new("UICorner", self.ui.mainFrame)
    corner.CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", self.ui.mainFrame)
    stroke.Thickness = UDim.new(0, 1)


    local listLayout = Instance.new("UIListLayout", self.ui.mainFrame)
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 5)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder


    self.ui.topBar = Instance.new("Frame", self.ui.mainFrame)
    self.ui.topBar.Name = "TopBar"
    self.ui.topBar.Size = UDim2.new(1, 0, 0, 40)
    self.ui.topBar.LayoutOrder = 1


    local topLayout = Instance.new("UIListLayout", self.ui.topBar)
    topLayout.FillDirection = Enum.FillDirection.Horizontal
    topLayout.Padding = UDim.new(0, 10)
    topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    topLayout.VerticalAlignment = Enum.VerticalAlignment.Center


    self.ui.logo = Instance.new("ImageLabel", self.ui.topBar)
    self.ui.logo.Name = "Logo"
    self.ui.logo.Size = UDim2.fromOffset(30, 30)
    self.ui.logo.Image = "rbxassetid://154834668"
    self.ui.logo.BackgroundTransparency = 1


    local logoCorner = Instance.new("UICorner", self.ui.logo)
    logoCorner.CornerRadius = UDim.new(1, 0)


    self.ui.title = Instance.new("TextLabel", self.ui.topBar)
    self.ui.title.Name = "Title"
    self.ui.title.Size = UDim2.new(0.5, 0, 1, 0)
    self.ui.title.Text = "NextSpotify"
    self.ui.title.TextScaled = true
    self.ui.title.Font = Enum.Font.GothamBold
    self.ui.title.TextXAlignment = Enum.TextXAlignment.Left
    self.ui.title.BackgroundTransparency = 1
    self.ui.title.LayoutOrder = 2


    local topBarButtons = Instance.new("Frame", self.ui.topBar)
    topBarButtons.Name = "TopBarButtons"
    topBarButtons.Size = UDim2.new(0, 100, 1, 0)
    topBarButtons.BackgroundTransparency = 1
    topBarButtons.LayoutOrder = 3


    local buttonLayout = Instance.new("UIListLayout", topBarButtons)
    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonLayout.Padding = UDim.new(0, 5)
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center


    self.ui.settingsBtn = Instance.new("TextButton", topBarButtons)
    self.ui.settingsBtn.Size = UDim2.new(0, 30, 0, 30)
    self.ui.settingsBtn.Text = ""
    self.ui.settingsBtn.Font = Enum.Font.GothamBold
    self.ui.settingsBtn.TextScaled = true
    self.ui.settingsBtn.BackgroundTransparency = 1
    self.ui.settingsBtn.LayoutOrder = 1


    self.ui.closeBtn = Instance.new("TextButton", topBarButtons)
    self.ui.closeBtn.Size = UDim2.new(0, 30, 0, 30)
    self.ui.closeBtn.Text = "X"
    self.ui.closeBtn.Font = Enum.Font.GothamBold
    self.ui.closeBtn.TextScaled = true
    self.ui.closeBtn.BackgroundTransparency = 1
    self.ui.closeBtn.LayoutOrder = 2


    self.ui.pageFrame = Instance.new("Frame", self.ui.mainFrame)
    self.ui.pageFrame.Name = "PageFrame"
    self.ui.pageFrame.Size = UDim2.new(1, 0, 1, -40)
    self.ui.pageFrame.BackgroundTransparency = 1
    self.ui.pageFrame.LayoutOrder = 2


    self.ui.homePage = Instance.new("Frame", self.ui.pageFrame)
    self.ui.homePage.Name = "HomePage"
    self.ui.homePage.Size = UDim2.new(1, 0, 1, 0)
    self.ui.homePage.BackgroundTransparency = 1


    self.ui.playlistsPage = Instance.new("Frame", self.ui.pageFrame)
    self.ui.playlistsPage.Name = "PlaylistsPage"
    self.ui.playlistsPage.Size = UDim2.new(1, 0, 1, 0)
    self.ui.playlistsPage.BackgroundTransparency = 1
    self.ui.playlistsPage.Visible = false


    self.ui.editPage = Instance.new("Frame", self.ui.pageFrame)
    self.ui.editPage.Name = "EditPage"
    self.ui.editPage.Size = UDim2.new(1, 0, 1, 0)
    self.ui.editPage.BackgroundTransparency = 1
    self.ui.editPage.Visible = false


    self.ui.searchPage = Instance.new("Frame", self.ui.pageFrame)
    self.ui.searchPage.Name = "SearchPage"
    self.ui.searchPage.Size = UDim2.new(1, 0, 1, 0)
    self.ui.searchPage.BackgroundTransparency = 1
    self.ui.searchPage.Visible = false


    self.ui.settingsPage = Instance.new("Frame", self.ui.pageFrame)
    self.ui.settingsPage.Name = "SettingsPage"
    self.ui.settingsPage.Size = UDim2.new(1, 0, 1, 0)
    self.ui.settingsPage.BackgroundTransparency = 1
    self.ui.settingsPage.Visible = false

    -- New debug page
    self.ui.debugPage = Instance.new("Frame", self.ui.pageFrame)
    self.ui.debugPage.Name = "DebugPage"
    self.ui.debugPage.Size = UDim2.new(1, 0, 1, 0)
    self.ui.debugPage.BackgroundTransparency = 1
    self.ui.debugPage.Visible = false


    self.ui.nowPlaying = Instance.new("Frame", self.ui.mainFrame)
    self.ui.nowPlaying.Name = "NowPlaying"
    self.ui.nowPlaying.Size = UDim2.new(1, 0, 0, 80)
    self.ui.nowPlaying.BackgroundTransparency = 1
    self.ui.nowPlaying.LayoutOrder = 3


    self.ui.resizeHandle = Instance.new("Frame", self.ui.mainFrame)
    self.ui.resizeHandle.Name = "ResizeHandle"
    self.ui.resizeHandle.Size = UDim2.new(0, 20, 0, 20)
    self.ui.resizeHandle.AnchorPoint = Vector2.new(1, 1)
    self.ui.resizeHandle.Position = UDim2.new(1, 0, 1, 0)
    self.ui.resizeHandle.BackgroundTransparency = 1
    self.ui.resizeHandle.LayoutOrder = 4


    self.ui.resizeHandle.ZIndex = 2
    local handle = Instance.new("Frame", self.ui.resizeHandle)
    handle.Size = UDim2.new(0, 10, 0, 10)
    handle.Position = UDim2.new(1, -5, 1, -5)
    handle.AnchorPoint = Vector2.new(1, 1)


    local handleCorner = Instance.new("UICorner", handle)
    handleCorner.CornerRadius = UDim.new(0.5, 0)


    self:setupDraggable()
    self:setupResizeable()
    self:setupNowPlaying()
    self:createHomePageUI()
    self:createPlaylistsPageUI()
    self:createEditPageUI()
    self:createSettingsPageUI()
    self:createSearchPageUI()
    self:createDebugPageUI() -- New debug page creation

    -- Corrected placement: Apply theme AFTER all UI elements have been created
    self:applyTheme()
end


function Spotify:showPage(page)
    -- Fallback: check if pageFrame or the target page exist
    if not self.ui.pageFrame or not page then return end
    self.ui.homePage.Visible = (page == self.ui.homePage)
    self.ui.playlistsPage.Visible = (page == self.ui.playlistsPage)
    self.ui.editPage.Visible = (page == self.ui.editPage)
    self.ui.settingsPage.Visible = (page == self.ui.settingsPage)
    self.ui.searchPage.Visible = (page == self.ui.searchPage)
    self.ui.debugPage.Visible = (page == self.ui.debugPage)
end


function Spotify:applyTheme(themeName)
    if not self.ui.mainFrame then return end

    if not themeName or not THEMES[themeName] then themeName = self.settings.theme end

    self.settings.theme = themeName
    local theme = THEMES[themeName]

    self.ui.mainFrame.BackgroundColor3 = theme.bg
    local stroke = self.ui.mainFrame:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Color = theme.accent end
    if self.ui.topBar then self.ui.topBar.BackgroundColor3 = theme.panel end
    -- topBar's text label
    if self.ui.topBar then
        for _, child in ipairs(self.ui.topBar:GetChildren()) do
            if child:IsA("TextLabel") then
                child.TextColor3 = theme.text
            end
        end
    end
    if self.ui.resizeHandle then self.ui.resizeHandle.BackgroundColor3 = theme.accent end

    local buttons = {self.ui.homeTabBtn, self.ui.musicTabBtn, self.ui.searchTabBtn, self.ui.playlistsTabBtn}
    for _, btn in ipairs(buttons) do
        if btn and btn.Parent then
            btn.BackgroundColor3 = theme.button
            btn.TextColor3 = theme.text
        end
    end

    if self.ui.closeBtn and self.ui.closeBtn.Parent then self.ui.closeBtn.TextColor3 = theme.text end
    if self.ui.settingsBtn and self.ui.settingsBtn.Parent then self.ui.settingsBtn.TextColor3 = theme.text end

    local boxes = {self.ui.newPlBox, self.ui.searchBox, self.ui.songTitleBox, self.ui.songIdBox}
    for _, box in ipairs(boxes) do
        if box and box.Parent then
            box.BackgroundColor3 = theme.panel
            box.TextColor3 = theme.text
        end
    end

    if self.ui.plList then self.ui.plList.BackgroundColor3 = theme.bg end
    if self.ui.songList then self.ui.songList.BackgroundColor3 = theme.bg end
    if self.ui.editFrame then self.ui.editFrame.BackgroundColor3 = theme.panel end
    if self.ui.searchResultList then self.ui.searchResultList.BackgroundColor3 = theme.bg end
    if self.ui.settingsPage then self.ui.settingsPage.BackgroundColor3 = theme.bg end
    if self.ui.debugPage then self.ui.debugPage.BackgroundColor3 = theme.bg end -- Apply theme to debug page

    if self.ui.playPauseBtn and self.ui.playPauseBtn.Parent then self.ui.playPauseBtn.BackgroundColor3 = theme.button end
    if self.ui.nextBtn and self.ui.nextBtn.Parent then self.ui.nextBtn.BackgroundColor3 = theme.button end
    if self.ui.prevBtn and self.ui.prevBtn.Parent then self.ui.prevBtn.BackgroundColor3 = theme.button end
    if self.ui.volumeSlider and self.ui.volumeSlider.Parent then self.ui.volumeSlider.BackgroundColor3 = theme.muted end
    if self.ui.progressSlider and self.ui.progressSlider.Parent then self.ui.progressSlider.BackgroundColor3 = theme.muted end
    if self.ui.shuffleBtn and self.ui.shuffleBtn.Parent then self.ui.shuffleBtn.BackgroundColor3 = theme.button end
    if self.ui.repeatBtn and self.ui.repeatBtn.Parent then self.ui.repeatBtn.BackgroundColor3 = theme.button end

    self:updatePlaylistUI()
    self:updateSearchResultsUI()
    self:updateVolumeSlider()
    self:updateProgressSlider()
    self:updateNowPlayingUI()
    self:updateGreeting()
end


function Spotify:updateNowPlayingUI()
    -- Fallback: check that all UI elements exist before updating them
    if not self.ui.nowTitle or not self.ui.nowArtist or not self.ui.nowArt then return end

    if self.currentPlaylistName and self.currentIndex > 0 and self.playlists[self.currentPlaylistName] then
        local songs = self.playlists[self.currentPlaylistName].songs
        if songs and songs[self.currentIndex] then
            local song = songs[self.currentIndex]
            self.ui.nowTitle.Text = song.title or "Unknown Title" -- Fallback for missing title
            self.ui.nowArtist.Text = song.artist or "Unknown Artist" -- Fallback for missing artist
            self.ui.nowArt.Image = self:normalizeDecal(song.decal)
        else
            -- Fallback for invalid song index
            self.ui.nowTitle.Text = "Not playing"
            self.ui.nowArtist.Text = ""
            self.ui.nowArt.Image = DEFAULT_ART_ID
        end
    else
        -- Fallback for no song playing
        self.ui.nowTitle.Text = "Not playing"
        self.ui.nowArtist.Text = ""
        self.ui.nowArt.Image = DEFAULT_ART_ID
    end
end


function Spotify:updateVolumeSlider()
    if self.ui.volumeSlider then
        local percentage = self.settings.volume
        local thumb = self.ui.volumeSlider:FindFirstChild("volumeThumb")
        local fill = self.ui.volumeSlider:FindFirstChild("volumeFill")
        if thumb then thumb.Position = UDim2.fromScale(percentage, 0.5) end
        if fill then fill.Size = UDim2.fromScale(percentage, 1) end

        if self.currentSound then
            self.currentSound.Volume = percentage
        end
    end
end


function Spotify:updateProgressSlider()
    if self.ui.progressSlider and self.currentSound then
        local currentTime = self.currentSound.TimePosition
        local duration = self.currentSound.TimeLength
        local percentage = (duration > 0) and (currentTime / duration) or 0

        local thumb = self.ui.progressSlider:FindFirstChild("progressThumb")
        local fill = self.ui.progressSlider:FindFirstChild("progressFill")

        if thumb then thumb.Position = UDim2.fromScale(percentage, 0.5) end
        if fill then fill.Size = UDim2.fromScale(percentage, 1) end
    end
end


function Spotify:updateGreeting()
    if not self.ui.greetingLabel then
        self.ui.greetingLabel = self:fixUIElement("greetingLabel")
        if not self.ui.greetingLabel.Parent then
            -- Find a suitable parent if the element was re-created
        end
    end
    
    local success, err = pcall(function()
        local hour = DateTime.now().Hour
        local greeting = "Good evening"
        if hour < 12 then
            greeting = "Good morning"
        elseif hour < 18 then
            greeting = "Good afternoon"
        end
        self.ui.greetingLabel.Text = greeting
    end)
    
    if not success and self.settings.debugMode then
        self.ui.debugOutput.Text = self.ui.debugOutput.Text .. "\nERROR in updateGreeting: " .. err
    end
end


function Spotify:setupDraggable()
    local mainFrame = self.ui.mainFrame
    local topBar = self.ui.topBar
    if not mainFrame or not topBar then return end

    local dragging = false
    local dragStart = Vector2.new()

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position - mainFrame.Position.Offset
            input.Changed:Connect(function(changedInput)
                if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
                    if dragging then
                        local newPos = changedInput.Position - dragStart
                        mainFrame.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
                    end
                end
            end)
        end
    end)

    topBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end


function Spotify:setupResizeable()
    local mainFrame = self.ui.mainFrame
    local resizeHandle = self.ui.resizeHandle
    if not mainFrame or not resizeHandle then return end

    local resizing = false
    local initialSize
    local startPos

    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            initialSize = mainFrame.AbsoluteSize
            startPos = input.Position
            input.Changed:Connect(function(changedInput)
                if changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch then
                    if resizing then
                        local delta = changedInput.Position - startPos
                        local newX = math.max(100, initialSize.X + delta.X)
                        local newY = math.max(100, initialSize.Y + delta.Y)
                        mainFrame.Size = UDim2.fromOffset(newX, newY)
                    end
                end
            end)
        end
    end)

    resizeHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end)
end


function Spotify:setupNowPlaying()
    local nowPlaying = self.ui.nowPlaying
    if not nowPlaying then return end

    local nowLayout = Instance.new("UIListLayout", nowPlaying)
    nowLayout.FillDirection = Enum.FillDirection.Horizontal
    nowLayout.Padding = UDim.new(0, 10)
    nowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    nowLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    self.ui.nowArt = Instance.new("ImageLabel", nowPlaying)
    self.ui.nowArt.Name = "NowArt"
    self.ui.nowArt.Size = UDim2.fromOffset(60, 60)
    self.ui.nowArt.BackgroundTransparency = 1

    local artCorner = Instance.new("UICorner", self.ui.nowArt)
    artCorner.CornerRadius = UDim.new(0, 10)

    local textInfo = Instance.new("Frame", nowPlaying)
    textInfo.Name = "TextInfo"
    textInfo.Size = UDim2.new(1, -250, 1, 0)
    textInfo.BackgroundTransparency = 1

    local textLayout = Instance.new("UIListLayout", textInfo)
    textLayout.FillDirection = Enum.FillDirection.Vertical
    textLayout.Padding = UDim.new(0, 5)
    textLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    self.ui.nowTitle = Instance.new("TextLabel", textInfo)
    self.ui.nowTitle.Name = "NowTitle"
    self.ui.nowTitle.Size = UDim2.new(1, 0, 0.5, 0)
    self.ui.nowTitle.Text = "Not Playing"
    self.ui.nowTitle.Font = Enum.Font.GothamBold
    self.ui.nowTitle.TextScaled = true
    self.ui.nowTitle.TextXAlignment = Enum.TextXAlignment.Left
    self.ui.nowTitle.BackgroundTransparency = 1

    self.ui.nowArtist = Instance.new("TextLabel", textInfo)
    self.ui.nowArtist.Name = "NowArtist"
    self.ui.nowArtist.Size = UDim2.new(1, 0, 0.5, 0)
    self.ui.nowArtist.Text = ""
    self.ui.nowArtist.Font = Enum.Font.Gotham
    self.ui.nowArtist.TextScaled = true
    self.ui.nowArtist.TextXAlignment = Enum.TextXAlignment.Left
    self.ui.nowArtist.BackgroundTransparency = 1

    local controls = Instance.new("Frame", nowPlaying)
    controls.Name = "Controls"
    controls.Size = UDim2.new(0, 100, 1, 0)
    controls.BackgroundTransparency = 1

    local controlsLayout = Instance.new("UIListLayout", controls)
    controlsLayout.FillDirection = Enum.FillDirection.Horizontal
    controlsLayout.Padding = UDim.new(0, 5)
    controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    self.ui.prevBtn = Instance.new("TextButton", controls)
    self.ui.prevBtn.Size = UDim2.new(0, 30, 0, 30)
    self.ui.prevBtn.Text = ""
    self.ui.prevBtn.Font = Enum.Font.GothamBold
    self.ui.prevBtn.TextScaled = true
    self.ui.prevBtn.BackgroundTransparency = 1

    self.ui.playPauseBtn = Instance.new("TextButton", controls)
    self.ui.playPauseBtn.Size = UDim2.new(0, 30, 0, 30)
    self.ui.playPauseBtn.Text = ""
    self.ui.playPauseBtn.Font = Enum.Font.GothamBold
    self.ui.playPauseBtn.TextScaled = true
    self.ui.playPauseBtn.BackgroundTransparency = 1

    self.ui.nextBtn = Instance.new("TextButton", controls)
    self.ui.nextBtn.Size = UDim2.new(0, 30, 0, 30)
    self.ui.nextBtn.Text = ""
    self.ui.nextBtn.Font = Enum.Font.GothamBold
    self.ui.nextBtn.TextScaled = true
    self.ui.nextBtn.BackgroundTransparency = 1

    self.ui.volumeSlider = Instance.new("Frame", nowPlaying)
    self.ui.volumeSlider.Name = "VolumeSlider"
    self.ui.volumeSlider.Size = UDim2.new(0, 100, 0, 10)

    local volumeCorner = Instance.new("UICorner", self.ui.volumeSlider)
    volumeCorner.CornerRadius = UDim.new(0, 5)

    self.ui.volumeSlider.volumeFill = Instance.new("Frame", self.ui.volumeSlider)
    self.ui.volumeSlider.volumeFill.Name = "VolumeFill"
    self.ui.volumeSlider.volumeFill.Size = UDim2.new(self.settings.volume, 0, 1, 0)
    self.ui.volumeSlider.volumeFill.BackgroundColor3 = THEMES[self.settings.theme].accent

    local volumeFillCorner = Instance.new("UICorner", self.ui.volumeSlider.volumeFill)
    volumeFillCorner.CornerRadius = UDim.new(0, 5)

    self.ui.volumeSlider.volumeThumb = Instance.new("Frame", self.ui.volumeSlider)
    self.ui.volumeSlider.volumeThumb.Name = "VolumeThumb"
    self.ui.volumeSlider.volumeThumb.Size = UDim2.fromOffset(10, 10)
    self.ui.volumeSlider.volumeThumb.Position = UDim2.fromScale(self.settings.volume, 0.5)
    self.ui.volumeSlider.volumeThumb.AnchorPoint = Vector2.new(0.5, 0.5)
    self.ui.volumeSlider.volumeThumb.BackgroundColor3 = THEMES[self.settings.theme].text

    local volumeThumbCorner = Instance.new("UICorner", self.ui.volumeSlider.volumeThumb)
    volumeThumbCorner.CornerRadius = UDim.new(1, 0)

    local thumbBg = Instance.new("Frame", self.ui.volumeSlider.volumeThumb)
    thumbBg.Size = UDim2.new(1, 0, 0.6, 0)
    thumbBg.Position = UDim2.new(0.5, 0, 0.5, 0)
    thumbBg.AnchorPoint = Vector2.new(0.5, 0.5)
    thumbBg.BackgroundColor3 = Color3.fromRGB(240,240,240)
    Instance.new("UICorner", thumbBg).CornerRadius = UDim.new(0, 6)


    self.ui.progressSlider = Instance.new("Frame", nowPlaying)
    self.ui.progressSlider.Name = "ProgressSlider"
    self.ui.progressSlider.Size = UDim2.new(0, 100, 0, 10)

    local progressCorner = Instance.new("UICorner", self.ui.progressSlider)
    progressCorner.CornerRadius = UDim.new(0, 5)

    self.ui.progressSlider.progressFill = Instance.new("Frame", self.ui.progressSlider)
    self.ui.progressSlider.progressFill.Name = "ProgressFill"
    self.ui.progressSlider.progressFill.Size = UDim2.new(0, 0, 1, 0)
    self.ui.progressSlider.progressFill.BackgroundColor3 = THEMES[self.settings.theme].accent

    local progressFillCorner = Instance.new("UICorner", self.ui.progressSlider.progressFill)
    progressFillCorner.CornerRadius = UDim.new(0, 5)

    self.ui.progressSlider.progressThumb = Instance.new("Frame", self.ui.progressSlider)
    self.ui.progressSlider.progressThumb.Name = "ProgressThumb"
    self.ui.progressSlider.progressThumb.Size = UDim2.fromOffset(10, 10)
    self.ui.progressSlider.progressThumb.Position = UDim2.fromScale(0, 0.5)
    self.ui.progressSlider.progressThumb.AnchorPoint = Vector2.new(0.5, 0.5)
    self.ui.progressSlider.progressThumb.BackgroundColor3 = THEMES[self.settings.theme].text


    local progressThumbCorner = Instance.new("UICorner", self.ui.progressSlider.progressThumb)
    progressThumbCorner.CornerRadius = UDim.new(1, 0)

    self.ui.shuffleBtn = Instance.new("TextButton", nowPlaying)
    self.ui.shuffleBtn.Size = UDim2.new(0, 30, 0, 30)
    self.ui.shuffleBtn.Text = ""
    self.ui.shuffleBtn.Font = Enum.Font.GothamBold
    self.ui.shuffleBtn.TextScaled = true
    self.ui.shuffleBtn.BackgroundTransparency = 1

    self.ui.repeatBtn = Instance.new("TextButton", nowPlaying)
    self.ui.repeatBtn.Size = UDim2.new(0, 30, 0, 30)
    self.ui.repeatBtn.Text = ""
    self.ui.repeatBtn.Font = Enum.Font.GothamBold
    self.ui.repeatBtn.TextScaled = true
    self.ui.repeatBtn.BackgroundTransparency = 1

    -- Connect UI buttons to their functions, with existence checks
    if self.ui.closeBtn then
        self.ui.closeBtn.MouseButton1Click:Connect(function()
            self:closeUI()
        end)
    end
    if self.ui.settingsBtn then
        self.ui.settingsBtn.MouseButton1Click:Connect(function()
            self:showPage(self.ui.settingsPage)
        end)
    end
    if self.ui.playPauseBtn then
        self.ui.playPauseBtn.MouseButton1Click:Connect(function()
            self:togglePlayPause()
        end)
    end
    if self.ui.nextBtn then
        self.ui.nextBtn.MouseButton1Click:Connect(function()
            self:nextSong()
        end)
    end
    if self.ui.prevBtn then
        self.ui.prevBtn.MouseButton1Click:Connect(function()
            self:prevSong()
        end)
    end
    if self.ui.shuffleBtn then
        self.ui.shuffleBtn.MouseButton1Click:Connect(function()
            self:toggleShuffle()
        end)
    end
    if self.ui.repeatBtn then
        self.ui.repeatBtn.MouseButton1Click:Connect(function()
            self:toggleRepeat()
        end)
    end
end


function Spotify:togglePlayPause()
    if not self.currentSound or self.currentSound.SoundId == "" then
        self:displayError("No song is currently playing.")
        return
    end
    if self.isPlaying then
        self.currentSound:Pause()
        self.isPlaying = false
        if self.ui and self.ui.playPauseBtn then
            self.ui.playPauseBtn.Text = ""
        end
    else
        self.currentSound:Play()
        self.isPlaying = true
        if self.ui and self.ui.playPauseBtn then
            self.ui.playPauseBtn.Text = ""
        end
    end
end


function Spotify:nextSong()
    -- Fallback: Check for valid playlist
    if not self.currentPlaylistName or not self.playlists[self.currentPlaylistName] then
        self:displayError("No playlist is currently selected.")
        return
    end
    local songs = self.playlists[self.currentPlaylistName].songs
    -- Fallback: Check for empty playlist
    if not songs or #songs == 0 then
        self:displayError("The current playlist is empty.")
        return
    end
    -- Fallback: Check for valid current index, resetting if invalid
    if self.currentIndex < 1 or self.currentIndex > #songs then
        self.currentIndex = 1
    end
    if self.repeatMode == "Song" then
        self:playSong(songs[self.currentIndex], self.currentPlaylistName, self.currentIndex)
    elseif self.isShuffling then
        local randomIndex = math.random(1, #songs)
        self:playSong(songs[randomIndex], self.currentPlaylistName, randomIndex)
    else
        local nextIndex = (self.currentIndex % #songs) + 1
        self:playSong(songs[nextIndex], self.currentPlaylistName, nextIndex)
    end
end


function Spotify:prevSong()
    -- Fallback: Check for valid playlist
    if not self.currentPlaylistName or not self.playlists[self.currentPlaylistName] then
        self:displayError("No playlist is currently selected.")
        return
    end
    local songs = self.playlists[self.currentPlaylistName].songs
    -- Fallback: Check for empty playlist
    if not songs or #songs == 0 then
        self:displayError("The current playlist is empty.")
        return
    end
    -- Fallback: Check for valid current index, resetting if invalid
    if self.currentIndex < 1 or self.currentIndex > #songs then
        self.currentIndex = #songs
    end
    if self.repeatMode == "Song" then
        self:playSong(songs[self.currentIndex], self.currentPlaylistName, self.currentIndex)
    elseif self.isShuffling then
        local randomIndex = math.random(1, #songs)
        self:playSong(songs[randomIndex], self.currentPlaylistName, randomIndex)
    else
        local prevIndex = (self.currentIndex - 2 + #songs) % #songs + 1
        self:playSong(songs[prevIndex], self.currentPlaylistName, prevIndex)
    end
end


function Spotify:playSong(songData, playlistName, songIndex)
    -- Fallback: Ensure required song data is present and valid
    if not songData or not songData.soundId or self:normalizeSoundId(songData.soundId) == nil then
        self:displayError("Invalid song data. Missing or invalid sound ID.")
        return
    end
    if self.currentSound then
        self.currentSound:Stop()
        self.currentSound:Destroy()
    end
    self.currentSound = Instance.new("Sound")
    self.currentSound.SoundId = self:normalizeSoundId(songData.soundId)
    self.currentSound.Volume = self.settings.volume
    self.currentSound.Parent = self.player:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    -- Check if sound loaded successfully
    local loadSuccess, loadError = pcall(function()
        self.currentSound.Loaded:Wait()
    end)
    if not loadSuccess then
        self.currentSound:Destroy()
        self.currentSound = nil
        self:displayError("Failed to load sound: " .. loadError)
        return
    end
    self.currentSound.Ended:Connect(function()
        self:nextSong()
    end)
    self.currentSound:Play()
    self.isPlaying = true
    self.currentPlaylistName = playlistName
    self.currentIndex = songIndex
    self:updateNowPlayingUI()
    if self.ui and self.ui.playPauseBtn then
        self.ui.playPauseBtn.Text = ""
    end
end


function Spotify:addPlaylist(name)
    -- Fallback: Check for empty name
    if not name or name == "" then
        self:displayError("Playlist name cannot be empty.")
        return
    end
    -- Fallback: Check if playlist already exists
    if self.playlists[name] then
        self:displayError("A playlist with that name already exists.")
        return
    end
    self.playlists[name] = { name = name, songs = {} }
    self:saveData()
    self:updatePlaylistUI()
end


function Spotify:addSongToPlaylist()
    -- Fallback: Check for valid text boxes and content
    local name = self.ui.songTitleBox and self.ui.songTitleBox.Text or ""
    local id = self.ui.songIdBox and self.ui.songIdBox.Text or ""
    local art = self.ui.songArtBox and self.ui.songArtBox.Text or ""
    if not self.selectedPlaylistName or not self.playlists[self.selectedPlaylistName] then
        self:displayError("No playlist is currently selected to add a song to.")
        return
    end
    if not name or name == "" or not id or id == "" then
        self:displayError("Song title and ID cannot be empty.")
        return
    end
    local song = {
        title = name,
        soundId = id,
        decal = art,
        artist = "Unknown Artist"
    }
    table.insert(self.playlists[self.selectedPlaylistName].songs, song)
    self:saveData()
    self:updateEditPageUI()
end


function Spotify:createEditPageUI()
    local frame = self.ui.editPage
    if not frame then return end
    
    local layout = Instance.new("UIListLayout", frame)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    self.ui.editPlaylistName = Instance.new("TextLabel", frame)
    self.ui.editPlaylistName.Size = UDim2.new(1, -20, 0, 30)
    self.ui.editPlaylistName.Font = Enum.Font.GothamBold
    self.ui.editPlaylistName.TextScaled = true
    self.ui.editPlaylistName.BackgroundTransparency = 1

    local addFrame = Instance.new("Frame", frame)
    addFrame.Size = UDim2.new(1, -20, 0, 120)
    addFrame.BackgroundTransparency = 1
    addFrame.ClipsDescendants = true

    local addLayout = Instance.new("UIListLayout", addFrame)
    addLayout.FillDirection = Enum.FillDirection.Vertical
    addLayout.Padding = UDim.new(0, 5)

    self.ui.songTitleBox = Instance.new("TextBox", addFrame)
    self.ui.songTitleBox.Size = UDim2.new(1, 0, 0, 30)
    self.ui.songTitleBox.PlaceholderText = "Song Title"

    self.ui.songIdBox = Instance.new("TextBox", addFrame)
    self.ui.songIdBox.Size = UDim2.new(1, 0, 0, 30)
    self.ui.songIdBox.PlaceholderText = "Sound ID"

    self.ui.addSongBtn = Instance.new("TextButton", addFrame)
    self.ui.addSongBtn.Size = UDim2.new(1, 0, 0, 30)
    self.ui.addSongBtn.Text = "Add Song"
    
    self.ui.addSongBtn.MouseButton1Click:Connect(function()
        self:addSongToPlaylist()
    end)
    
    self.ui.songScrollFrame = Instance.new("ScrollingFrame", frame)
    self.ui.songScrollFrame.Size = UDim2.new(1, -20, 1, -150)
    self.ui.songScrollFrame.BackgroundTransparency = 1

    self.ui.songList = Instance.new("UIListLayout", self.ui.songScrollFrame)
    self.ui.songList.FillDirection = Enum.FillDirection.Vertical
    self.ui.songList.Padding = UDim.new(0, 5)
    self.ui.songList.HorizontalAlignment = Enum.HorizontalAlignment.Center
end


function Spotify:updateEditPageUI()
    local name = self.selectedPlaylistName
    if not name or not self.playlists[name] then return end

    self.ui.editPlaylistName.Text = "Editing: " .. name

    for _, child in self.ui.songScrollFrame:GetChildren() do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local songs = self.playlists[name].songs
    for i, song in ipairs(songs) do
        local btn = Instance.new("TextButton", self.ui.songScrollFrame)
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.Text = song.title
        btn.Font = Enum.Font.Gotham
        btn.TextColor3 = THEMES[self.settings.theme].text
        btn.BackgroundColor3 = THEMES[self.settings.theme].button
        btn.MouseButton1Click:Connect(function()
            self:playSong(song, name, i)
        end)
    end
end


function Spotify:createHomePageUI()
    local frame = self.ui.homePage
    if not frame then return end

    local layout = Instance.new("UIListLayout", frame)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    self.ui.greetingLabel = Instance.new("TextLabel", frame)
    self.ui.greetingLabel.Name = "greetingLabel"
    self.ui.greetingLabel.Size = UDim2.new(1, -20, 0, 40)
    self.ui.greetingLabel.Font = Enum.Font.GothamBold
    self.ui.greetingLabel.TextScaled = true
    self.ui.greetingLabel.BackgroundTransparency = 1

    local newPlFrame = Instance.new("Frame", frame)
    newPlFrame.Size = UDim2.new(1, -20, 0, 40)
    newPlFrame.BackgroundTransparency = 1

    local newPlLayout = Instance.new("UIListLayout", newPlFrame)
    newPlLayout.FillDirection = Enum.FillDirection.Horizontal
    newPlLayout.Padding = UDim.new(0, 5)
    newPlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    self.ui.newPlBox = Instance.new("TextBox", newPlFrame)
    self.ui.newPlBox.Size = UDim2.new(0.7, 0, 1, 0)
    self.ui.newPlBox.PlaceholderText = "New Playlist Name"

    self.ui.createPlBtn = Instance.new("TextButton", newPlFrame)
    self.ui.createPlBtn.Size = UDim2.new(0.3, 0, 1, 0)
    self.ui.createPlBtn.Text = "Create"
    
    self.ui.createPlBtn.MouseButton1Click:Connect(function()
        self:addPlaylist(self.ui.newPlBox.Text)
        self.ui.newPlBox.Text = ""
    end)
end


function Spotify:createPlaylistsPageUI()
    local frame = self.ui.playlistsPage
    if not frame then return end

    local layout = Instance.new("UIListLayout", frame)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    self.ui.plScrollFrame = Instance.new("ScrollingFrame", frame)
    self.ui.plScrollFrame.Size = UDim2.new(1, 0, 1, -20)
    self.ui.plScrollFrame.BackgroundTransparency = 1

    self.ui.plList = Instance.new("UIListLayout", self.ui.plScrollFrame)
    self.ui.plList.FillDirection = Enum.FillDirection.Vertical
    self.ui.plList.Padding = UDim.new(0, 5)
    self.ui.plList.HorizontalAlignment = Enum.HorizontalAlignment.Center
end


function Spotify:updatePlaylistUI()
    if not self.ui.plScrollFrame then return end

    for _, child in self.ui.plScrollFrame:GetChildren() do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    for name, playlist in pairs(self.playlists) do
        local btn = Instance.new("TextButton", self.ui.plScrollFrame)
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.Text = name
        btn.Font = Enum.Font.Gotham
        btn.TextColor3 = THEMES[self.settings.theme].text
        btn.BackgroundColor3 = THEMES[self.settings.theme].button
        btn.MouseButton1Click:Connect(function()
            self.selectedPlaylistName = name
            self:showPage(self.ui.editPage)
            self:updateEditPageUI()
        end)
    end
end


function Spotify:createSettingsPageUI()
    local frame = self.ui.settingsPage
    if not frame then return end

    local layout = Instance.new("UIListLayout", frame)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    -- New Debug Settings UI
    local debugFrame = Instance.new("Frame", frame)
    debugFrame.Name = "DebugFrame"
    debugFrame.Size = UDim2.new(1, -20, 0, 40)
    debugFrame.BackgroundTransparency = 1

    local debugLayout = Instance.new("UIListLayout", debugFrame)
    debugLayout.FillDirection = Enum.FillDirection.Horizontal
    debugLayout.Padding = UDim.new(0, 5)
    debugLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local debugLabel = Instance.new("TextLabel", debugFrame)
    debugLabel.Size = UDim2.new(0.7, 0, 1, 0)
    debugLabel.Text = "Debug Mode"
    debugLabel.BackgroundTransparency = 1
    debugLabel.TextXAlignment = Enum.TextXAlignment.Left

    self.ui.debugToggleBtn = Instance.new("TextButton", debugFrame)
    self.ui.debugToggleBtn.Size = UDim2.new(0.3, 0, 1, 0)
    self.ui.debugToggleBtn.Text = tostring(self.settings.debugMode)
    self.ui.debugToggleBtn.MouseButton1Click:Connect(function()
        self.settings.debugMode = not self.settings.debugMode
        self.ui.debugToggleBtn.Text = tostring(self.settings.debugMode)
        if self.settings.debugMode then
            self:showPage(self.ui.debugPage)
            self:updateDebugUI()
        else
            self:showPage(self.ui.settingsPage)
        end
    end)
end

-- New function for debug UI
function Spotify:createDebugPageUI()
    local frame = self.ui.debugPage
    if not frame then return end
    
    local layout = Instance.new("UIListLayout", frame)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    self.ui.debugTestBtn = Instance.new("TextButton", frame)
    self.ui.debugTestBtn.Size = UDim2.new(1, -20, 0, 40)
    self.ui.debugTestBtn.Text = "Test Error Handling (Simulate Missing UI)"
    self.ui.debugTestBtn.TextColor3 = Color3.new(1,1,1)
    self.ui.debugTestBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    self.ui.debugTestBtn.MouseButton1Click:Connect(function()
        self:testErrorHandling()
    end)
    
    local outputScroll = Instance.new("ScrollingFrame", frame)
    outputScroll.Size = UDim2.new(1, -20, 1, -60)
    outputScroll.BackgroundTransparency = 1
    
    self.ui.debugOutput = Instance.new("TextLabel", outputScroll)
    self.ui.debugOutput.Name = "DebugOutput"
    self.ui.debugOutput.Size = UDim2.new(1, 0, 0, 0)
    self.ui.debugOutput.Text = "Debug Log: Ready."
    self.ui.debugOutput.BackgroundTransparency = 1
    self.ui.debugOutput.TextXAlignment = Enum.TextXAlignment.Left
    self.ui.debugOutput.TextYAlignment = Enum.TextYAlignment.Top
    self.ui.debugOutput.TextWrapped = true
    self.ui.debugOutput.AutomaticSize = Enum.AutomaticSize.Y
end

-- Function to update the debug UI with new logs
function Spotify:updateDebugUI(message)
    if self.ui.debugOutput and self.settings.debugMode then
        self.ui.debugOutput.Text = self.ui.debugOutput.Text .. "\n" .. tostring(message)
    end
end

-- Function to simulate an error for testing
function Spotify:testErrorHandling()
    -- Simulates a critical error, but pcall will catch it
    local success, err = pcall(function()
        self.ui.playPauseBtn = nil -- Simulate the button being deleted
        self:togglePlayPause() -- This will try to call a function on a nil value
    end)
    
    if not success then
        self:updateDebugUI("Caught an error: " .. err)
    end
end


function Spotify:createSearchPageUI()
    local frame = self.ui.searchPage
    if not frame then return end

    local layout = Instance.new("UIListLayout", frame)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local searchFrame = Instance.new("Frame", frame)
    searchFrame.Size = UDim2.new(1, -20, 0, 40)
    searchFrame.BackgroundTransparency = 1

    local searchLayout = Instance.new("UIListLayout", searchFrame)
    searchLayout.FillDirection = Enum.FillDirection.Horizontal
    searchLayout.Padding = UDim.new(0, 5)

    self.ui.searchBox = Instance.new("TextBox", searchFrame)
    self.ui.searchBox.Size = UDim2.new(0.8, 0, 1, 0)
    self.ui.searchBox.PlaceholderText = "Search for a song..."

    self.ui.searchBtn = Instance.new("TextButton", searchFrame)
    self.ui.searchBtn.Size = UDim2.new(0.2, 0, 1, 0)
    self.ui.searchBtn.Text = "Search"
    
    self.ui.searchBtn.MouseButton1Click:Connect(function()
        self:searchSongs(self.ui.searchBox.Text)
    end)

    self.ui.searchResultFrame = Instance.new("ScrollingFrame", frame)
    self.ui.searchResultFrame.Size = UDim2.new(1, -20, 1, -60)
    self.ui.searchResultFrame.BackgroundTransparency = 1

    self.ui.searchResultList = Instance.new("UIListLayout", self.ui.searchResultFrame)
    self.ui.searchResultList.FillDirection = Enum.FillDirection.Vertical
    self.ui.searchResultList.Padding = UDim.new(0, 5)
    self.ui.searchResultList.HorizontalAlignment = Enum.HorizontalAlignment.Center
end


function Spotify:searchSongs(query)
    if not query or query == "" then
        self:displayError("Search query cannot be empty.")
        return
    end

    for _, child in self.ui.searchResultFrame:GetChildren() do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local url = SEARCH_API_URL .. HttpService:UrlEncode(query)
    local success, response = pcall(function()
        return HttpService:GetAsync(url)
    end)

    if not success or not response then
        self:displayError("Search failed: " .. (response or ""))
        return
    end

    local results = HttpService:JSONDecode(response)
    if not results or #results == 0 then
        local noResultsLabel = Instance.new("TextLabel", self.ui.searchResultFrame)
        noResultsLabel.Size = UDim2.new(1, 0, 0, 40)
        noResultsLabel.Text = "No results found."
        noResultsLabel.BackgroundTransparency = 1
        return
    end

    for _, result in ipairs(results) do
        local songData = {
            title = result.Name,
            soundId = result.AssetId,
            artist = result.Creator.Name
        }
        local btn = Instance.new("TextButton", self.ui.searchResultFrame)
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.Text = songData.title .. " by " .. songData.artist
        btn.Font = Enum.Font.Gotham
        btn.TextColor3 = THEMES[self.settings.theme].text
        btn.BackgroundColor3 = THEMES[self.settings.theme].button
        btn.MouseButton1Click:Connect(function()
            self:playSong(songData)
        end)
    end
end


function Spotify:updateSearchResultsUI()
    -- This function is a placeholder for updating search results based on a new theme.
end


function Spotify:toggleUI()
    local mainFrame = self.ui.mainFrame
    if not mainFrame then
        self:displayError("Main UI frame is missing.")
        return
    end

local isVisible = mainFrame.Visible
local targetPos
local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart)

if isVisible then
    -- Slide out
    targetPos = UDim2.fromScale(0.5, 1.5)
    local tweenOut = TweenService:Create(mainFrame, tweenInfo, { Position = targetPos })
    tweenOut:Play()
    tweenOut.Completed:Connect(function()
        mainFrame.Visible = false
    end)
else
    -- Prepare off-screen start before sliding in
    mainFrame.Position = UDim2.fromScale(0.5, 1.5)
    mainFrame.Visible = true
    self:updateGreeting()

    targetPos = UDim2.fromScale(0.5, 0.5)
    local tweenIn = TweenService:Create(mainFrame, tweenInfo, { Position = targetPos })
    tweenIn:Play()
end


function Spotify:toggleShuffle()
    self.isShuffling = not self.isShuffling
    self:displayError("Shuffle mode is now " .. (self.isShuffling and "ON" or "OFF"))
end


function Spotify:toggleRepeat()
    if self.repeatMode == "None" then
        self.repeatMode = "Playlist"
        self:displayError("Repeat mode is now 'Playlist'")
    elseif self.repeatMode == "Playlist" then
        self.repeatMode = "Song"
        self:displayError("Repeat mode is now 'Song'")
    else
        self.repeatMode = "None"
        self:displayError("Repeat mode is now 'None'")
    end
end


function Spotify:closeUI()
    local mainFrame = self.ui.mainFrame
    if not mainFrame then return end
    
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Position = UDim2.fromScale(0.5, 1.5)
    })
    
    tween.Completed:Wait()
    mainFrame.Visible = false
end


function Spotify:init()
    local success, err = pcall(function()
        local loadedData = self:loadData()
        if loadedData then
            if loadedData.playlists and typeof(loadedData.playlists) == "table" then
                self.playlists = loadedData.playlists
            end
            if loadedData.settings and typeof(loadedData.settings) == "table" then
                self.settings.theme = loadedData.settings.theme or "Dark"
                self.settings.volume = loadedData.settings.volume or 0.5
                local keyName = loadedData.settings.toggleKeyString
                if keyName and Enum.KeyCode[keyName] then
                    self.settings.toggleKey = Enum.KeyCode[keyName]
                end
            end
        end

        self:createUI()
        self:updatePlaylistUI()
        self:updateVolumeSlider()
        self:updateGreeting()
        self:startSession()

        local heartbeatThread = coroutine.create(function()
            while task.wait(60) do
                self:heartbeat()
            end
        end)
        coroutine.resume(heartbeatThread)
        game:GetService("Players").PlayerRemoving:Connect(function(player)
            if player == self.player then
                self:stopSession()
            end
        end)

        UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode == self.settings.toggleKey then
                self:toggleUI()
            end
        end)

        RunService.RenderStepped:Connect(function()
            if self.isPlaying and self.currentSound then
                self:updateProgressSlider()
            end
        end)
    end)

    if not success then
        self:displayError("Initialization failed: " .. err)
    end
end


local spotifyApp = Spotify.new()
spotifyApp:init()
