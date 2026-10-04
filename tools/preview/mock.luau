--!nocheck
-- A tiny fake Roblox engine, just enough to run the builders outside Studio and dump every
-- part they create. Used by tools/preview/render.py to draw preview images.
--
-- tools/preview/render.py bundles this with the builder sources and runs it with luau.

-- Vector3 -----------------------------------------------------------------------------------
local warn = function(...) print("[warn]", ...) end
local V3 = {}
V3.__index = function(v, k)
	if k == "X" then
		return rawget(v, 1)
	elseif k == "Y" then
		return rawget(v, 2)
	elseif k == "Z" then
		return rawget(v, 3)
	elseif k == "Magnitude" then
		return math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	elseif k == "Unit" then
		local m = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
		return V3.new(v[1] / m, v[2] / m, v[3] / m)
	end
	return V3[k]
end
function V3.new(x, y, z)
	return setmetatable({ x or 0, y or 0, z or 0 }, V3)
end
V3.__add = function(a, b)
	return V3.new(a[1] + b[1], a[2] + b[2], a[3] + b[3])
end
V3.__sub = function(a, b)
	return V3.new(a[1] - b[1], a[2] - b[2], a[3] - b[3])
end
V3.__unm = function(a)
	return V3.new(-a[1], -a[2], -a[3])
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return V3.new(a * b[1], a * b[2], a * b[3])
	elseif type(b) == "number" then
		return V3.new(a[1] * b, a[2] * b, a[3] * b)
	end
	return V3.new(a[1] * b[1], a[2] * b[2], a[3] * b[3])
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return V3.new(a[1] / b, a[2] / b, a[3] / b)
	end
	return V3.new(a[1] / b[1], a[2] / b[2], a[3] / b[3])
end
function V3.Cross(a, b)
	return V3.new(a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])
end
function V3.Dot(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local Vector3 = {
	new = V3.new,
	one = V3.new(1, 1, 1),
	zero = V3.new(0, 0, 0),
	xAxis = V3.new(1, 0, 0),
	yAxis = V3.new(0, 1, 0),
	zAxis = V3.new(0, 0, 1),
}

-- CFrame: rotation matrix r (row-major 3x3) + position p --------------------------------------
local CF = {}
local function mat_mul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end
local function mat_vec(a, v)
	return V3.new(
		a[1] * v[1] + a[2] * v[2] + a[3] * v[3],
		a[4] * v[1] + a[5] * v[2] + a[6] * v[3],
		a[7] * v[1] + a[8] * v[2] + a[9] * v[3]
	)
end
local function mkcf(r, p)
	return setmetatable({ r = r, p = p }, CF)
end
CF.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "Rotation" then
		return mkcf(c.r, V3.new(0, 0, 0))
	elseif k == "LookVector" then
		return V3.new(-c.r[3], -c.r[6], -c.r[9])
	elseif k == "X" then
		return c.p[1]
	elseif k == "Y" then
		return c.p[2]
	elseif k == "Z" then
		return c.p[3]
	end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return a.p + mat_vec(a.r, b)
	end
	return mkcf(mat_mul(a.r, b.r), a.p + mat_vec(a.r, b.p))
end
function CF.Inverse(c)
	local r = c.r
	local rt = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	return mkcf(rt, -mat_vec(rt, c.p))
end
CF.__add = function(a, v)
	return mkcf(a.r, a.p + v)
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function rx(t)
	local c, s = math.cos(t), math.sin(t)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
local CFrame = {}
function CFrame.new(x, y, z)
	if x == nil then
		return mkcf(IDENT, V3.new(0, 0, 0))
	elseif type(x) == "table" then
		return mkcf(IDENT, x)
	end
	return mkcf(IDENT, V3.new(x, y, z))
end
function CFrame.Angles(a, b, c)
	return mkcf(mat_mul(mat_mul(rx(a), ry(b)), rz(c)), V3.new(0, 0, 0))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy)
	return mkcf({ vx[1], vy[1], vz[1], vx[2], vy[2], vz[2], vx[3], vy[3], vz[3] }, pos)
end
function CFrame.lookAt(at, target, up)
	up = up or V3.new(0, 1, 0)
	local look = (target - at).Unit
	local right = V3.Cross(look, up).Unit
	local up2 = V3.Cross(right, look)
	return mkcf({ right[1], up2[1], -look[1], right[2], up2[2], -look[2], right[3], up2[3], -look[3] }, at)
end

-- Color3 ------------------------------------------------------------------------------------
local C3 = {}
C3.__index = C3
local function color(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3)
end
local Color3 = {
	new = function(r, g, b)
		return color(r or 0, g or 0, b or 0)
	end,
	fromRGB = function(r, g, b)
		return color(r / 255, g / 255, b / 255)
	end,
}
function C3:Lerp(o, t)
	return color(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t)
end
function C3:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, if mx == 0 then 0 else d / mx, mx
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local m = i % 6
	if m == 0 then
		return color(v, t, p)
	elseif m == 1 then
		return color(q, v, p)
	elseif m == 2 then
		return color(p, v, t)
	elseif m == 3 then
		return color(p, q, v)
	elseif m == 4 then
		return color(t, p, v)
	end
	return color(v, p, q)
end

-- Misc datatypes ------------------------------------------------------------------------------
local function anyCtor()
	return setmetatable({}, { __index = function()
		return function(...)
			return { ... }
		end
	end })
end
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return { EnumType = enumName, Name = item }
			end,
		})
	end,
})
local RandomMT = {}
RandomMT.__index = RandomMT
local Random = {
	new = function(seed)
		return setmetatable({ s = (seed or 1) % 2147483647 }, RandomMT)
	end,
}
function RandomMT:next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function RandomMT:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:next()
end
function RandomMT:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:next())
end

-- Instances -----------------------------------------------------------------------------------
local all = {}
local Inst = {}
local PART_CLASSES = { Part = true, WedgePart = true, CornerWedgePart = true, SpawnLocation = true, MeshPart = true }
Inst.__index = function(self, k)
	local v = rawget(self, "_props")[k]
	if v ~= nil then
		return v
	end
	if k == "Position" and PART_CLASSES[rawget(self, "_props").ClassName] and rawget(self, "_props").CFrame then
		return rawget(self, "_props").CFrame.p
	end
	if Inst[k] then
		return Inst[k]
	end
	return rawget(self, "_children_by_name")[k]
end
Inst.__newindex = function(self, k, v)
	local props = rawget(self, "_props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local list = rawget(old, "_children")
			for i, c in list do
				if c == self then
					table.remove(list, i)
					break
				end
			end
			rawget(old, "_children_by_name")[props.Name] = nil
		end
		props.Parent = v
		if v then
			table.insert(rawget(v, "_children"), self)
			rawget(v, "_children_by_name")[props.Name] = self
		end
	elseif k == "Position" and PART_CLASSES[props.ClassName] then
		local cf = props.CFrame or CFrame.new()
		props.CFrame = mkcf(cf.r, v)
	elseif k == "Name" then
		local parent = props.Parent
		if parent then
			rawget(parent, "_children_by_name")[props.Name] = nil
			rawget(parent, "_children_by_name")[v] = self
		end
		props.Name = v
	else
		props[k] = v
	end
end
function Inst:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Inst:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in rawget(n, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst:FindFirstChild(name)
	return rawget(self, "_children_by_name")[name]
end
function Inst:WaitForChild(name)
	return rawget(self, "_children_by_name")[name]
end
function Inst:FindFirstChildOfClass(cls)
	for _, c in rawget(self, "_children") do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end
function Inst:IsA(cls)
	local c = self.ClassName
	if cls == "BasePart" then
		return PART_CLASSES[c] == true
	end
	return c == cls
end
function Inst:Destroy()
	self.Parent = nil
end
function Inst:SetAttribute(k, v)
	rawget(self, "_attrs")[k] = v
end
function Inst:GetAttribute(k)
	return rawget(self, "_attrs")[k]
end
function Inst:AddTag(t)
	rawget(self, "_attrs")["Tag_" .. t] = true
end
function Inst:Clone()
	local props = rawget(self, "_props")
	local o = Instance.new(props.ClassName)
	local oprops = rawget(o, "_props")
	for k, v in props do
		if k ~= "Parent" then
			oprops[k] = v
		end
	end
	for k, v in rawget(self, "_attrs") do
		rawget(o, "_attrs")[k] = v
	end
	for _, c in rawget(self, "_children") do
		c:Clone().Parent = o
	end
	return o
end
function Inst:ClearAllChildren()
	for _, c in self:GetChildren() do
		c.Parent = nil
	end
end

local Instance = {}
function Instance.new(cls, parent)
	local o = setmetatable({ _props = { ClassName = cls, Name = cls }, _children = {}, _children_by_name = {}, _attrs = {} }, Inst)
	if PART_CLASSES[cls] then
		o._props.Size = V3.new(4, 1, 2)
		o._props.CFrame = CFrame.new()
		o._props.Color = Color3.fromRGB(163, 162, 165)
		o._props.Transparency = 0
		o._props.Shape = Enum.PartType.Block
	end
	if parent then
		o.Parent = parent
	end
	table.insert(all, o)
	return o
end

-- game / script / require ----------------------------------------------------------------------
local ROOT = "."
local function moduleInst(name, path)
	local m = Instance.new("ModuleScript")
	m.Name = name
	rawset(m, "_path", path)
	return m
end
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	if parent then
		f.Parent = parent
	end
	return f
end

local services = {}
local function service(name)
	if not services[name] then
		services[name] = Instance.new(name)
		services[name].Name = name
	end
	return services[name]
end
local game = { GetService = function(_, name)
	return service(name)
end }
local RunService = service("RunService")
rawget(RunService, "_props").IsStudio = function()
	return true
end
local workspace = service("Workspace")

local shared = folder("Shared", service("ReplicatedStorage"))
for _, n in { "Config", "Layout", "AssetIds", "UiSprites", "Cosmetics" } do
	moduleInst(n, ROOT .. "/src/shared/" .. n .. ".luau").Parent = shared
end
local builders = folder("Builders", service("ReplicatedStorage"))
for _, n in { "Build", "Palette", "Props", "WorldBuilder", "CarBuilder", "LightingBuilder", "ChickenBuilder", "Meshes", "MeshManifest" } do
	moduleInst(n, ROOT .. "/src/builders/" .. n .. ".luau").Parent = builders
end

local cache = {}
local __modules = {}
local function mockRequire(m)
	if cache[m] then
		return cache[m]
	end
	local fn = __modules[rawget(m, "_path")]
	if not fn then
		error("unknown module " .. tostring(rawget(m, "_path")))
	end
	local result = fn(m, mockRequire)
	cache[m] = result
	return result
end

-- UI datatypes (real enough for layout previews) ---------------------------------------------
local Vector2 = { new = function(x, y)
	return { kind = "Vector2", X = x or 0, Y = y or 0 }
end }
local UDimMT = {}
local UDim = { new = function(s, o)
	return setmetatable({ kind = "UDim", Scale = s or 0, Offset = o or 0 }, UDimMT)
end }
local UDim2MT = {}
local function udim2(sx, ox, sy, oy)
	return setmetatable({ kind = "UDim2", X = UDim.new(sx, ox), Y = UDim.new(sy, oy) }, UDim2MT)
end
UDim2MT.__add = function(a, b)
	return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
local UDim2 = {
	new = function(sx, ox, sy, oy)
		return udim2(sx or 0, ox or 0, sy or 0, oy or 0)
	end,
	fromScale = function(x, y)
		return udim2(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return udim2(0, x, 0, y)
	end,
}
local ColorSequenceKeypoint = { new = function(t, c)
	return { Time = t, Value = c }
end }
local ColorSequence = { new = function(a, b)
	if type(a) == "table" and a.R == nil then
		return { kind = "ColorSequence", Keypoints = a }
	end
	return { kind = "ColorSequence", Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } }
end }
local NumberSequenceKeypoint = { new = function(t, v)
	return { Time = t, Value = v }
end }
local NumberSequence = { new = function(a, b)
	if type(a) == "table" then
		return { kind = "NumberSequence", Keypoints = a }
	end
	return { kind = "NumberSequence", Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } }
end }
local NumberRange = { new = function(a, b)
	return { Min = a, Max = b or a }
end }

-- Deep clone for GUI templates.
function Inst:Clone()
	local copy = Instance.new(self.ClassName)
	for k, v in rawget(self, "_props") do
		if k ~= "Parent" then
			rawget(copy, "_props")[k] = v
		end
	end
	for k, v in rawget(self, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	for _, child in rawget(self, "_children") do
		child:Clone().Parent = copy
	end
	return copy
end

local Rect = { new = function(a, b, c, d)
	return { kind = "Rect", Min = Vector2.new(a, b), Max = Vector2.new(c, d) }
end }

-- JSON dump of an instance tree.
local function jsonValue(v)
	local t = type(v)
	if t == "number" then
		return if v ~= v then "0" else string.format("%.5g", v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		local escaped = v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
		return '"' .. escaped .. '"'
	elseif t == "table" then
		if getmetatable(v) == C3 then
			return string.format('{"c3":[%.4f,%.4f,%.4f]}', v.R, v.G, v.B)
		elseif v.EnumType then
			return string.format("%q", v.Name)
		elseif v.kind == "UDim2" then
			return string.format('{"udim2":[%.5g,%.5g,%.5g,%.5g]}', v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
		elseif v.kind == "UDim" then
			return string.format('{"udim":[%.5g,%.5g]}', v.Scale, v.Offset)
		elseif v.kind == "Rect" then
			return string.format('{"rect":[%.5g,%.5g,%.5g,%.5g]}', v.Min.X, v.Min.Y, v.Max.X, v.Max.Y)
		elseif v.kind == "Vector2" then
			return string.format('{"v2":[%.5g,%.5g]}', v.X, v.Y)
		elseif v.kind == "ColorSequence" then
			local parts = {}
			for _, k in v.Keypoints do
				table.insert(parts, string.format("[%.4f,%.4f,%.4f,%.4f]", k.Time, k.Value.R, k.Value.G, k.Value.B))
			end
			return '{"cseq":[' .. table.concat(parts, ",") .. "]}"
		elseif v.kind == "NumberSequence" then
			local parts = {}
			for _, k in v.Keypoints do
				table.insert(parts, string.format("[%.4f,%.4f]", k.Time, k.Value))
			end
			return '{"nseq":[' .. table.concat(parts, ",") .. "]}"
		end
	end
	return "null"
end
local function dumpTree(node)
	local props = {}
	for k, v in rawget(node, "_props") do
		if k ~= "Parent" and type(v) ~= "function" then
			local js = jsonValue(v)
			if js ~= "null" then
				table.insert(props, string.format("%q:%s", k, js))
			end
		end
	end
	local attrs = {}
	for k, v in rawget(node, "_attrs") do
		local js = jsonValue(v)
		if js ~= "null" then
			table.insert(attrs, string.format("%q:%s", k, js))
		end
	end
	local kids = {}
	for _, c in rawget(node, "_children") do
		table.insert(kids, dumpTree(c))
	end
	return string.format('{"props":{%s},"attrs":{%s},"children":[%s]}', table.concat(props, ","), table.concat(attrs, ","), table.concat(kids, ","))
end
