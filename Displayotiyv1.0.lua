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

	return self
end

--------------------
--- Utility
--------------------
function Spotify:normalizeDecal(input)
	if not input or input == "" then return "" end
	local s = tostring(input)
	if s:find("rbxassetid://") then return s end
	local n = s:match("(%d+)")
	return n and "rbxassetid://" .. n or s
end

function Spotify:normalizeSoundId(id)
	if not id or id == "" then return nil end
	local s = tostring(id)
	local n = s:match("(%d+)")
	return n and "rbxassetid://" .. n or s
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
		warn("Failed to save data to file:", err)
	end
end

function Spotify:loadData()
	if not self.isExecutor then return end
	local success, data = pcall(function()
		if isfile("NextSpotify.json") then
			return HttpService:JSONDecode(readfile("NextSpotify.json"))
		end
	end)
	if success and data and typeof(data) == "table" then
		return data
	else
		return nil
	end
end

function Spotify:findFirstInstance(name, parent)
	for _, child in parent:GetChildren() do
		if child.Name == name then
			return child
		end
	end
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
	stroke.Thickness = 2
	local minConstraint = Instance.new("UISizeConstraint", self.ui.mainFrame)
	minConstraint.MinSize = Vector2.new(600, 400)
	
	self.ui.topBar = Instance.new("Frame", self.ui.mainFrame)
	self.ui.topBar.Name = "TopBar"
	self.ui.topBar.Size = UDim2.new(1, 0, 0, 86)
	Instance.new("UICorner", self.ui.topBar).CornerRadius = UDim.new(0, 14)
	
	local logo = Instance.new("TextLabel", self.ui.topBar)
	logo.Size = UDim2.fromScale(1, 1)
	logo.BackgroundTransparency = 1
	logo.Font = Enum.Font.GothamBlack
	logo.Text = "Displayoptiy"
	logo.TextScaled = true
	logo.TextXAlignment = Enum.TextXAlignment.Center
	
	local isDragging = false
	local dragStartPos
	local startInputPos
	self.connections.dragBegan = self.ui.topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			dragStartPos = self.ui.mainFrame.Position
			startInputPos = input.Position
		end
	end)
	
	self.connections.dragChanged = UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startInputPos
			self.ui.mainFrame.Position = UDim2.new(dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X, dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y)
		end
	end)
	
	self.connections.dragEnded = UserInputService.InputEnded:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			isDragging = false
		end
	end)
	
	self.ui.resizeHandle = Instance.new("Frame", self.ui.mainFrame)
	self.ui.resizeHandle.Name = "ResizeHandle"
	self.ui.resizeHandle.Size = UDim2.fromOffset(22, 22)
	self.ui.resizeHandle.AnchorPoint = Vector2.new(1, 1)
	self.ui.resizeHandle.Position = UDim2.fromScale(1, 1)
	Instance.new("UICorner", self.ui.resizeHandle).CornerRadius = UDim.new(0, 6)
	
	local isResizing = false
	local startSize
	local startInputPos_r
	self.connections.resizeBegan = self.ui.resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isResizing = true
			startInputPos_r = input.Position
			startSize = self.ui.mainFrame.AbsoluteSize
		end
	end)
	
	self.connections.resizeChanged = UserInputService.InputChanged:Connect(function(input)
		if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startInputPos_r
			local newWidth = math.max(minConstraint.MinSize.X, startSize.X + delta.X)
			local newHeight = math.max(minConstraint.MinSize.Y, startSize.Y + delta.Y)
			self.ui.mainFrame.Size = UDim2.fromOffset(newWidth, newHeight)
		end
	end)
	
	self.connections.resizeEnded = UserInputService.InputEnded:Connect(function(input)
		if isResizing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			isResizing = false
		end
	end)
	
	self.ui.tabsRow = Instance.new("Frame", self.ui.mainFrame)
	self.ui.tabsRow.Name = "TabsRow"
	self.ui.tabsRow.Size = UDim2.new(1, -28, 0, 64)
	self.ui.tabsRow.Position = UDim2.new(0, 14, 0, 92)
	self.ui.tabsRow.BackgroundTransparency = 1
	local tabsLayout = Instance.new("UIListLayout", self.ui.tabsRow)
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 12)
	tabsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	local function makeTabButton(name)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1/5, -9, 1, -12)
		btn.Text = name
		btn.Font = Enum.Font.GothamBlack
		btn.TextScaled = true
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
		btn.Parent = self.ui.tabsRow
		return btn
	end

	self.ui.homeTabBtn = makeTabButton("Home")
	self.ui.musicTabBtn = makeTabButton("Music")
	self.ui.playlistsTabBtn = makeTabButton("Playlists")
	self.ui.searchTabBtn = makeTabButton("Search")
	self.ui.settingsTabBtn = makeTabButton("Settings")
	
	self.ui.content = Instance.new("Frame", self.ui.mainFrame)
	self.ui.content.Name = "Content"
	self.ui.content.Size = UDim2.new(1, -28, 1, -200)
	self.ui.content.Position = UDim2.new(0, 14, 0, 168)
	self.ui.content.BackgroundTransparency = 1
	
	self.ui.homePage = Instance.new("Frame", self.ui.content)
	self.ui.musicPage = Instance.new("Frame", self.ui.content)
	self.ui.playlistsPage = Instance.new("Frame", self.ui.content)
	self.ui.searchPage = Instance.new("Frame", self.ui.content)
	self.ui.settingsPage = Instance.new("Frame", self.ui.content)
	
	self.ui.homePage.Name, self.ui.musicPage.Name, self.ui.playlistsPage.Name, self.ui.searchPage.Name, self.ui.settingsPage.Name = "Home", "Music", "Playlists", "Search", "Settings"
	self.ui.homePage.Size, self.ui.musicPage.Size, self.ui.playlistsPage.Size, self.ui.searchPage.Size, self.ui.settingsPage.Size = UDim2.fromScale(1, 1), UDim2.fromScale(1, 1), UDim2.fromScale(1, 1), UDim2.fromScale(1, 1), UDim2.fromScale(1, 1)
	self.ui.homePage.BackgroundTransparency, self.ui.musicPage.BackgroundTransparency, self.ui.playlistsPage.BackgroundTransparency, self.ui.searchPage.BackgroundTransparency, self.ui.settingsPage.BackgroundTransparency = 1, 1, 1, 1, 1
	self.ui.homePage.Visible = true
	self.ui.musicPage.Visible = false
	self.ui.playlistsPage.Visible = false
	self.ui.searchPage.Visible = false
	self.ui.settingsPage.Visible = false
	
	self.ui.homeTabBtn.MouseButton1Click:Connect(function() self:showPage(self.ui.homePage) end)
	self.ui.musicTabBtn.MouseButton1Click:Connect(function() self:showPage(self.ui.musicPage) end)
	self.ui.playlistsTabBtn.MouseButton1Click:Connect(function() self:showPage(self.ui.playlistsPage) end)
	self.ui.searchTabBtn.MouseButton1Click:Connect(function() self:showPage(self.ui.searchPage) end)
	self.ui.settingsTabBtn.MouseButton1Click:Connect(function() self:showPage(self.ui.settingsPage) end)
	
	self:createHomePageUI()
	self:createMusicPageUI()
	self:createPlaylistsPageUI()
	self:createSearchPageUI()
	self:createSettingsPageUI()
end

function Spotify:createHomePageUI()
	local topInfoFrame = Instance.new("Frame", self.ui.homePage)
	topInfoFrame.Size = UDim2.new(1, 0, 0, 120)
	topInfoFrame.BackgroundTransparency = 1
	
	local topLayout = Instance.new("UIListLayout", topInfoFrame)
	topLayout.Padding = UDim.new(0, 10)
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local playerInfoFrame = Instance.new("Frame", topInfoFrame)
	playerInfoFrame.Name = "PlayerInfoFrame"
	playerInfoFrame.Size = UDim2.new(0, 200, 1, 0)
	playerInfoFrame.BackgroundTransparency = 1
	playerInfoFrame.LayoutOrder = 2
	
	self.ui.playerImage = Instance.new("ImageLabel", playerInfoFrame)
	self.ui.playerImage.Size = UDim2.fromOffset(80, 80)
	self.ui.playerImage.Position = UDim2.new(1, -10, 0.5, 0)
	self.ui.playerImage.AnchorPoint = Vector2.new(1, 0.5)
	self.ui.playerImage.BackgroundTransparency = 1
	self.ui.playerImage.Image = DEFAULT_ART_ID
	Instance.new("UICorner", self.ui.playerImage).CornerRadius = UDim.new(1, 0)

	local playerTextFrame = Instance.new("Frame", playerInfoFrame)
	playerTextFrame.Size = UDim2.new(1, -100, 1, 0)
	playerTextFrame.BackgroundTransparency = 1
	
	local textLayout = Instance.new("UIListLayout", playerTextFrame)
	textLayout.Padding = UDim.new(0, 2)
	textLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	textLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	self.ui.greetingLabel = Instance.new("TextLabel", playerTextFrame)
	self.ui.greetingLabel.Size = UDim2.new(1, 0, 0, 24)
	self.ui.greetingLabel.Text = "Hello!"
	self.ui.greetingLabel.Font = Enum.Font.GothamBlack
	self.ui.greetingLabel.TextScaled = true
	self.ui.greetingLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.ui.greetingLabel.BackgroundTransparency = 1
	
	self.ui.displayNameLabel = Instance.new("TextLabel", playerTextFrame)
	self.ui.displayNameLabel.Size = UDim2.new(1, 0, 0, 20)
	self.ui.displayNameLabel.Text = "@Username"
	self.ui.displayNameLabel.Font = Enum.Font.GothamBold
	self.ui.displayNameLabel.TextScaled = true
	self.ui.displayNameLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.ui.displayNameLabel.BackgroundTransparency = 1
	
	local statsFrame = Instance.new("Frame", topInfoFrame)
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(0.6, 0, 1, 0)
	statsFrame.LayoutOrder = 1
	statsFrame.BackgroundTransparency = 1
	
	local statsLayout = Instance.new("UIListLayout", statsFrame)
	statsLayout.Padding = UDim.new(0, 5)
	statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	self.ui.songStatsLabel = Instance.new("TextLabel", statsFrame)
	self.ui.songStatsLabel.Size = UDim2.new(1, -20, 0, 24)
	self.ui.songStatsLabel.Text = "0 user songs found."
	self.ui.songStatsLabel.Font = Enum.Font.Gotham
	self.ui.songStatsLabel.TextScaled = true
	self.ui.songStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.ui.songStatsLabel.BackgroundTransparency = 1
	
	self.ui.gameStatsLabel = Instance.new("TextLabel", statsFrame)
	self.ui.gameStatsLabel.Size = UDim2.new(1, -20, 0, 24)
	self.ui.gameStatsLabel.Text = "Your Playlists"
	self.ui.gameStatsLabel.Font = Enum.Font.GothamBold
	self.ui.gameStatsLabel.TextScaled = true
	self.ui.gameStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.ui.gameStatsLabel.BackgroundTransparency = 1
	
	self.ui.homeList = Instance.new("ScrollingFrame", self.ui.homePage)
	self.ui.homeList.Size = UDim2.new(1, 0, 1, -130)
	self.ui.homeList.Position = UDim2.new(0, 0, 0, 130)
	self.ui.homeList.BackgroundTransparency = 1
	self.ui.homeList.ScrollBarThickness = 6
	self.ui.homeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.ui.homeListLayout = Instance.new("UIGridLayout", self.ui.homeList)
	self.ui.homeListLayout.CellPadding = UDim2.fromOffset(12, 12)
	self.ui.homeListLayout.CellSize = UDim2.fromOffset(180, 200)
end

function Spotify:createMusicPageUI()
	local nowFrame = Instance.new("Frame", self.ui.musicPage)
	nowFrame.Size = UDim2.new(1, 0, 0, 220)
	Instance.new("UICorner", nowFrame).CornerRadius = UDim.new(0, 12)
	Instance.new("UIPadding", nowFrame).PaddingTop = UDim.new(0, 10)
	Instance.new("UIPadding", nowFrame).PaddingBottom = UDim.new(0, 10)
	Instance.new("UIPadding", nowFrame).PaddingLeft = UDim.new(0, 10)
	Instance.new("UIPadding", nowFrame).PaddingRight = UDim.new(0, 10)
	self.ui.nowFrame = nowFrame
	
	local nowLayout = Instance.new("UIListLayout", nowFrame)
	nowLayout.FillDirection = Enum.FillDirection.Horizontal
	nowLayout.Padding = UDim.new(0, 15)
	nowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	self.ui.nowArt = Instance.new("ImageLabel", nowFrame)
	self.ui.nowArt.Size = UDim2.fromOffset(200, 200)
	self.ui.nowArt.BackgroundTransparency = 1
	self.ui.nowArt.Image = DEFAULT_ART_ID
	
	local nowRight = Instance.new("Frame", nowFrame)
	nowRight.Size = UDim2.new(1, -225, 1, 0)
	nowRight.BackgroundTransparency = 1
	
	local nowRightLayout = Instance.new("UIListLayout", nowRight)
	nowRightLayout.Padding = UDim.new(0, 10)
	nowRightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	self.ui.nowTitle = Instance.new("TextLabel", nowRight)
	self.ui.nowTitle.Size = UDim2.new(1, 0, 0, 60)
	self.ui.nowTitle.Font = Enum.Font.GothamBlack
	self.ui.nowTitle.TextScaled = true
	self.ui.nowTitle.Text = "Now Playing: None"
	self.ui.nowTitle.BackgroundTransparency = 1
	self.ui.nowTitle.TextXAlignment = Enum.TextXAlignment.Left

	self.ui.visualizerFrame = Instance.new("Frame", nowRight)
	self.ui.visualizerFrame.Size = UDim2.new(1, 0, 0, 50)
	self.ui.visualizerFrame.BackgroundTransparency = 1
	local vizLayout = Instance.new("UIListLayout", self.ui.visualizerFrame)
	vizLayout.FillDirection = Enum.FillDirection.Horizontal
	vizLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	vizLayout.Padding = UDim.new(0, 4)
	self.ui.visualizerBars = {}
	for i = 1, 20 do
		local bar = Instance.new("Frame", self.ui.visualizerFrame)
		bar.Size = UDim2.new(1/20, -4, 0.1, 0)
		bar.BorderSizePixel = 0
		Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)
		table.insert(self.ui.visualizerBars, bar)
	end

	local nowControls = Instance.new("Frame", nowRight)
	nowControls.Size = UDim2.new(1, 0, 0, 40)
	nowControls.BackgroundTransparency = 1
	
	local ctrlLayout = Instance.new("UIListLayout", nowControls)
	ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
	ctrlLayout.Padding = UDim.new(0, 10)
	ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	local function makeCtrl(txt, widthScale)
		local btn = Instance.new("TextButton", nowControls)
		btn.Size = UDim2.new(widthScale, -5, 1, 0)
		btn.Text = txt
		btn.Font = Enum.Font.SourceSans
		btn.TextScaled = true
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
		return btn
	end
	
	self.ui.playPauseBtn = makeCtrl("▶", 0.2)
	self.ui.nextBtn = makeCtrl("⏭", 0.2)
	self.ui.shuffleBtn = makeCtrl("🔀", 0.2)
	self.ui.repeatBtn = makeCtrl("🔁", 0.2)

	-- Custom volume slider implementation (Frame + Fill + Thumb)
	self.ui.volumeBar = Instance.new("Frame", nowControls)
	self.ui.volumeBar.Size = UDim2.new(0.4, -10, 0.6, 0)
	self.ui.volumeBar.BackgroundTransparency = 0
	self.ui.volumeBar.BackgroundColor3 = Color3.fromRGB(60,60,60)
	Instance.new("UICorner", self.ui.volumeBar).CornerRadius = UDim.new(0, 8)
	
	self.ui.volumeFill = Instance.new("Frame", self.ui.volumeBar)
	self.ui.volumeFill.Size = UDim2.new(self.settings.volume, 0, 1, 0)
	self.ui.volumeFill.Position = UDim2.new(0, 0, 0, 0)
	self.ui.volumeFill.BackgroundColor3 = Color3.fromRGB(100,200,120)
	Instance.new("UICorner", self.ui.volumeFill).CornerRadius = UDim.new(0, 8)
	
	self.ui.volumeThumb = Instance.new("ImageButton", self.ui.volumeBar)
	self.ui.volumeThumb.Size = UDim2.new(0, 14, 1, 0)
	self.ui.volumeThumb.AnchorPoint = Vector2.new(0.5, 0.5)
	self.ui.volumeThumb.Position = UDim2.new(self.settings.volume, 0, 0.5, 0)
	self.ui.volumeThumb.BackgroundTransparency = 1
	self.ui.volumeThumb.Image = ""
	self.ui.volumeThumb.AutoButtonColor = false
	
	-- thumb visuals (small rounded rect)
	local thumbBg = Instance.new("Frame", self.ui.volumeThumb)
	thumbBg.Size = UDim2.new(1, 0, 0.6, 0)
	thumbBg.Position = UDim2.new(0.5, 0, 0.5, 0)
	thumbBg.AnchorPoint = Vector2.new(0.5, 0.5)
	thumbBg.BackgroundColor3 = Color3.fromRGB(240,240,240)
	Instance.new("UICorner", thumbBg).CornerRadius = UDim.new(0, 6)
	
	-- Dragging logic
	self.connections.volumeDragging = nil
	local dragging = false
	local function setVolumeFromX(x)
		local absPos = x - self.ui.volumeBar.AbsolutePosition.X
		local w = self.ui.volumeBar.AbsoluteSize.X
		local ratio = math.clamp(absPos / w, 0, 1)
		self:updateVolume(ratio)
		-- update visuals
		self.ui.volumeFill.Size = UDim2.new(ratio, 0, 1, 0)
		self.ui.volumeThumb.Position = UDim2.new(ratio, 0, 0.5, 0)
	end

	self.connections.volumeThumbDown = self.ui.volumeThumb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	
	self.connections.volumeBarDown = self.ui.volumeBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setVolumeFromX(input.Position.X)
			dragging = true
		end
	end)
	
	self.connections.volumeInputChanged = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setVolumeFromX(input.Position.X)
		end
	end)
	
	self.connections.volumeInputEnd = UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			self:saveData()
		end
	end)
end

function Spotify:createPlaylistsPageUI()
	local viewportSize = Workspace.CurrentCamera.ViewportSize
	local isMobile = viewportSize.X < 700
	
	local playlistCols = Instance.new("UIListLayout", self.ui.playlistsPage)
	playlistCols.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	playlistCols.Padding = UDim.new(0, 12)
	
	self.ui.leftCol = Instance.new("Frame", self.ui.playlistsPage)
	self.ui.rightCol = Instance.new("Frame", self.ui.playlistsPage)
	self.ui.leftCol.Size = isMobile and UDim2.new(1, 0, 0.4, -6) or UDim2.new(0.34, 0, 1, 0)
	self.ui.rightCol.Size = isMobile and UDim2.new(1, 0, 0.6, -6) or UDim2.new(0.66, -12, 1, 0)
	self.ui.leftCol.BackgroundTransparency, self.ui.rightCol.BackgroundTransparency = 1, 1
	
	local createRow = Instance.new("Frame", self.ui.leftCol)
	createRow.Size = UDim2.new(1, 0, 0, 60)
	Instance.new("UICorner", createRow).CornerRadius = UDim.new(0, 10)
	self.ui.createRow = createRow
	
	self.ui.newPlBox = Instance.new("TextBox", createRow)
	self.ui.newPlBox.Size = UDim2.new(1, -110, 1, -12)
	self.ui.newPlBox.Position = UDim2.new(0, 5, 0.5, -18)
	self.ui.newPlBox.PlaceholderText = "New Playlist"
	self.ui.newPlBox.Font = Enum.Font.Gotham
	self.ui.newPlBox.TextScaled = true
	Instance.new("UICorner", self.ui.newPlBox).CornerRadius = UDim.new(0, 8)
	
	self.ui.addPlButton = Instance.new("TextButton", createRow)
	self.ui.addPlButton.Size = UDim2.new(0, 100, 1, -12)
	self.ui.addPlButton.Position = UDim2.new(1, -105, 0.5, -18)
	self.ui.addPlButton.Text = "Add"
	self.ui.addPlButton.Font = Enum.Font.GothamBold
	self.ui.addPlButton.TextScaled = true
	Instance.new("UICorner", self.ui.addPlButton).CornerRadius = UDim.new(0, 8)
	
	self.ui.plList = Instance.new("ScrollingFrame", self.ui.leftCol)
	self.ui.plList.Size = UDim2.new(1, 0, 1, -70)
	self.ui.plList.Position = UDim2.new(0, 0, 0, 70)
	self.ui.plList.BackgroundTransparency = 1
	self.ui.plList.ScrollBarThickness = 6
	self.ui.plList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.ui.plListLayout = Instance.new("UIListLayout", self.ui.plList)
	self.ui.plListLayout.Padding = UDim.new(0, 8)
	
	self.connections.addPlClick = self.ui.addPlButton.MouseButton1Click:Connect(function()
		self:createPlaylist()
	end)
	
	local addSongRow = Instance.new("Frame", self.ui.rightCol)
	addSongRow.Size = UDim2.new(1, 0, 0, 64)
	Instance.new("UICorner", addSongRow).CornerRadius = UDim.new(0, 10)
	self.ui.addSongRow = addSongRow
	
	local addLayout = Instance.new("UIListLayout", addSongRow)
	addLayout.FillDirection = Enum.FillDirection.Horizontal
	addLayout.Padding = UDim.new(0, 8)
	addLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	self.ui.songTitleBox = Instance.new("TextBox", addSongRow)
	self.ui.songIdBox = Instance.new("TextBox", addSongRow)
	self.ui.decalBox = Instance.new("TextBox", addSongRow)
	self.ui.addSongButton = Instance.new("TextButton", addSongRow)
	
	self.ui.songTitleBox.Size, self.ui.songIdBox.Size, self.ui.decalBox.Size = UDim2.new(0.3, 0, 1, 0), UDim2.new(0.25, 0, 1, 0), UDim2.new(0.3, 0, 1, 0)
	self.ui.songTitleBox.PlaceholderText, self.ui.songIdBox.PlaceholderText, self.ui.decalBox.PlaceholderText = "Title (opt)", "Song ID", "Decal ID (opt)"
	self.ui.addSongButton.Size = UDim2.new(0.12, 0, 1, 0)
	self.ui.addSongButton.Text = "Add"
	self.ui.addSongButton.Font = Enum.Font.GothamBold
	
	for _, box in {self.ui.songTitleBox, self.ui.songIdBox, self.ui.decalBox, self.ui.addSongButton} do
		box.TextScaled = true
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
	end
	
	self.ui.songsPanel = Instance.new("ScrollingFrame", self.ui.rightCol)
	self.ui.songsPanel.Size = UDim2.new(1, 0, 1, -74)
	self.ui.songsPanel.Position = UDim2.new(0, 0, 0, 74)
	self.ui.songsPanel.BackgroundTransparency = 1
	self.ui.songsPanel.ScrollBarThickness = 8
	self.ui.songsGrid = Instance.new("UIGridLayout", self.ui.songsPanel)
	self.ui.songsGrid.CellPadding = UDim2.new(0, 12, 0, 12)
	-- Fixed CellSize: choose proper parameters depending on mobile
	if Workspace.CurrentCamera.ViewportSize.X < 700 then
		self.ui.songsGrid.CellSize = UDim2.new(1, -12, 0, 100)
	else
		self.ui.songsGrid.CellSize = UDim2.new(0.5, -18, 0, 100)
	end
	
	self.connections.addSongClick = self.ui.addSongButton.MouseButton1Click:Connect(function()
		self:addSongToPlaylist()
	end)

	self.ui.editOverlay = Instance.new("Frame", self.ui.playlistsPage)
	self.ui.editOverlay.Size = UDim2.new(1,0,1,0)
	self.ui.editOverlay.BackgroundTransparency = 0.5
	self.ui.editOverlay.BackgroundColor3 = Color3.new(0,0,0)
	self.ui.editOverlay.ZIndex = 10
	self.ui.editOverlay.Visible = false

	local editFrame = Instance.new("Frame", self.ui.editOverlay)
	editFrame.Size = UDim2.new(0.6, 0, 0.4, 0)
	editFrame.Position = UDim2.fromScale(0.5, 0.5)
	editFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	Instance.new("UICorner", editFrame).CornerRadius = UDim.new(0, 10)
	self.ui.editFrame = editFrame

	local editTitle = Instance.new("TextLabel", editFrame)
	editTitle.Size = UDim2.new(1, -24, 0, 40)
	editTitle.Position = UDim2.new(0, 12, 0, 10)
	editTitle.Text = "Edit Song"
	editTitle.Font = Enum.Font.GothamBlack
	editTitle.TextScaled = true
	editTitle.TextXAlignment = Enum.TextXAlignment.Left
	editTitle.BackgroundTransparency = 1

	self.ui.editTitleBox = Instance.new("TextBox", editFrame)
	self.ui.editTitleBox.Size = UDim2.new(1, -24, 0, 40)
	self.ui.editTitleBox.Position = UDim2.new(0, 12, 0, 60)
	self.ui.editTitleBox.PlaceholderText = "Title"
	self.ui.editTitleBox.Font = Enum.Font.Gotham
	self.ui.editTitleBox.TextScaled = true
	Instance.new("UICorner", self.ui.editTitleBox).CornerRadius = UDim.new(0, 8)
	
	self.ui.editIdBox = Instance.new("TextBox", editFrame)
	self.ui.editIdBox.Size = UDim2.new(1, -24, 0, 40)
	self.ui.editIdBox.Position = UDim2.new(0, 12, 0, 110)
	self.ui.editIdBox.PlaceholderText = "Song ID"
	self.ui.editIdBox.Font = Enum.Font.Gotham
	self.ui.editIdBox.TextScaled = true
	Instance.new("UICorner", self.ui.editIdBox).CornerRadius = UDim.new(0, 8)
	
	self.ui.editDecalBox = Instance.new("TextBox", editFrame)
	self.ui.editDecalBox.Size = UDim2.new(1, -24, 0, 40)
	self.ui.editDecalBox.Position = UDim2.new(0, 12, 0, 160)
	self.ui.editDecalBox.PlaceholderText = "Decal ID"
	self.ui.editDecalBox.Font = Enum.Font.Gotham
	self.ui.editDecalBox.TextScaled = true
	Instance.new("UICorner", self.ui.editDecalBox).CornerRadius = UDim.new(0, 8)
	
	self.ui.saveEditBtn = Instance.new("TextButton", editFrame)
	self.ui.saveEditBtn.Size = UDim2.new(0.4, 0, 0, 40)
	self.ui.saveEditBtn.Position = UDim2.new(0.5, 0, 0, 210)
	self.ui.saveEditBtn.AnchorPoint = Vector2.new(0.5, 0)
	self.ui.saveEditBtn.Text = "Save"
	self.ui.saveEditBtn.Font = Enum.Font.GothamBold
	self.ui.saveEditBtn.TextScaled = true
	Instance.new("UICorner", self.ui.saveEditBtn).CornerRadius = UDim.new(0, 8)
	
	self.ui.cancelEditBtn = Instance.new("TextButton", editFrame)
	self.ui.cancelEditBtn.Size = UDim2.new(0, 40, 0, 40)
	self.ui.cancelEditBtn.Position = UDim2.new(1, -12, 0, 12)
	self.ui.cancelEditBtn.AnchorPoint = Vector2.new(1, 0)
	self.ui.cancelEditBtn.Text = "X"
	self.ui.cancelEditBtn.Font = Enum.Font.GothamBold
	self.ui.cancelEditBtn.TextScaled = true
	Instance.new("UICorner", self.ui.cancelEditBtn).CornerRadius = UDim.new(0, 8)
	
	self.ui.cancelEditBtn.MouseButton1Click:Connect(function()
		self.ui.editOverlay.Visible = false
	end)
end

function Spotify:createSearchPageUI()
	
	local searchRow = Instance.new("Frame", self.ui.searchPage)
	searchRow.Name = "SearchRow"
	searchRow.Size = UDim2.new(1, 0, 0, 60)
	Instance.new("UICorner", searchRow).CornerRadius = UDim.new(0, 10)
	self.ui.searchRow = searchRow

	local searchLayout = Instance.new("UIListLayout", searchRow)
	searchLayout.FillDirection = Enum.FillDirection.Horizontal
	searchLayout.Padding = UDim.new(0, 8)
	searchLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	self.ui.searchBox = Instance.new("TextBox", searchRow)
	self.ui.searchBox.Size = UDim2.new(1, -110, 1, -12)
	self.ui.searchBox.PlaceholderText = "Search for a sound ID or name..."
	self.ui.searchBox.Font = Enum.Font.Gotham
	self.ui.searchBox.TextScaled = true
	Instance.new("UICorner", self.ui.searchBox).CornerRadius = UDim.new(0, 8)

	self.ui.searchBtn = Instance.new("TextButton", searchRow)
	self.ui.searchBtn.Size = UDim2.new(0, 100, 1, -12)
	self.ui.searchBtn.Text = "Search"
	self.ui.searchBtn.Font = Enum.Font.GothamBold
	self.ui.searchBtn.TextScaled = true
	Instance.new("UICorner", self.ui.searchBtn).CornerRadius = UDim.new(0, 8)
	
	self.ui.searchBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self:searchSounds()
		end
	end)

	self.ui.searchList = Instance.new("ScrollingFrame", self.ui.searchPage)
	self.ui.searchList.Name = "SearchList"
	self.ui.searchList.Size = UDim2.new(1, 0, 1, -70)
	self.ui.searchList.Position = UDim2.new(0, 0, 0, 70)
	self.ui.searchList.BackgroundTransparency = 1
	self.ui.searchList.ScrollBarThickness = 6
	self.ui.searchList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.ui.searchListLayout = Instance.new("UIListLayout", self.ui.searchList)
	self.ui.searchListLayout.Padding = UDim.new(0, 8)

	self.connections.searchBtn = self.ui.searchBtn.MouseButton1Click:Connect(function()
		self:searchSounds()
	end)
end

function Spotify:createSettingsPageUI()
	local settingsLayout = Instance.new("UIListLayout", self.ui.settingsPage)
	settingsLayout.Padding = UDim.new(0, 20)
	
	local function section(titleText)
		local f = Instance.new("Frame", self.ui.settingsPage)
		f.Size = UDim2.new(1, 0, 0, 86)
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
		local l = Instance.new("TextLabel", f)
		l.Size = UDim2.new(1, -24, 0, 38)
		l.Position = UDim2.new(0, 12, 0, 8)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = titleText
		return f
	end
	
	local themeFrame = section("Theme")
	self.ui.themeSelector = Instance.new("ScrollingFrame", themeFrame)
	self.ui.themeSelector.Size = UDim2.new(1, -24, 0, 44)
	self.ui.themeSelector.Position = UDim2.new(0, 12, 0, 40)
	self.ui.themeSelector.BackgroundTransparency = 1
	self.ui.themeSelector.ScrollBarThickness = 4
	self.ui.themeSelector.CanvasSize = UDim2.new(2, 0, 0, 0)
	local themeLayout = Instance.new("UIListLayout", self.ui.themeSelector)
	themeLayout.FillDirection = Enum.FillDirection.Horizontal
	themeLayout.Padding = UDim.new(0, 10)
	themeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	for themeName, themeData in pairs(THEMES) do
		local themeBtn = Instance.new("TextButton", self.ui.themeSelector)
		themeBtn.Name = themeName
		themeBtn.Size = UDim2.new(0, 150, 1, 0)
		themeBtn.Text = themeName
		themeBtn.Font = Enum.Font.GothamBold
		themeBtn.TextScaled = true
		Instance.new("UICorner", themeBtn).CornerRadius = UDim.new(0, 8)
		themeBtn.BackgroundColor3 = themeData.panel
		themeBtn.TextColor3 = themeData.text
		self.connections[themeName .. "Btn"] = themeBtn.MouseButton1Click:Connect(function()
			self:applyTheme(themeName)
			self:saveData()
		end)
	end
	
	local keyFrame = section("Toggle Keybind")
	self.ui.kbRow = Instance.new("TextButton", keyFrame)
	self.ui.kbRow.Size = UDim2.new(1, -24, 0, 44)
	self.ui.kbRow.Position = UDim2.new(0, 12, 0, 40)
	self.ui.kbRow.Text = "Current: " .. self.settings.toggleKey.Name
	Instance.new("UICorner", self.ui.kbRow).CornerRadius = UDim.new(0, 10)
	self.ui.kbRow.Font = Enum.Font.GothamBold
	self.ui.kbRow.TextScaled = true
	
	self.connections.keybindClick = self.ui.kbRow.MouseButton1Click:Connect(function()
		self.ui.kbRow.Text = "Press any key..."
		local conn
		conn = UserInputService.InputBegan:Connect(function(input, gp)
			if not gp and input.UserInputType == Enum.UserInputType.Keyboard then
				self.settings.toggleKey = input.KeyCode
				self.ui.kbRow.Text = "Current: " .. input.KeyCode.Name
				self:saveData()
				if conn then conn:Disconnect() end
			end
		end)
	end)

	local unloadFrame = section("Unload GUI")
	self.ui.unloadBtn = Instance.new("TextButton", unloadFrame)
	self.ui.unloadBtn.Size = UDim2.new(1, -24, 0, 44)
	self.ui.unloadBtn.Position = UDim2.new(0, 12, 0, 40)
	self.ui.unloadBtn.Text = "Unload GUI"
	self.ui.unloadBtn.Font = Enum.Font.GothamBold
	self.ui.unloadBtn.TextScaled = true
	Instance.new("UICorner", self.ui.unloadBtn).CornerRadius = UDim.new(0, 10)
	self.ui.unloadBtn.BackgroundColor3 = Color3.fromRGB(220, 20, 60)
	
	self.connections.unloadBtn = self.ui.unloadBtn.MouseButton1Click:Connect(function()
		self:unloadGUI()
	end)
end

--------------------
--- Functionality
--------------------
function Spotify:unloadGUI()
	self:cleanup()
	print("Next Spotify GUI unloaded.")
end

function Spotify:showPage(page)
	for _, p in pairs({self.ui.homePage, self.ui.musicPage, self.ui.playlistsPage, self.ui.searchPage, self.ui.settingsPage}) do
		p.Visible = false
	end
	page.Visible = true
	
	if page == self.ui.homePage then
		self:rebuildHomeList()
	elseif page == self.ui.playlistsPage then
		self:rebuildPlaylistList()
		self:displayPlaylistSongs(self.selectedPlaylistName)
	end
end

function Spotify:toggleUI()
	local isVisible = self.ui.mainFrame.Visible
	local targetPos = isVisible and UDim2.fromScale(0.5, 1.5) or UDim2.fromScale(0.5, 0.5)
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	if not isVisible then
		self.ui.mainFrame.Visible = true
	end

	local tween = TweenService:Create(self.ui.mainFrame, tweenInfo, { Position = targetPos })
	tween:Play()

	tween.Completed:Connect(function()
		if isVisible then
			self.ui.mainFrame.Visible = false
		end
	end)
end

function Spotify:applyTheme(themeName)
	if not THEMES[themeName] then return end
	self.settings.theme = themeName
	local theme = THEMES[themeName]
	
	self.ui.mainFrame.BackgroundColor3 = theme.bg
	local stroke = self.ui.mainFrame:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = theme.accent end
	self.ui.topBar.BackgroundColor3 = theme.panel
	-- topBar's text label
	for _, child in ipairs(self.ui.topBar:GetChildren()) do
		if child:IsA("TextLabel") then
			child.TextColor3 = theme.text
		end
	end
	self.ui.resizeHandle.BackgroundColor3 = theme.accent
	
	local buttons = {self.ui.homeTabBtn, self.ui.musicTabBtn, self.ui.playlistsTabBtn, self.ui.searchTabBtn, self.ui.settingsTabBtn, self.ui.addPlButton, self.ui.addSongButton, self.ui.kbRow, self.ui.searchBtn, self.ui.playPauseBtn, self.ui.nextBtn, self.ui.shuffleBtn, self.ui.repeatBtn, self.ui.saveEditBtn, self.ui.cancelEditBtn, self.ui.plDropdown}
	for _, btn in pairs(buttons) do
		if btn then
			btn.BackgroundColor3 = theme.button
			btn.TextColor3 = theme.text
		end
	end
	
	local textboxes = {self.ui.newPlBox, self.ui.songTitleBox, self.ui.songIdBox, self.ui.decalBox, self.ui.searchBox, self.ui.editTitleBox, self.ui.editIdBox, self.ui.editDecalBox}
	for _, box in pairs(textboxes) do
		if box then
			box.BackgroundColor3 = theme.button
			box.TextColor3 = theme.text
			if box:IsA("TextBox") then
				box.PlaceholderColor3 = theme.muted
			end
		end
	end

	local panels = {self.ui.nowFrame, self.ui.plRow, self.ui.dropPanel, self.ui.createRow, self.ui.addSongRow, self.ui.searchRow, self.ui.editFrame}
	for _, panel in pairs(panels) do
		if panel then panel.BackgroundColor3 = theme.panel end
	end
	
	if self.ui.nowTitle then self.ui.nowTitle.TextColor3 = theme.text end
	if self.ui.greetingLabel then self.ui.greetingLabel.TextColor3 = theme.text end
	if self.ui.displayNameLabel then self.ui.displayNameLabel.TextColor3 = theme.muted end
	if self.ui.songStatsLabel then self.ui.songStatsLabel.TextColor3 = theme.muted end
	if self.ui.gameStatsLabel then self.ui.gameStatsLabel.TextColor3 = theme.text end
	if self.ui.editFrame then
		for _, child in ipairs(self.ui.editFrame:GetChildren()) do
			if child:IsA("TextLabel") then child.TextColor3 = theme.text end
		end
	end
	if self.ui.unloadBtn then self.ui.unloadBtn.BackgroundColor3 = Color3.fromRGB(220, 20, 60); self.ui.unloadBtn.TextColor3 = theme.text end
	
	-- Apply colors to custom volume slider if present
	if self.ui.volumeBar and self.ui.volumeFill and self.ui.volumeThumb then
		self.ui.volumeBar.BackgroundColor3 = theme.button
		self.ui.volumeFill.BackgroundColor3 = theme.accent
		-- thumb inner background
		local thumbInner = self.ui.volumeThumb:FindFirstChildWhichIsA("Frame")
		if thumbInner then thumbInner.BackgroundColor3 = theme.text end
	end

	for _, bar in ipairs(self.ui.visualizerBars or {}) do
		bar.BackgroundColor3 = theme.accent
	end
end

function Spotify:cleanup()
	for k, conn in pairs(self.connections) do
		if type(conn) == "userdata" and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
		self.connections[k] = nil
	end
	if self.ui.screenGui and self.ui.screenGui.Parent then
		self.ui.screenGui:Destroy()
	end
	if self.currentSound then
		self.currentSound:Destroy()
		self.currentSound = nil
	end
end

function Spotify:playSong(songData, playlistName, index)
	if not songData or not songData.id then return end

	if not self.currentSound then
		self.currentSound = Instance.new("Sound")
		self.currentSound.Name = "SpotifySound"
		self.currentSound.Volume = self.settings.volume
		self.currentSound.Parent = SoundService

		self.connections.soundEnded = self.currentSound.Ended:Connect(function()
			self.isPlaying = false
			if self.ui and self.ui.playPauseBtn then self.ui.playPauseBtn.Text = "▶" end
			if self.repeatMode == "Song" then
				self:playSong(songData, playlistName, index)
			else
				self:playNext()
			end
		end)
	end

	self.currentSound:Stop()
	self.currentSound.SoundId = self:normalizeSoundId(songData.id)
	self.currentSound:Play()
	self.isPlaying = true
	
	self.currentPlaylistName = playlistName
	self.currentIndex = index

	if self.ui and self.ui.nowTitle then self.ui.nowTitle.Text = songData.title or "Unknown Title" end
	if self.ui and self.ui.nowArt then self.ui.nowArt.Image = songData.decal or DEFAULT_ART_ID end
	if self.ui and self.ui.playPauseBtn then self.ui.playPauseBtn.Text = "⏸" end
end

function Spotify:togglePlayPause()
	if not self.currentSound or self.currentSound.SoundId == "" then return end
	if self.isPlaying then
		self.currentSound:Pause()
		self.isPlaying = false
		if self.ui and self.ui.playPauseBtn then self.ui.playPauseBtn.Text = "▶" end
	else
		self.currentSound:Resume()
		self.isPlaying = true
		if self.ui and self.ui.playPauseBtn then self.ui.playPauseBtn.Text = "⏸" end
	end
end

function Spotify:playNext()
	if not self.currentPlaylistName or not self.playlists[self.currentPlaylistName] then return end
	
	local playlist = self.playlists[self.currentPlaylistName]
	if #playlist == 0 then return end
	
	local nextIndex
	if self.isShuffling then
		nextIndex = math.random(1, #playlist)
	else
		nextIndex = self.currentIndex + 1
		if nextIndex > #playlist then
			if self.repeatMode == "Playlist" then
				nextIndex = 1
			else
				self.isPlaying = false
				if self.ui and self.ui.playPauseBtn then self.ui.playPauseBtn.Text = "▶" end
				if self.ui and self.ui.nowTitle then self.ui.nowTitle.Text = "Playlist Finished" end
				return
			end
		end
	end
	
	self:playSong(playlist[nextIndex], self.currentPlaylistName, nextIndex)
end

function Spotify:updateVolume(vol)
	self.settings.volume = vol
	if self.currentSound then
		self.currentSound.Volume = vol
	end
end

function Spotify:rebuildHomeList()
	self.ui.homeList.CanvasSize = UDim2.new(0,0,0,0)
	for _, v in ipairs(self.ui.homeList:GetChildren()) do
		if not v:IsA("UILayout") then
			v:Destroy()
		end
	end
	
	local totalSongs = 0
	for name, songs in pairs(self.playlists) do
		totalSongs = totalSongs + #songs
		
		local card = Instance.new("Frame")
		card.Name = name
		card.Size = UDim2.fromOffset(180, 200)
		card.BackgroundColor3 = THEMES[self.settings.theme].panel
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
		card.Parent = self.ui.homeList

		local layout = Instance.new("UIListLayout", card)
		layout.Padding = UDim.new(0, 8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		
		local art = Instance.new("ImageLabel", card)
		art.Size = UDim2.new(1, -20, 0, 130)
		art.Position = UDim2.fromScale(0.5, 0)
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.BackgroundTransparency = 1
		art.Image = (songs[1] and songs[1].decal) or DEFAULT_ART_ID
		Instance.new("UICorner", art).CornerRadius = UDim.new(0, 8)
		
		local title = Instance.new("TextLabel", card)
		title.Size = UDim2.new(1, -20, 0, 20)
		title.Text = name
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextColor3 = THEMES[self.settings.theme].text
		title.BackgroundTransparency = 1
		
		local playBtn = Instance.new("TextButton", card)
		playBtn.Size = UDim2.new(1, -20, 0, 30)
		playBtn.Text = "Play"
		playBtn.Font = Enum.Font.GothamBold
		playBtn.BackgroundColor3 = THEMES[self.settings.theme].accent
		playBtn.TextColor3 = THEMES[self.settings.theme].text
		Instance.new("UICorner", playBtn).CornerRadius = UDim.new(0, 8)
		playBtn.MouseButton1Click:Connect(function()
			if self.playlists[name] and #self.playlists[name] > 0 then
				self:playSong(self.playlists[name][1], name, 1)
				self:showPage(self.ui.musicPage)
			end
		end)
	end
	
	self.ui.songStatsLabel.Text = totalSongs .. " user songs found."
end

function Spotify:createPlaylist()
	local name = self.ui.newPlBox.Text
	if name and name ~= "" and not self.playlists[name] then
		self.playlists[name] = {}
		self.ui.newPlBox.Text = ""
		self:rebuildPlaylistList()
		self:saveData()
	end
end

function Spotify:addSongToPlaylist()
	local plName = self.selectedPlaylistName
	if not plName or not self.playlists[plName] then return end
	
	local songId = self:normalizeSoundId(self.ui.songIdBox.Text)
	if not songId then return end
	
	local songTitle = self.ui.songTitleBox.Text or "Untitled Song"
	local decalId = self:normalizeDecal(self.ui.decalBox.Text)
	
	table.insert(self.playlists[plName], {
		title = songTitle,
		id = songId,
		decal = decalId
	})
	
	self.ui.songIdBox.Text = ""
	self.ui.songTitleBox.Text = ""
	self.ui.decalBox.Text = ""
	
	self:displayPlaylistSongs(plName)
	self:saveData()
end

function Spotify:rebuildPlaylistList()
	self.ui.plList.CanvasSize = UDim2.new(0,0,0,0)
	for _, v in ipairs(self.ui.plList:GetChildren()) do
		if not v:IsA("UILayout") then v:Destroy() end
	end
	
	for name, _ in pairs(self.playlists) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 40)
		row.BackgroundTransparency = 1
		row.Parent = self.ui.plList
		
		local selectBtn = Instance.new("TextButton", row)
		selectBtn.Size = UDim2.new(1, -50, 1, 0)
		selectBtn.Text = name
		selectBtn.Font = Enum.Font.Gotham
		selectBtn.TextXAlignment = Enum.TextXAlignment.Left
		Instance.new("UIPadding", selectBtn).PaddingLeft = UDim.new(0, 10)
		Instance.new("UICorner", selectBtn).CornerRadius = UDim.new(0, 8)
		selectBtn.BackgroundColor3 = (name == self.selectedPlaylistName) and THEMES[self.settings.theme].accent or THEMES[self.settings.theme].button
		selectBtn.TextColor3 = THEMES[self.settings.theme].text
		selectBtn.MouseButton1Click:Connect(function()
			self.selectedPlaylistName = name
			self:rebuildPlaylistList()
			self:displayPlaylistSongs(name)
		end)
		
		local deleteBtn = Instance.new("TextButton", row)
		deleteBtn.Size = UDim2.new(0, 40, 1, 0)
		deleteBtn.Position = UDim2.new(1, -40, 0, 0)
		deleteBtn.Text = "X"
		deleteBtn.Font = Enum.Font.GothamBold
		Instance.new("UICorner", deleteBtn).CornerRadius = UDim.new(0, 8)
		deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		deleteBtn.TextColor3 = Color3.new(1,1,1)
		deleteBtn.MouseButton1Click:Connect(function()
			self:deletePlaylist(name)
		end)
	end
end

function Spotify:displayPlaylistSongs(playlistName)
	self.ui.songsPanel.CanvasSize = UDim2.new(0,0,0,0)
	for _, v in ipairs(self.ui.songsPanel:GetChildren()) do
		if not v:IsA("UILayout") then v:Destroy() end
	end
	
	if not playlistName or not self.playlists[playlistName] then return end
	
	for i, song in ipairs(self.playlists[playlistName]) do
		local card = Instance.new("Frame")
		card.Size = self.ui.songsGrid.CellSize
		card.BackgroundColor3 = THEMES[self.settings.theme].button
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
		card.Parent = self.ui.songsPanel
		
		local layout = Instance.new("UIListLayout", card)
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 10)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		Instance.new("UIPadding", card).PaddingLeft = UDim.new(0, 10)
		
		local art = Instance.new("ImageLabel", card)
		art.Size = UDim2.fromOffset(80, 80)
		art.Image = song.decal or DEFAULT_ART_ID
		art.BackgroundTransparency = 1
		
		local textInfo = Instance.new("Frame", card)
		textInfo.Size = UDim2.new(1, -200, 1, 0)
		textInfo.BackgroundTransparency = 1
		Instance.new("UIListLayout", textInfo).Padding = UDim.new(0, 5)
		
		local title = Instance.new("TextLabel", textInfo)
		title.Size = UDim2.new(1, 0, 0.5, 0)
		title.Text = song.title
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = THEMES[self.settings.theme].text
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.BackgroundTransparency = 1
		
		local idLabel = Instance.new("TextLabel", textInfo)
		idLabel.Size = UDim2.new(1, 0, 0.3, 0)
		idLabel.Text = tostring((song.id and song.id:match("(%d+)") ) or "")
		idLabel.Font = Enum.Font.Gotham
		idLabel.TextColor3 = THEMES[self.settings.theme].muted
		idLabel.TextXAlignment = Enum.TextXAlignment.Left
		idLabel.BackgroundTransparency = 1
		
		local controls = Instance.new("Frame", card)
		controls.Size = UDim2.new(0, 80, 1, 0)
		controls.BackgroundTransparency = 1
		local ctrlLayout = Instance.new("UIListLayout", controls)
		ctrlLayout.Padding = UDim.new(0, 5)
		ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		
		local function makeBtn(txt, color)
			local btn = Instance.new("TextButton", controls)
			btn.Size = UDim2.new(1, 0, 0.3, -5)
			btn.Text = txt
			btn.Font = Enum.Font.GothamBold
			btn.BackgroundColor3 = color
			btn.TextColor3 = THEMES[self.settings.theme].text
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
			return btn
		end
		
		makeBtn("▶", THEMES[self.settings.theme].accent).MouseButton1Click:Connect(function()
			self:playSong(song, playlistName, i)
		end)
		makeBtn("✎", THEMES[self.settings.theme].muted).MouseButton1Click:Connect(function()
			self:openEditSong(playlistName, i)
		end)
		makeBtn("X", Color3.fromRGB(200, 50, 50)).MouseButton1Click:Connect(function()
			self:deleteSong(playlistName, i)
		end)
	end
end

function Spotify:deletePlaylist(name)
	self.playlists[name] = nil
	if self.selectedPlaylistName == name then
		self.selectedPlaylistName = nil
		self:displayPlaylistSongs(nil)
	end
	self:rebuildPlaylistList()
	self:saveData()
end

function Spotify:deleteSong(playlistName, index)
	if self.playlists[playlistName] then
		table.remove(self.playlists[playlistName], index)
		self:displayPlaylistSongs(playlistName)
		self:saveData()
	end
end

function Spotify:openEditSong(playlistName, index)
	local song = self.playlists[playlistName][index]
	if not song then return end
	
	self.ui.editTitleBox.Text = song.title or ""
	self.ui.editIdBox.Text = song.id or ""
	self.ui.editDecalBox.Text = song.decal or ""
	self.ui.editOverlay.Visible = true

	if self.connections.saveEdit then self.connections.saveEdit:Disconnect() end
	
	self.connections.saveEdit = self.ui.saveEditBtn.MouseButton1Click:Connect(function()
		self:saveSongChanges(playlistName, index)
	end)
end

function Spotify:saveSongChanges(playlistName, index)
	local song = self.playlists[playlistName][index]
	if not song then return end
	
	song.title = self.ui.editTitleBox.Text
	song.id = self:normalizeSoundId(self.ui.editIdBox.Text)
	song.decal = self:normalizeDecal(self.ui.editDecalBox.Text)
	
	self.ui.editOverlay.Visible = false
	self:displayPlaylistSongs(playlistName)
	self:saveData()
end

function Spotify:rebuildDropdownList()
	self.ui.dropPanel.CanvasSize = UDim2.new(0,0,0,0)
	for _, v in ipairs(self.ui.dropPanel:GetChildren()) do
		if not v:IsA("UILayout") then v:Destroy() end
	end

	for name, songs in pairs(self.playlists) do
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(1, 0, 0, 40)
		btn.Text = name .. " (" .. #songs .. ")"
		btn.Font = Enum.Font.Gotham
		btn.BackgroundColor3 = THEMES[self.settings.theme].button
		btn.TextColor3 = THEMES[self.settings.theme].text
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
		btn.Parent = self.ui.dropPanel
		
		btn.MouseButton1Click:Connect(function()
			self.ui.plDropdown.Text = name
			self.ui.dropPanel.Visible = false
			if #songs > 0 then
				self:playSong(songs[1], name, 1)
			end
		end)
	end
end

function Spotify:searchSounds()
	local query = self.ui.searchBox.Text
	if query == "" then return end
	
	self.ui.searchBtn.Text = "..."
	
	self.ui.searchList.CanvasSize = UDim2.new(0,0,0,0)
	for _, v in ipairs(self.ui.searchList:GetChildren()) do
		if not v:IsA("UILayout") then v:Destroy() end
	end
	
	local success, result = pcall(function()
		return HttpService:GetAsync(SEARCH_API_URL .. HttpService:UrlEncode(query))
	end)
	
	if success and result then
		local success, decoded = pcall(HttpService.JSONDecode, HttpService, result)
		if success and type(decoded) == "table" then
			for _, asset in ipairs(decoded) do
				local card = Instance.new("Frame")
				card.Size = UDim2.new(1, 0, 0, 80)
				card.BackgroundColor3 = THEMES[self.settings.theme].button
				Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
				card.Parent = self.ui.searchList
				
				local layout = Instance.new("UIListLayout", card)
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.Padding = UDim.new(0, 10)
				layout.VerticalAlignment = Enum.VerticalAlignment.Center
				Instance.new("UIPadding", card).PaddingLeft = UDim.new(0, 10)
				
				local infoFrame = Instance.new("Frame", card)
				infoFrame.Size = UDim2.new(1, -150, 1, 0)
				infoFrame.BackgroundTransparency = 1
				Instance.new("UIListLayout", infoFrame).Padding = UDim.new(0, 5)

				local title = Instance.new("TextLabel", infoFrame)
				title.Size = UDim2.new(1, 0, 0.5, 0)
				title.Text = asset.Name or "Unknown"
				title.Font = Enum.Font.GothamBold
				title.TextColor3 = THEMES[self.settings.theme].text
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.BackgroundTransparency = 1
				
				local creator = Instance.new("TextLabel", infoFrame)
				creator.Size = UDim2.new(1, 0, 0.3, 0)
				creator.Text = "by " .. (asset.Creator or "Unknown")
				creator.Font = Enum.Font.Gotham
				creator.TextColor3 = THEMES[self.settings.theme].muted
				creator.TextXAlignment = Enum.TextXAlignment.Left
				creator.BackgroundTransparency = 1
				
				local playBtn = Instance.new("TextButton", card)
				playBtn.Size = UDim2.fromOffset(60, 60)
				playBtn.Text = "▶"
				playBtn.Font = Enum.Font.GothamBold
				playBtn.BackgroundColor3 = THEMES[self.settings.theme].accent
				playBtn.TextColor3 = THEMES[self.settings.theme].text
				Instance.new("UICorner", playBtn).CornerRadius = UDim.new(0, 8)
				playBtn.MouseButton1Click:Connect(function()
					local songData = {
						id = "rbxassetid://" .. asset.AssetId,
						title = asset.Name,
						decal = "rbxassetid://" .. asset.AssetId
					}
					self:playSong(songData, "Search Results", 1)
				end)

				local addBtn = Instance.new("TextButton", card)
				addBtn.Size = UDim2.fromOffset(60, 60)
				addBtn.Text = "+"
				addBtn.Font = Enum.Font.GothamBold
				addBtn.BackgroundColor3 = THEMES[self.settings.theme].button
				addBtn.TextColor3 = THEMES[self.settings.theme].text
				Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 8)
				addBtn.MouseButton1Click:Connect(function()
					if self.selectedPlaylistName and self.playlists[self.selectedPlaylistName] then
						self.ui.songIdBox.Text = tostring(asset.AssetId)
						self.ui.songTitleBox.Text = asset.Name
						self:addSongToPlaylist()
						self:showPage(self.ui.playlistsPage)
					end
				end)
			end
		end
	end
	
	self.ui.searchBtn.Text = "Search"
end

function Spotify:init()
	local loadedData = self:loadData()
	if loadedData then
		self.playlists = loadedData.playlists or {}
		if loadedData.settings then
			self.settings.theme = loadedData.settings.theme or "Dark"
			self.settings.volume = loadedData.settings.volume or 0.5
			local keyName = loadedData.settings.toggleKeyString
			if keyName and Enum.KeyCode[keyName] then
				self.settings.toggleKey = Enum.KeyCode[keyName]
			end
		end
	end
	
	self:createUI()
	
	self:updateHomeInfo()
	
	self:applyTheme(self.settings.theme)
	
	self.connections.toggleInput = UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == self.settings.toggleKey and not (UserInputService:GetFocusedTextBox()) then
			self:toggleUI()
		end
	end)

	self.connections.playPause = self.ui.playPauseBtn.MouseButton1Click:Connect(function() self:togglePlayPause() end)
	self.connections.next = self.ui.nextBtn.MouseButton1Click:Connect(function() self:playNext() end)
	-- volume slider handled by custom Input events
	
	self.connections.shuffle = self.ui.shuffleBtn.MouseButton1Click:Connect(function()
		self.isShuffling = not self.isShuffling
		if self.ui and self.ui.shuffleBtn then
			self.ui.shuffleBtn.BackgroundColor3 = self.isShuffling and THEMES[self.settings.theme].accent or THEMES[self.settings.theme].button
		end
	end)
	
	self.connections.repeatClick = self.ui.repeatBtn.MouseButton1Click:Connect(function()
		if self.repeatMode == "None" then self.repeatMode = "Playlist"
		elseif self.repeatMode == "Playlist" then self.repeatMode = "Song"
		else self.repeatMode = "None" end
		
		if self.ui and self.ui.repeatBtn then
			self.ui.repeatBtn.Text = (self.repeatMode == "Song") and "🔁¹" or "🔁"
			self.ui.repeatBtn.BackgroundColor3 = (self.repeatMode ~= "None") and THEMES[self.settings.theme].accent or THEMES[self.settings.theme].button
		end
	end)
	
	self.connections.renderStep = RunService.RenderStepped:Connect(function()
		if self.currentSound and self.isPlaying then
			local loudness = 0
			-- PlaybackLoudness is only available under certain contexts; guard it
			if pcall(function() loudness = self.currentSound.PlaybackLoudness end) then end
			for i, bar in ipairs(self.ui.visualizerBars) do
				local targetHeight = math.clamp((math.log(1 + loudness) / 6) or 0.05, 0.05, 1) * (1 - math.abs(i - 10.5)/10)
				bar.Size = UDim2.new(bar.Size.X.Scale, bar.Size.X.Offset, targetHeight, 0)
			end
		else
			for _, bar in ipairs(self.ui.visualizerBars) do
				bar.Size = UDim2.new(bar.Size.X.Scale, bar.Size.X.Offset, 0.05, 0)
			end
		end
	end)
end

function Spotify:updateHomeInfo()
	if self.ui.displayNameLabel then
		self.ui.displayNameLabel.Text = "@" .. (self.player and self.player.Name or "Player")
	end
	local userId = self.player and self.player.UserId
	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size150x150
	local success, content = pcall(Players.GetUserThumbnailAsync, Players, userId, thumbType, thumbSize)
	if success and content and self.ui.playerImage then
		self.ui.playerImage.Image = content
	end
	
	local hour = tonumber(os.date("%H")) or 12
	if hour < 12 then
		if self.ui.greetingLabel then self.ui.greetingLabel.Text = "Good morning" end
	elseif hour < 18 then
		if self.ui.greetingLabel then self.ui.greetingLabel.Text = "Good afternoon" end
	else
		if self.ui.greetingLabel then self.ui.greetingLabel.Text = "Good evening" end
	end

	self:rebuildHomeList()
end


-- Main Execution
local MySpotify = Spotify.new()
MySpotify:init()
