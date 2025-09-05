-- UIManager.lua
return function(deps)
    local Util = deps.Util
    local ThemeManager = deps.ThemeManager

    local UIManager = {}
    local screenGui, buttons = nil, {}

    function UIManager.init()
        if screenGui then screenGui:Destroy() end
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "DisplayoptiyUI"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

        -- Play Button
        local play = Instance.new("TextButton")
        play.Size = UDim2.new(0, 100, 0, 50)
        play.Position = UDim2.new(0, 10, 0, 10)
        play.Text = "Play"
        play.Parent = screenGui
        buttons.Play = play

        -- Pause Button
        local pause = Instance.new("TextButton")
        pause.Size = UDim2.new(0, 100, 0, 50)
        pause.Position = UDim2.new(0, 120, 0, 10)
        pause.Text = "Pause"
        pause.Parent = screenGui
        buttons.Pause = pause

        -- etc: Next, Prev, Add Playlist
        local nextBtn = Instance.new("TextButton")
        nextBtn.Size = UDim2.new(0, 100, 0, 50)
        nextBtn.Position = UDim2.new(0, 230, 0, 10)
        nextBtn.Text = "Next"
        nextBtn.Parent = screenGui
        buttons.Next = nextBtn

        local prevBtn = Instance.new("TextButton")
        prevBtn.Size = UDim2.new(0, 100, 0, 50)
        prevBtn.Position = UDim2.new(0, 340, 0, 10)
        prevBtn.Text = "Prev"
        prevBtn.Parent = screenGui
        buttons.Prev = prevBtn

        local playlistBox = Instance.new("TextBox")
        playlistBox.Size = UDim2.new(0, 200, 0, 30)
        playlistBox.Position = UDim2.new(0, 10, 0, 70)
        playlistBox.PlaceholderText = "Playlist name"
        playlistBox.Parent = screenGui
        buttons.PlaylistBox = playlistBox

        local addBtn = Instance.new("TextButton")
        addBtn.Size = UDim2.new(0, 100, 0, 30)
        addBtn.Position = UDim2.new(0, 220, 0, 70)
        addBtn.Text = "Add Playlist"
        addBtn.Parent = screenGui
        buttons.AddPlaylist = addBtn

        UIManager.applyTheme()
    end

    function UIManager.applyTheme()
        if not screenGui then return end
        local theme = ThemeManager.getTheme()
        for _, child in ipairs(screenGui:GetDescendants()) do
            if child:IsA("TextButton") or child:IsA("TextBox") then
                child.BackgroundColor3 = theme.bg
                child.TextColor3 = theme.text
            end
        end
    end

    function UIManager.getElements()
        return buttons
    end

    ThemeManager.OnThemeChanged:Connect(function()
        UIManager.applyTheme()
    end)

    return UIManager
end
