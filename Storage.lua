-- Storage.lua (dependency-injected)

return function(deps)
    local Util = deps.Util

    local Storage = {}
    local data = {} -- in-memory fallback

    -- helper to safely load from file if exploit API exists
    local function loadFromFile(name)
        if isfile and isfile(name) then
            local ok, decoded = pcall(function()
                return game:GetService("HttpService"):JSONDecode(readfile(name))
            end)
            if ok and decoded then
                return decoded
            end
        end
        return nil
    end

    local function saveToFile(name, tbl)
        if writefile then
            local ok, encoded = pcall(function()
                return game:GetService("HttpService"):JSONEncode(tbl)
            end)
            if ok then
                writefile(name, encoded)
            end
        end
    end

    -- public API
    function Storage.save(key, value)
        data[key] = value
        saveToFile(key .. ".json", value)
    end

    function Storage.load(key)
        if data[key] then
            return data[key]
        end
        local fromFile = loadFromFile(key .. ".json")
        if fromFile then
            data[key] = fromFile
            return fromFile
        end
        return nil
    end

    function Storage.delete(key)
        data[key] = nil
        if delfile then
            local ok = pcall(function()
                delfile(key .. ".json")
            end)
            if not ok then
                warn("Could not delete file for " .. key)
            end
        end
    end

    return Storage
end
