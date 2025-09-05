-- Util.lua (standalone, no dependencies)
return function()
    local Util = {}

    function Util.deepcopy(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for k, v in next, orig, nil do
                copy[Util.deepcopy(k)] = Util.deepcopy(v)
            end
            setmetatable(copy, Util.deepcopy(getmetatable(orig)))
        else
            copy = orig
        end
        return copy
    end

    function Util.tableFind(tbl, val)
        for i, v in ipairs(tbl) do
            if v == val then
                return i
            end
        end
        return nil
    end

    return Util
end
