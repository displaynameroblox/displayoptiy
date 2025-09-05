-- PlaylistManager.lua
return function(deps)
    local Util = deps.Util
    local Storage = deps.Storage

    local PlaylistManager = {
        playlists = Storage.load("playlists") or {}
    }

    function PlaylistManager.create(name)
        if not PlaylistManager.playlists[name] then
            PlaylistManager.playlists[name] = {}
            PlaylistManager.save()
        end
    end

    function PlaylistManager.addTrack(playlist, assetId, title)
        if PlaylistManager.playlists[playlist] then
            table.insert(PlaylistManager.playlists[playlist], { id = assetId, title = title })
            PlaylistManager.save()
        end
    end

    function PlaylistManager.removeTrack(playlist, index)
        if PlaylistManager.playlists[playlist] and PlaylistManager.playlists[playlist][index] then
            table.remove(PlaylistManager.playlists[playlist], index)
            PlaylistManager.save()
        end
    end

    function PlaylistManager.listPlaylists()
        local names = {}
        for k in pairs(PlaylistManager.playlists) do table.insert(names, k) end
        return names
    end

    function PlaylistManager.getTracks(playlist)
        return PlaylistManager.playlists[playlist] or {}
    end

    function PlaylistManager.save()
        Storage.save("playlists", PlaylistManager.playlists)
    end

    return PlaylistManager
end
