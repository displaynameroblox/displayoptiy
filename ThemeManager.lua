-- ThemeManager.lua
return function(deps)
    local Util = deps.Util
    local Storage = deps.Storage

    local ThemeManager = {
        themes = {
            Dark = { bg = Color3.fromRGB(30, 30, 30), text = Color3.fromRGB(255, 255, 255) },
            Light = { bg = Color3.fromRGB(245, 245, 245), text = Color3.fromRGB(0, 0, 0) },
            Neon = { bg = Color3.fromRGB(0, 255, 150), text = Color3.fromRGB(0, 0, 0) }
        },
        current = "Dark"
    }

    local Signal = Instance.new("BindableEvent")
    ThemeManager.OnThemeChanged = Signal.Event

    function ThemeManager.setTheme(name)
        if ThemeManager.themes[name] then
            ThemeManager.current = name
            Storage.save("theme", name)
            Signal:Fire(ThemeManager.themes[name])
        end
    end

    function ThemeManager.getTheme()
        return ThemeManager.themes[ThemeManager.current]
    end

    -- restore last theme if available
    local saved = Storage.load("theme")
    if saved and ThemeManager.themes[saved] then
        ThemeManager.current = saved
    end

    return ThemeManager
end
