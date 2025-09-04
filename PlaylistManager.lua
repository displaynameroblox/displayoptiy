--[[
Displayoptiy / PlaylistManager.lua
Manages playlists: add, remove, reorder, search.
Integrates with Storage for persistence.
]]

local Util = require(script.Parent.Util)
local Storage = require(script.Parent.Storage)

local PlaylistManager = {}

-- Playlist structure:
-- playlists = {
--   { name = "My Playlist", tracks = { {id="rbxassetid://...", title="..."}, ... } }
-- }

PlaylistManager.playlists = Storage.loadPlaylists()

--//////////// Helpers ////////////--
local function findPlaylist(name)
    for i,p in ipairs(PlaylistManager.playlists) do
        if p.name == name then return p, i end
    end
    return nil, nil
end

--//////////// API ////////////--
function PlaylistManager.create(name)
    if findPlaylist(name) then return false end
    table.insert(PlaylistManager.playlists, { name = name, tracks = {} })
    Storage.savePlaylists(PlaylistManager.playlists)
    return true
end

function PlaylistManager.delete(name)
    local _, idx = findPlaylist(name)
    if idx then
        table.remove(PlaylistManager.playlists, idx)
        Storage.savePlaylists(PlaylistManager.playlists)
        return true
    end
    return false
end

function PlaylistManager.rename(oldName, newName)
    local pl = findPlaylist(oldName)
    if pl and not findPlaylist(newName) then
        pl.name = newName
        Storage.savePlaylists(PlaylistManager.playlists)
        return true
    end
    return false
end

function PlaylistManager.addTrack(playlistName, trackId, title)
    local pl = findPlaylist(playlistName)
    if not pl then return false end
    table.insert(pl.tracks, { id = Util.normalizeSoundId(trackId), title = title or ("Track " .. #pl.tracks+1) })
    Storage.savePlaylists(PlaylistManager.playlists)
    return true
end

function PlaylistManager.removeTrack(playlistName, idx)
    local pl = findPlaylist(playlistName)
    if not pl or not pl.tracks[idx] then return false end
    table.remove(pl.tracks, idx)
    Storage.savePlaylists(PlaylistManager.playlists)
    return true
end

function PlaylistManager.moveTrack(playlistName, fromIdx, toIdx)
    local pl = findPlaylist(playlistName)
    if not pl then return false end
    local track = pl.tracks[fromIdx]
    if not track then return false end
    table.remove(pl.tracks, fromIdx)
    table.insert(pl.tracks, toIdx, track)
    Storage.savePlaylists(PlaylistManager.playlists)
    return true
end

function PlaylistManager.list(playlistName)
    local pl = findPlaylist(playlistName)
    if not pl then return {} end
    return Util.deepClone(pl.tracks)
end

function PlaylistManager.search(playlistName, query)
    local pl = findPlaylist(playlistName)
    if not pl then return {} end
    local results = {}
    query = string.lower(query)
    for _,t in ipairs(pl.tracks) do
        if string.find(string.lower(t.title), query, 1, true) then
            table.insert(results, t)
        end
    end
    return results
end

function PlaylistManager.listPlaylists()
    local names = {}
    for _,p in ipairs(PlaylistManager.playlists) do
        table.insert(names, p.name)
    end
    return names
end

return PlaylistManager
