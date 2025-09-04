--[[
Displayoptiy / ThemeManager.lua
Handles themes and styling for the UI.
Provides defaults and allows switching.
]]

local Util = require(script.Parent.Util)

local ThemeManager = {}

-- Default themes
ThemeManager.Themes = {
    Dark = {
        Background = Color3.fromRGB(20, 20, 20),
        Foreground = Color3.fromRGB(240, 240, 240),
        Accent = Color3.fromRGB(0, 170, 255),
        Secondary = Color3.fromRGB(60, 60, 60),
    },
    Light = {
        Background = Color3.fromRGB(245, 245, 245),
        Foreground = Color3.fromRGB(30, 30, 30),
        Accent = Color3.fromRGB(0, 120, 215),
        Secondary = Color3.fromRGB(220, 220, 220),
    },
    Neon = {
        Background = Color3.fromRGB(10, 10, 20),
        Foreground = Color3.fromRGB(255, 255, 255),
        Accent = Color3.fromRGB(255, 0, 200),
        Secondary = Color3.fromRGB(30, 30, 60),
    }
}

-- Current theme
ThemeManager.Current = Util.deepClone(ThemeManager.Themes.Dark)
ThemeManager.Name = "Dark"

-- Signal for theme changes
ThemeManager.OnThemeChanged = Util.Signal.new()

--//////////// API ////////////--
function ThemeManager.setTheme(name)
    local theme = ThemeManager.Themes[name]
    if theme then
        ThemeManager.Current = Util.deepClone(theme)
        ThemeManager.Name = name
        ThemeManager.OnThemeChanged:Fire(theme)
    end
end

function ThemeManager.getTheme()
    return ThemeManager.Current
end

function ThemeManager.listThemes()
    local keys = {}
    for k,_ in pairs(ThemeManager.Themes) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

function ThemeManager.registerTheme(name, def)
    ThemeManager.Themes[name] = Util.deepClone(def)
end

return ThemeManager
