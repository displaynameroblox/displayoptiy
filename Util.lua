--[[
Displayoptiy / Util.lua
Small, dependency-free helpers used across modules.
Safe on pure client; no server calls.
]]

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Util = {}

--//////////// General ////////////--
function Util.uuid()
	return HttpService:GenerateGUID(false)
end

function Util.now()
	return os.clock()
end

function Util.round(n, p)
	p = p or 2
	local m = 10 ^ p
	return math.floor(n * m + 0.5) / m
end

function Util.clamp(n, a, b)
	return math.max(a, math.min(b, n))
end

function Util.deepClone(t)
	if type(t) ~= "table" then return t end
	local r = {}
	for k,v in pairs(t) do r[k] = Util.deepClone(v) end
	return r
end

function Util.deepMerge(into, from)
	for k,v in pairs(from) do
		if type(v) == "table" and type(into[k]) == "table" then
			Util.deepMerge(into[k], v)
		else
			into[k] = Util.deepClone(v)
		end
	end
	return into
end

--//////////// JSON ////////////--
function Util.jsonEncode(tbl)
	return HttpService:JSONEncode(tbl)
end

function Util.jsonDecode(str)
	local ok, res = pcall(function() return HttpService:JSONDecode(str) end)
	if ok then return res end
	return nil
end

--//////////// Id Normalizers ////////////--
function Util.normalizeDecal(input)
	if not input or input == "" then return "" end
	if tostring(input):find("rbxassetid://") then return tostring(input) end
	local numeric = tostring(input):match("(%d+)")
	if numeric then return "rbxassetid://" .. numeric end
	return tostring(input)
end

function Util.normalizeSoundId(id)
	if not id or id == "" then return nil end
	local numeric = tostring(id):match("(%d+)")
	if numeric then return "rbxassetid://" .. numeric end
	return tostring(id)
end

--//////////// Clipboard (best-effort) ////////////--
function Util.copyToClipboard(text)
	if typeof(setclipboard) == "function" then
		local ok = pcall(setclipboard, text)
		return ok
	end
	return false
end

--//////////// Filesystem (exploit-friendly) ////////////--
function Util.hasFS()
	return typeof(writefile) == "function" and typeof(readfile) == "function"
end

function Util.ensureFolder(path)
	if typeof(makefolder) == "function" then pcall(makefolder, path) end
end

--//////////// Tween helpers ////////////--
function Util.tween(inst, duration, props, style, dir)
	local info = TweenInfo.new(duration or 0.25, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

--//////////// Time formatting ////////////--
function Util.formatTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	local m = math.floor(sec/60)
	local s = sec % 60
	return string.format("%d:%02d", m, s)
end

--//////////// Simple Signal ////////////--
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _b = {} }, Signal)
end

function Signal:Connect(fn)
	local c = { fn = fn, d = false }
	table.insert(self._b, c)
	return {
		Disconnect = function()
			c.d = true
		end
	}
end

function Signal:Fire(...)
	for _,c in ipairs(self._b) do if not c.d then c.fn(...) end end
end

Util.Signal = Signal

--//////////// Debounce/Throttle ////////////--
function Util.debounce(wait, fn)
	local t = 0
	return function(...)
		local now = os.clock()
		if now - t >= wait then
			t = now
			return fn(...)
		end
	end
end

function Util.throttle(wait, fn)
	local last = 0
	local queued = false
	local args
	return function(...)
		args = {...}
		local now = os.clock()
		if now - last >= wait then
			last = now
			queued = false
			return fn(table.unpack(args))
		elseif not queued then
			queued = true
			task.delay(wait - (now - last), function()
				last = os.clock()
				queued = false
				fn(table.unpack(args))
			end)
		end
	end
end

--//////////// UI helpers ////////////--
function Util.clickOutsideToClose(panel, toggleBtn)
	local UIS = game:GetService("UserInputService")
	local function inside(gui, pos)
		return pos.X >= gui.AbsolutePosition.X and pos.X <= gui.AbsolutePosition.X + gui.AbsoluteSize.X and
			   pos.Y >= gui.AbsolutePosition.Y and pos.Y <= gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
	end
	return UIS.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not panel.Visible then return end
		local m = UIS:GetMouseLocation()
		if toggleBtn and inside(toggleBtn, m) then return end
		if not inside(panel, m) then panel.Visible = false end
	end)
end

return Util
