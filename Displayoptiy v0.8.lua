local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

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

-- Core Spotify Module
local Spotify = {}
Spotify.__index = Spotify

function Spotify.new()
	local self = setmetatable({}, Spotify)
	
	-- State
	self.player = Players.LocalPlayer
	self.playlists = {}
	self.settings = { theme = "Dark", toggleKey = Enum.KeyCode.M }
	self.selectedPlaylistName = nil
	self.currentSound = nil
	self.currentPlaylistName = nil
	self.currentIndex = 0
	self.connections = {}
	self.ui = {}
    self.isExecutor = true

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
                toggleKeyString = self.settings.toggleKey.Name
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
        warn("Failed to load data or data file not found:", data or err)
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
    self.ui.screenGui.Parent = game:GetService("CoreGui")
	
	self.ui.mainFrame = Instance.new("Frame")
	self.ui.mainFrame.Name = "Main"
	self.ui.mainFrame.Size = UDim2.new(0.9, 0, 0.9, 0)
	self.ui.mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	self.ui.mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.ui.mainFrame.ClipsDescendants = true
	self.ui.mainFrame.Visible = false
	self.ui.mainFrame.Parent = self.ui.screenGui
	
	Instance.new("UICorner", self.ui.mainFrame).CornerRadius = UDim.new(0, 14)
	Instance.new("UIStroke", self.ui.mainFrame).Thickness = 2
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
	self.ui.gameStatsLabel.Text = "0 game songs found."
	self.ui.gameStatsLabel.Font = Enum.Font.Gotham
	self.ui.gameStatsLabel.TextScaled = true
	self.ui.gameStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.ui.gameStatsLabel.BackgroundTransparency = 1
	
	self.ui.homeList = Instance.new("ScrollingFrame", self.ui.homePage)
	self.ui.homeList.Size = UDim2.new(1, 0, 1, -130)
	self.ui.homeList.Position = UDim2.new(0, 0, 0, 130)
	self.ui.homeList.BackgroundTransparency = 1
	self.ui.homeList.ScrollBarThickness = 6
	self.ui.homeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.ui.homeListLayout = Instance.new("UIListLayout", self.ui.homeList)
	self.ui.homeListLayout.Padding = UDim.new(0, 8)
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
	
	local nowControls = Instance.new("Frame", nowRight)
	nowControls.Size = UDim2.new(1, 0, 0, 40)
	nowControls.BackgroundTransparency = 1
    
	local ctrlLayout = Instance.new("UIListLayout", nowControls)
	ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
	ctrlLayout.Padding = UDim.new(0, 10)
	ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	
	local function makeCtrl(txt)
		local btn = Instance.new("TextButton", nowControls)
		btn.Size = UDim2.new(0.5, -5, 1, 0)
		btn.Text = txt
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
		return btn
	end
	
	self.ui.playPauseBtn = makeCtrl("▶ / ⏸")
	self.ui.nextBtn = makeCtrl("⏭ Next")
	
	local plRow = Instance.new("Frame", self.ui.musicPage)
	plRow.Size = UDim2.new(1, 0, 0, 64)
	plRow.Position = UDim2.new(0, 0, 0, 230)
	Instance.new("UICorner", plRow).CornerRadius = UDim.new(0, 12)
    Instance.new("UIPadding", plRow).PaddingLeft = UDim.new(0, 12)
    Instance.new("UIPadding", plRow).PaddingRight = UDim.new(0, 12)
	self.ui.plRow = plRow
	
	self.ui.plDropdown = Instance.new("TextButton", plRow)
	self.ui.plDropdown.Size = UDim2.new(1, 0, 1, -12)
	self.ui.plDropdown.Position = UDim2.new(0, 0, 0, 6)
	self.ui.plDropdown.Text = "Select a Playlist..."
	self.ui.plDropdown.Font = Enum.Font.Gotham
	self.ui.plDropdown.TextScaled = true
	Instance.new("UICorner", self.ui.plDropdown).CornerRadius = UDim.new(0, 8)
	
	self.ui.dropPanel = Instance.new("ScrollingFrame", self.ui.musicPage)
	self.ui.dropPanel.Size = UDim2.new(1, 0, 1, -290)
	self.ui.dropPanel.Position = UDim2.new(0, 0, 0, 290)
	self.ui.dropPanel.Visible = false
	self.ui.dropPanel.ScrollBarThickness = 6
	Instance.new("UICorner", self.ui.dropPanel).CornerRadius = UDim.new(0, 12)
	
	self.ui.dropLayout = Instance.new("UIListLayout", self.ui.dropPanel)
	self.ui.dropLayout.Padding = UDim.new(0, 8)
	
	self.connections.dropdownClick = self.ui.plDropdown.MouseButton1Click:Connect(function()
		self.ui.dropPanel.Visible = not self.ui.dropPanel.Visible
		if self.ui.dropPanel.Visible then
			self:rebuildDropdownList()
			self.connections.dropdownInput = UserInputService.InputBegan:Connect(function(input, gp)
				if not self.ui.dropPanel:IsAncestorOf(input.Source) and input.Source ~= self.ui.plDropdown and input.UserInputType ~= Enum.UserInputType.Touch then
					self.ui.dropPanel.Visible = false
					if self.connections.dropdownInput then
						self.connections.dropdownInput:Disconnect()
						self.connections.dropdownInput = nil
					end
				end
			end)
		end
	end)
end

function Spotify:createPlaylistsPageUI()
	local viewportSize = Workspace.CurrentCamera.ViewportSize
	local isMobile = viewportSize.X < viewportSize.Y * 1.5
	
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
	self.ui.songsGrid.CellSize = UDim2.new(isMobile and 1 or 0.5, isMobile and -12 or -18, 0, 100)
	
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

	local editTitleBox = Instance.new("TextBox", editFrame)
	editTitleBox.Size = UDim2.new(1, -24, 0, 40)
	editTitleBox.Position = UDim2.new(0, 12, 0, 60)
	editTitleBox.PlaceholderText = "Title"
	editTitleBox.Font = Enum.Font.Gotham
	editTitleBox.TextScaled = true
	Instance.new("UICorner", editTitleBox).CornerRadius = UDim.new(0, 8)
	self.ui.editTitleBox = editTitleBox

	local editIdBox = Instance.new("TextBox", editFrame)
	editIdBox.Size = UDim2.new(1, -24, 0, 40)
	editIdBox.Position = UDim2.new(0, 12, 0, 110)
	editIdBox.PlaceholderText = "Song ID"
	editIdBox.Font = Enum.Font.Gotham
	editIdBox.TextScaled = true
	Instance.new("UICorner", editIdBox).CornerRadius = UDim.new(0, 8)
	self.ui.editIdBox = editIdBox

	local editDecalBox = Instance.new("TextBox", editFrame)
	editDecalBox.Size = UDim2.new(1, -24, 0, 40)
	editDecalBox.Position = UDim2.new(0, 12, 0, 160)
	editDecalBox.PlaceholderText = "Decal ID"
	editDecalBox.Font = Enum.Font.Gotham
	editDecalBox.TextScaled = true
	Instance.new("UICorner", editDecalBox).CornerRadius = UDim.new(0, 8)
	self.ui.editDecalBox = editDecalBox

	local saveBtn = Instance.new("TextButton", editFrame)
	saveBtn.Size = UDim2.new(0.4, 0, 0, 40)
	saveBtn.Position = UDim2.new(0.5, 0, 0, 210)
	saveBtn.AnchorPoint = Vector2.new(0.5, 0)
	saveBtn.Text = "Save"
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.TextScaled = true
	Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 8)
	self.ui.saveEditBtn = saveBtn

	local cancelBtn = Instance.new("TextButton", editFrame)
	cancelBtn.Size = UDim2.new(0, 40, 0, 40)
	cancelBtn.Position = UDim2.new(1, -12, 0, 12)
	cancelBtn.AnchorPoint = Vector2.new(1, 0)
	cancelBtn.Text = "X"
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.TextScaled = true
	Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 8)
	self.ui.cancelEditBtn = cancelBtn

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
	
	self.ui.searchBox.Changed:Connect(function()
		if self.ui.searchBox.Text == "" then
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
		local conn = nil
		conn = UserInputService.InputBegan:Connect(function(input, gp)
			if not gp and input.UserInputType == Enum.UserInputType.Keyboard then
				self.settings.toggleKey = input.KeyCode
				self.ui.kbRow.Text = "Current: " .. input.KeyCode.Name
				self:saveData()
				conn:Disconnect()
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
    self.ui.unloadBtn.BackgroundColor3 = THEMES[self.settings.theme].accent
    self.ui.unloadBtn.TextColor3 = THEMES[self.settings.theme].text

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
	self.ui.homePage.Visible = (page == self.ui.homePage)
	self.ui.musicPage.Visible = (page == self.ui.musicPage)
	self.ui.playlistsPage.Visible = (page == self.ui.playlistsPage)
	self.ui.searchPage.Visible = (page == self.ui.searchPage)
	self.ui.settingsPage.Visible = (page == self.ui.settingsPage)
	
	if page == self.ui.homePage then
		self:rebuildHomeList()
	end

	if page == self.ui.searchPage then
		self:searchSounds()
	end
end

function Spotify:applyTheme(themeName)
	if not THEMES[themeName] then return end
	self.settings.theme = themeName
	local theme = THEMES[themeName]
	
	TweenService:Create(self.ui.mainFrame, TweenInfo.new(0.3), { BackgroundColor3 = theme.bg }):Play()
	self.ui.resizeHandle.BackgroundColor3 = theme.accent
	
	local function applyRecursive(obj)
		if obj:IsA("Frame") or obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") or obj:IsA("ImageLabel") then
			if obj.Name ~= "TopBar" and obj.Name ~= "Background" then
				obj.BackgroundColor3 = theme.panel
			end
		end

		if obj:IsA("TextLabel") then
			obj.TextColor3 = theme.text
		elseif obj:IsA("TextBox") then
			obj.BackgroundColor3 = theme.button
			obj.TextColor3 = theme.text
		elseif obj:IsA("TextButton") then
			local isAccent = obj == self.ui.addPlButton or obj == self.ui.addSongButton or obj == self.ui.playPauseBtn or obj == self.ui.nextBtn or obj == self.ui.searchBtn or obj == self.ui.saveEditBtn or obj == self.ui.unloadBtn
			if isAccent then
				obj.BackgroundColor3 = theme.accent
				obj.TextColor3 = theme.text
			else
				obj.BackgroundColor3 = theme.button
				obj.TextColor3 = theme.text
			end
		end
		
		for _, child in obj:GetChildren() do
			applyRecursive(child)
		end
	end
	
	applyRecursive(self.ui.mainFrame)
	self.ui.topBar.BackgroundColor3 = theme.panel
	self.ui.editFrame.BackgroundColor3 = theme.panel
	
	if self.ui.addSongRow then
		self.ui.addSongRow.BackgroundColor3 = theme.panel
	end
	if self.ui.createRow then
		self.ui.createRow.BackgroundColor3 = theme.panel
	end
	if self.ui.searchRow then
		self.ui.searchRow.BackgroundColor3 = theme.panel
	end
	
	self:refreshSongsGrid()
end

function Spotify:playSong(song, playlistName, songIndex)
	if self.currentSound then
		self.currentSound:Stop()
		self.currentSound:Destroy()
		self.currentSound = nil
	end
	
	local soundId = self:normalizeSoundId(song.id)
	if not soundId then
		self.ui.nowTitle.Text = "Now Playing: Invalid ID"
		return
	end
	
	local sound = Instance.new("Sound")
	sound.Name = "NextSpotifySound"
	sound.SoundId = soundId
	sound.Volume = 1
	sound.Parent = Workspace
	
	local ok, err = pcall(function()
		sound:Play()
	end)
	
	if not ok then
		warn("Failed to play sound:", err)
		self.ui.nowTitle.Text = "Now Playing: Failed"
		if sound then sound:Destroy() end
		return
	end
	
	self.currentSound = sound
	self.currentPlaylistName = playlistName
	self.currentIndex = songIndex
	
	self.ui.nowArt.Image = (song.decal and song.decal ~= "") and self:normalizeDecal(song.decal) or DEFAULT_ART_ID
	self.ui.nowTitle.Text = "Now Playing: " .. (song.title ~= "" and song.title or tostring(song.id))
	
	self.connections.playbackFinished = sound.Ended:Connect(function()
		self:playNextSong()
	end)
end

function Spotify:playNextSong()
	local playlist = self.playlists[self.currentPlaylistName]
	if not playlist or #playlist.songs == 0 then return end
	
	self.currentIndex = (self.currentIndex % #playlist.songs) + 1
	local nextSong = playlist.songs[self.currentIndex]
	
	self:playSong(nextSong, self.currentPlaylistName, self.currentIndex)
end

function Spotify:playPause()
	if self.currentSound then
		if self.currentSound.IsPlaying then
			self.currentSound:Pause()
		else
			local ok = pcall(function() self.currentSound:Resume() end)
			if not ok then
				self.currentSound:Play()
			end
		end
	else
		local name = self.ui.plDropdown.Text
		if self.playlists[name] and #self.playlists[name].songs > 0 then
			self.selectedPlaylistName = name
			self:playSong(self.playlists[name].songs[1], name, 1)
		end
	end
end

function Spotify:rebuildDropdownList()
	for _, child in self.ui.dropPanel:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	
	for name, _ in pairs(self.playlists) do
		local btn = Instance.new("TextButton", self.ui.dropPanel)
		btn.Size = UDim2.new(1, 0, 0, 36)
		btn.Text = name
		btn.Font = Enum.Font.Gotham
		btn.TextScaled = true
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
		btn.BackgroundColor3 = THEMES[self.settings.theme].button
		btn.TextColor3 = THEMES[self.settings.theme].text
		
		btn.MouseButton1Click:Connect(function()
			self.ui.plDropdown.Text, self.selectedPlaylistName, self.currentPlaylistName = name, name, name
			self.ui.dropPanel.Visible = false
			if self.connections.dropdownInput then
                self.connections.dropdownInput:Disconnect()
                self.connections.dropdownInput = nil
            end
		end)
	end
end

function Spotify:createPlaylist()
	local name = string.gsub(self.ui.newPlBox.Text or "", "^%s*(.-)%s*$", "%1")
	if name ~= "" and not self.playlists[name] then
		self.playlists[name] = { songs = {} }
		self.ui.newPlBox.Text = ""
		self:rebuildPlaylistList()
		self:saveData()
	end
end

function Spotify:rebuildPlaylistList()
	for _, child in self.ui.plList:GetChildren() do
		if child:IsA("GuiObject") and child ~= self.ui.plListLayout then
			child:Destroy()
		end
	end
	
	for name, _ in pairs(self.playlists) do
		local btn = Instance.new("TextButton", self.ui.plList)
		btn.Name = name .. "Button"
		btn.Size = UDim2.new(1, -10, 0, 44)
		btn.Text = name
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
		btn.BackgroundColor3 = THEMES[self.settings.theme].button
		btn.TextColor3 = THEMES[self.settings.theme].text
		
		btn.MouseButton1Click:Connect(function()
			self.ui.plDropdown.Text, self.selectedPlaylistName, self.currentPlaylistName = name, name, name
			self:refreshSongsGrid()
			self.ui.addSongRow.Visible = true
		end)
	end
end

function Spotify:updateHomeHeader()
	local localPlayer = self.player
	local displayName = localPlayer.DisplayName or localPlayer.Name
	local currentTime = tonumber(os.date("%H"))
	local greeting = "Hello"
	
	if currentTime >= 5 and currentTime < 12 then
		greeting = "Good Morning"
	elseif currentTime >= 12 and currentTime < 18 then
		greeting = "Good Afternoon"
	else
		greeting = "Good Evening"
	end
	
	self.ui.greetingLabel.Text = greeting .. ", " .. displayName .. "!"
	self.ui.displayNameLabel.Text = "@" .. localPlayer.Name
	
	local success, thumbnail = pcall(function()
		return Players:GetUserThumbnailAsync(localPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if success and thumbnail then
		self.ui.playerImage.Image = thumbnail
	end

	local totalSongs = 0
	local gameSounds = 0

	for _, playlist in pairs(self.playlists) do
		totalSongs = totalSongs + #playlist.songs
	end

	for _, sound in SoundService:GetChildren() do
		if sound:IsA("Sound") and sound.SoundId and sound.TimeLength > 60 then
			gameSounds = gameSounds + 1
		end
	end
	
	self.ui.songStatsLabel.Text = totalSongs .. " user songs found."
	self.ui.gameStatsLabel.Text = gameSounds .. " game songs found."
end

function Spotify:rebuildHomeList()
	for _, child in self.ui.homeList:GetChildren() do
		child:Destroy()
	end
	
	self:updateHomeHeader()

	local allSongs = {}
	for plName, playlist in pairs(self.playlists) do
		for i, song in ipairs(playlist.songs) do
			table.insert(allSongs, { source = "Player", playlistName = plName, song = song, index = i })
		end
	end
	
	local sortedSongs = {}
	for _, sound in SoundService:GetChildren() do
		if sound:IsA("Sound") and sound.SoundId and sound.TimeLength > 60 then
			table.insert(sortedSongs, { source = "Game", title = sound.Name, id = sound.SoundId })
		end
	end
	
	for _, songData in ipairs(allSongs) do
		table.insert(sortedSongs, { source = "Player", title = songData.song.title, id = songData.song.id, decal = songData.song.decal, playlistName = songData.playlistName, index = songData.index })
	end

	for _, songData in ipairs(sortedSongs) do
		local card = self:createHomeSongCard(songData)
		if card then
			card.Parent = self.ui.homeList
		end
	end
end

function Spotify:createHomeSongCard(songData)
	local card = Instance.new("Frame")
	card.Name = "HomeSongCard"
	card.Size = UDim2.new(1, 0, 0, 100)
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
	card.BackgroundColor3 = THEMES[self.settings.theme].button

	local art = Instance.new("ImageLabel", card)
	art.Size = UDim2.fromOffset(80, 80)
	art.Position = UDim2.new(0, 10, 0.5, -40)
	art.AnchorPoint = Vector2.new(0, 0.5)
	art.BackgroundTransparency = 1
	art.Image = (songData.decal and songData.decal ~= "") and self:normalizeDecal(songData.decal) or DEFAULT_ART_ID

	local titleL = Instance.new("TextLabel", card)
	titleL.Size = UDim2.new(1, -240, 0, 28)
	titleL.Position = UDim2.new(0, 100, 0, 22)
	titleL.Font = Enum.Font.GothamBold
	titleL.TextScaled = true
	titleL.TextXAlignment = Enum.TextXAlignment.Left
	titleL.Text = (songData.title and songData.title ~= "" and songData.title or ("ID: " .. tostring(songData.id)))
	titleL.BackgroundTransparency = 1
	titleL.TextColor3 = THEMES[self.settings.theme].text
	
	local sourceL = Instance.new("TextLabel", card)
	sourceL.Size = UDim2.new(1, -240, 0, 20)
	sourceL.Position = UDim2.new(0, 100, 0, 54)
	sourceL.Font = Enum.Font.Gotham
	sourceL.TextScaled = true
	sourceL.TextXAlignment = Enum.TextXAlignment.Left
	sourceL.Text = "Source: " .. (songData.source == "Game" and "In-Game" or "User Playlist")
	sourceL.BackgroundTransparency = 1
	sourceL.TextColor3 = THEMES[self.settings.theme].muted

	local playB = Instance.new("TextButton", card)
	playB.Size = UDim2.new(0, 50, 0, 28)
	playB.Position = UDim2.new(1, -120, 0.5, -14)
	playB.AnchorPoint = Vector2.new(0, 0.5)
	playB.Text = "▶"
	playB.Font = Enum.Font.GothamBold
	playB.TextScaled = true
	Instance.new("UICorner", playB).CornerRadius = UDim.new(0, 6)
	playB.BackgroundColor3 = THEMES[self.settings.theme].accent
	playB.TextColor3 = THEMES[self.settings.theme].text

	playB.MouseButton1Click:Connect(function()
		local soundToPlay = { id = songData.id, title = songData.title, decal = songData.decal }
		self:playSong(soundToPlay, songData.playlistName or "Home", songData.index or 1)
	end)

	return card
end

function Spotify:createSongCard(song, playlistName, index, isHome)
	local card = Instance.new("Frame")
	card.Name = "SongCard_" .. song.id
	card.Size = UDim2.new(1, 0, 0, 100)
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
	card.BackgroundColor3 = THEMES[self.settings.theme].button

	local art = Instance.new("ImageLabel", card)
	art.Size = UDim2.fromOffset(80, 80)
	art.Position = UDim2.new(0, 10, 0.5, -40)
	art.AnchorPoint = Vector2.new(0, 0.5)
	art.BackgroundTransparency = 1
	art.Image = (song.decal and song.decal ~= "") and self:normalizeDecal(song.decal) or DEFAULT_ART_ID

	local titleL = Instance.new("TextLabel", card)
	titleL.Size = UDim2.new(1, -240, 0, 28)
	titleL.Position = UDim2.new(0, 100, 0, 22)
	titleL.Font = Enum.Font.GothamBold
	titleL.TextScaled = true
	titleL.TextXAlignment = Enum.TextXAlignment.Left
	titleL.Text = (song.title and song.title ~= "" and song.title or ("ID: " .. tostring(song.id)))
	titleL.BackgroundTransparency = 1
	titleL.TextColor3 = THEMES[self.settings.theme].text

	local idL = Instance.new("TextLabel", card)
	idL.Size = UDim2.new(1, -240, 0, 20)
	idL.Position = UDim2.new(0, 100, 0, 54)
	idL.Font = Enum.Font.Gotham
	idL.TextScaled = true
	idL.TextXAlignment = Enum.TextXAlignment.Left
	idL.Text = "Song ID: " .. tostring(song.id)
	idL.BackgroundTransparency = 1
	idL.TextColor3 = THEMES[self.settings.theme].muted

	local playB = Instance.new("TextButton", card)
	playB.Size = UDim2.new(0, 50, 0, 28)
	playB.Position = UDim2.new(1, -120, 0.5, -14)
	playB.AnchorPoint = Vector2.new(0, 0.5)
	playB.Text = "▶"
	playB.Font = Enum.Font.GothamBold
	playB.TextScaled = true
	Instance.new("UICorner", playB).CornerRadius = UDim.new(0, 6)
	playB.BackgroundColor3 = THEMES[self.settings.theme].accent
	playB.TextColor3 = THEMES[self.settings.theme].text

	playB.MouseButton1Click:Connect(function()
		self:playSong(song, playlistName, index)
	end)

	if not isHome then
		local rmB = Instance.new("TextButton", card)
		rmB.Size = UDim2.new(0, 40, 0, 28)
		rmB.Position = UDim2.new(1, -60, 0.5, -14)
		rmB.AnchorPoint = Vector2.new(0, 0.5)
		rmB.Text = "🗑️"
		rmB.Font = Enum.Font.Gotham
		rmB.TextScaled = true
		Instance.new("UICorner", rmB).CornerRadius = UDim.new(0, 6)
		rmB.BackgroundColor3 = THEMES[self.settings.theme].button
		rmB.TextColor3 = THEMES[self.settings.theme].text
		
		local editB = Instance.new("TextButton", card)
		editB.Size = UDim2.new(0, 40, 0, 28)
		editB.Position = UDim2.new(1, -105, 0.5, -14)
		editB.AnchorPoint = Vector2.new(0, 0.5)
		editB.Text = "✎"
		editB.Font = Enum.Font.Gotham
		editB.TextScaled = true
		Instance.new("UICorner", editB).CornerRadius = UDim.new(0, 6)
		editB.BackgroundColor3 = THEMES[self.settings.theme].button
		editB.TextColor3 = THEMES[self.settings.theme].text

		rmB.MouseButton1Click:Connect(function()
			table.remove(self.playlists[playlistName].songs, index)
			self:refreshSongsGrid()
			self:saveData()
		end)

		editB.MouseButton1Click:Connect(function()
			self:editSong(song, playlistName, index)
		end)
	end

	return card
end

function Spotify:editSong(song, playlistName, index)
	self.ui.editOverlay.Visible = true
	self.ui.editTitleBox.Text = song.title or ""
	self.ui.editIdBox.Text = tostring(song.id)
	self.ui.editDecalBox.Text = song.decal or ""

	local saveConn = nil
	saveConn = self.ui.saveEditBtn.MouseButton1Click:Connect(function()
		local newTitle = self.ui.editTitleBox.Text
		local newId = self.ui.editIdBox.Text
		local newDecal = self.ui.editDecalBox.Text

		local soundTest = Instance.new("Sound")
		soundTest.SoundId = self:normalizeSoundId(newId)
		soundTest.Parent = Workspace
		wait()
		if soundTest.IsLoaded then
			self.playlists[playlistName].songs[index].title = newTitle
			self.playlists[playlistName].songs[index].id = newId
			self.playlists[playlistName].songs[index].decal = newDecal
			self:saveData()
			self:refreshSongsGrid()
			self.ui.editOverlay.Visible = false
		else
			warn("Invalid new song ID.")
		end
		soundTest:Destroy()
		saveConn:Disconnect()
	end)
end

function Spotify:addSongToPlaylist()
	if not self.selectedPlaylistName then return end
	local id = string.gsub(self.ui.songIdBox.Text or "", "^%s*(.-)%s*$", "%1")
	if id == "" then return end
	
	local title = string.gsub(self.ui.songTitleBox.Text or "", "^%s*(.-)%s*$", "%1")
	local decal = string.gsub(self.ui.decalBox.Text or "", "^%s*(.-)%s*$", "%1")

	local soundTest = Instance.new("Sound")
	soundTest.SoundId = self:normalizeSoundId(id)
	soundTest.Parent = Workspace
	wait()
	
	if soundTest.IsLoaded then
		table.insert(self.playlists[self.selectedPlaylistName].songs, { id = id, decal = decal, title = title })
		self.ui.songIdBox.Text, self.ui.songTitleBox.Text, self.ui.decalBox.Text = "", "", ""
		self:refreshSongsGrid()
		self:saveData()
	else
		warn("Sound is not a valid or loaded asset.")
	end
	
	soundTest:Destroy()
end

function Spotify:refreshSongsGrid()
	for _, child in self.ui.songsPanel:GetChildren() do
		if child:IsA("GuiObject") and child ~= self.ui.songsGrid then
			child:Destroy()
		end
	end
	
	if not self.selectedPlaylistName or not self.playlists[self.selectedPlaylistName] then
		self.ui.addSongButton.Text = "Select PL"
		self.ui.addSongRow.BackgroundColor3 = THEMES[self.settings.theme].muted
		return
	end
	
	self.ui.addSongButton.Text = "Add"
	self.ui.addSongRow.BackgroundColor3 = THEMES[self.settings.theme].panel
	
	for i, song in ipairs(self.playlists[self.selectedPlaylistName].songs) do
		local card = self:createSongCard(song, self.selectedPlaylistName, i, false)
		card.Parent = self.ui.songsPanel
	end
end

function Spotify:searchSounds()
	local query = self.ui.searchBox.Text
	
	for _, child in self.ui.searchList:GetChildren() do
		if child:IsA("GuiObject") and child ~= self.ui.searchListLayout then
			child:Destroy()
		end
	end
	
	local function createSearchCard(soundId, name, length)
		local card = Instance.new("Frame")
		card.Name = "SoundCard_" .. soundId
		card.Size = UDim2.new(1, 0, 0, 60)
		card.BackgroundColor3 = THEMES[self.settings.theme].button
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
		card.Parent = self.ui.searchList
		
		local titleL = Instance.new("TextLabel", card)
		titleL.Size = UDim2.new(1, -120, 0, 24)
		titleL.Position = UDim2.new(0, 10, 0, 8)
		titleL.Text = name
		titleL.Font = Enum.Font.GothamBold
		titleL.TextScaled = true
		titleL.TextXAlignment = Enum.TextXAlignment.Left
		titleL.BackgroundTransparency = 1
		titleL.TextColor3 = THEMES[self.settings.theme].text
		
		local idL = Instance.new("TextLabel", card)
		idL.Size = UDim2.new(1, -120, 0, 20)
		idL.Position = UDim2.new(0, 10, 0, 32)
		idL.Text = "ID: " .. soundId .. " (" .. math.floor(length) .. "s)"
		idL.Font = Enum.Font.Gotham
		idL.TextScaled = true
		idL.TextXAlignment = Enum.TextXAlignment.Left
		idL.BackgroundTransparency = 1
		idL.TextColor3 = THEMES[self.settings.theme].muted
		
		local addBtn = Instance.new("TextButton", card)
		addBtn.Size = UDim2.new(0, 40, 0, 40)
		addBtn.Position = UDim2.new(1, -50, 0.5, -20)
		addBtn.Text = "➕"
		addBtn.Font = Enum.Font.Gotham
		addBtn.TextScaled = true
		Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)
		addBtn.BackgroundColor3 = THEMES[self.settings.theme].accent
		
		addBtn.MouseButton1Click:Connect(function()
			local playlistName = self.ui.plDropdown.Text
			if self.playlists[playlistName] then
				table.insert(self.playlists[playlistName].songs, { id = soundId, title = name, decal = "" })
				self:saveData()
				self:rebuildPlaylistList()
				self:refreshSongsGrid()
				self:showPage(self.ui.playlistsPage)
			end
		end)
	end
	
	if query == "" then
		-- Automatically show all long in-game sounds
		for _, sound in SoundService:GetChildren() do
			if sound:IsA("Sound") and sound.SoundId and sound.TimeLength > 60 then
				local name = sound.Name
				local soundId = self:normalizeSoundId(sound.SoundId)
				if soundId then
					createSearchCard(soundId, name, sound.TimeLength)
				end
			end
		end
	else
		-- Search in-game sounds
		for _, sound in SoundService:GetChildren() do
			if sound:IsA("Sound") and sound.SoundId and sound.TimeLength > 60 then
				local name = sound.Name
				local soundId = self:normalizeSoundId(sound.SoundId)
				if soundId and (string.find(string.lower(name), string.lower(query)) or string.find(tostring(soundId), tostring(query))) then
					createSearchCard(soundId, name, sound.TimeLength)
				end
			end
		end

		-- Check for manually entered catalog IDs
		local soundTest = Instance.new("Sound")
		soundTest.SoundId = "rbxassetid://" .. query
		soundTest.Parent = Workspace
		wait()
		if soundTest.IsLoaded then
			createSearchCard(query, "Catalog Sound", soundTest.TimeLength)
		else
			warn("Could not find a valid sound with that ID.")
		end
		soundTest:Destroy()
	end
end

function Spotify:setupGlobalConnections()
	self.connections.playPauseBtn = self.ui.playPauseBtn.MouseButton1Click:Connect(function()
		self:playPause()
	end)
	
	self.connections.nextBtn = self.ui.nextBtn.MouseButton1Click:Connect(function()
		self:playNextSong()
	end)
	
	self.connections.toggleKey = UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == self.settings.toggleKey then
			self.ui.screenGui.Enabled = not self.ui.screenGui.Enabled
		end
	end)
end

function Spotify:cleanup()
	for _, conn in pairs(self.connections) do
		conn:Disconnect()
	end
	
	if self.currentSound then
		self.currentSound:Stop()
		self.currentSound:Destroy()
	end
	
	if self.ui.screenGui and self.ui.screenGui.Parent then
		self.ui.screenGui:Destroy()
	end
	
	self.connections = {}
	self.ui = {}
end

--------------------
--- Initialization
--------------------
function Spotify:init()
	local loadingOverlay = Instance.new("Frame")
	loadingOverlay.Name = "LoadingOverlay"
	loadingOverlay.Size = UDim2.fromScale(1, 1)
	loadingOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	loadingOverlay.Parent = game:GetService("CoreGui")
	
	local blur = Instance.new("BlurEffect", Lighting)
	blur.Size = 18
	
	local loadingLabel = Instance.new("TextLabel", loadingOverlay)
	loadingLabel.Size = UDim2.fromScale(1, 0)
	loadingLabel.Position = UDim2.new(0, 0, 0.45, 0)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Font = Enum.Font.GothamBlack
	loadingLabel.TextScaled = true
	loadingLabel.Text = "Loading..."
	loadingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	
	local statusLabel = Instance.new("TextLabel", loadingOverlay)
	statusLabel.Size = UDim2.fromScale(1, 0)
	statusLabel.Position = UDim2.new(0, 0, 0.55, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextScaled = true
	statusLabel.Text = "Preparing UI"
	statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	
	local alive = true
	task.spawn(function()
		local dots = 0
		while alive and loadingLabel.Parent do
			dots = (dots % 3) + 1
			loadingLabel.Text = "Loading" .. string.rep(".", dots)
			task.wait(0.4)
		end
	end)
	
	local function setStatus(txt) statusLabel.Text = txt end
	
	setStatus("Building UI...")
	self:createUI()
	self:setupGlobalConnections()
	
	setStatus("Fetching your data...")
	local loadedData = self:loadData()
	
	if loadedData and typeof(loadedData) == "table" then
		setStatus("Applying loaded data...")
		self.playlists = loadedData.playlists or { ["Default"] = { songs = {} } }
		if loadedData.settings then
			local s = loadedData.settings
			self.settings.theme = s.theme or "Dark"
			if s.toggleKeyString and Enum.KeyCode[s.toggleKeyString] then
				self.settings.toggleKey = Enum.KeyCode[s.toggleKeyString]
			end
		end
	else
		setStatus("No saved data found.")
		self.playlists["Default"] = { songs = {} }
	end
	
	self:applyTheme(self.settings.theme)
	self.ui.kbRow.Text = "Current: " .. self.settings.toggleKey.Name
	self:rebuildPlaylistList()
	self:rebuildDropdownList()
	
	if next(self.playlists) then
		local firstName = next(self.playlists)
		self.ui.plDropdown.Text = firstName
		self.selectedPlaylistName = firstName
		self:refreshSongsGrid()
	end
	
	setStatus("Ready!")
	task.wait(0.5)
	
	TweenService:Create(loadingOverlay, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(loadingLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(statusLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(blur, TweenInfo.new(0.5), { Size = 0 }):Play()
	
	task.wait(0.5)
	
	self.ui.mainFrame.Visible = true
	loadingOverlay:Destroy()
	blur:Destroy()
	alive = false
end

local spotifyInstance = Spotify.new()
spotifyInstance:init()
