--!strict
--[=[
	--> ["Kite : Tests : Stub"]

	A Roblox, small enough to fit in a file and strict enough to catch
	real mistakes.

	It is not trying to be Roblox. It is trying to answer the question
	"does Kite behave correctly" outside of Studio, in CI, on a Tuesday.

		Instance        real properties, real parent links, real ordering
		Instance:IsA    a real class hierarchy
		events          return RBXScriptSignal shaped things
		value types     UDim2, UDim, Vector2, Color3, ColorSequence, Font
		RunService      one connection list you step by hand
		CollectionService  tags, counted

	`Stub.frame(dt)` steps every connected frame callback. That is how the
	spring tests settle a spring without waiting on a real clock.
]=]

local Stub = {}

--> ["value types"]
-- Minimal implementations of the Roblox value types Kite touches.

local function numberType(name, fields)
	local meta = {} :: { [string]: any }
	meta.__type = name
	meta.__index = meta

	function meta.__tostring(self: any)
		local parts = {}
		for _, field in fields do
			table.insert(parts, tostring(self[field]))
		end
		return `{name}({table.concat(parts, ", ")})`
	end

	return meta
end

local function construct(meta, values)
	return setmetatable(values, meta)
end

-- UDim
local UDimMeta = numberType("UDim", { "Scale", "Offset" })
UDimMeta.new = function(scale: number, offset: number)
	return construct(UDimMeta, { Scale = scale, Offset = offset })
end
UDimMeta.Lerp = function(self: any, other: any, alpha: number)
	return UDimMeta.new(
		self.Scale + (other.Scale - self.Scale) * alpha,
		self.Offset + (other.Offset - self.Offset) * alpha
	)
end
UDimMeta.__eq = function(left: any, right: any)
	return left.Scale == right.Scale and left.Offset == right.Offset
end
UDimMeta.__add = function(left: any, right: any)
	return UDimMeta.new(left.Scale + right.Scale, left.Offset + right.Offset)
end
UDimMeta.__sub = function(left: any, right: any)
	return UDimMeta.new(left.Scale - right.Scale, left.Offset - right.Offset)
end

-- UDim2
local UDim2Meta = numberType("UDim2", { "X", "Y" })
UDim2Meta.new = function(xScale: number, xOffset: number, yScale: number, yOffset: number)
	return construct(UDim2Meta, {
		X = UDimMeta.new(xScale, xOffset),
		Y = UDimMeta.new(yScale, yOffset),
	})
end
UDim2Meta.fromScale = function(x: number, y: number)
	return UDim2Meta.new(x, 0, y, 0)
end
UDim2Meta.fromOffset = function(x: number, y: number)
	return UDim2Meta.new(0, x, 0, y)
end
UDim2Meta.Lerp = function(self: any, other: any, alpha: number)
	return UDim2Meta.new(
		self.X.Scale + (other.X.Scale - self.X.Scale) * alpha,
		self.X.Offset + (other.X.Offset - self.X.Offset) * alpha,
		self.Y.Scale + (other.Y.Scale - self.Y.Scale) * alpha,
		self.Y.Offset + (other.Y.Offset - self.Y.Offset) * alpha
	)
end

-- Vector2
local Vector2Meta = numberType("Vector2", { "X", "Y" })
Vector2Meta.new = function(x: number, y: number)
	return construct(Vector2Meta, { X = x, Y = y })
end
Vector2Meta.zero = Vector2Meta.new(0, 0)
Vector2Meta.Lerp = function(self: any, other: any, alpha: number)
	return Vector2Meta.new(self.X + (other.X - self.X) * alpha, self.Y + (other.Y - self.Y) * alpha)
end
Vector2Meta.__sub = function(left: any, right: any)
	return Vector2Meta.new(left.X - right.X, left.Y - right.Y)
end
Vector2Meta.__add = function(left: any, right: any)
	return Vector2Meta.new(left.X + right.X, left.Y + right.Y)
end
Vector2Meta.__index = function(self: any, key: string)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	end
	if key == "Unit" then
		local length = math.sqrt(self.X * self.X + self.Y * self.Y)
		if length == 0 then
			return Vector2Meta.new(0, 0)
		end
		return Vector2Meta.new(self.X / length, self.Y / length)
	end
	return Vector2Meta[key]
end

-- Vector3
local Vector3Meta = numberType("Vector3", { "X", "Y", "Z" })
Vector3Meta.new = function(x: number?, y: number?, z: number?)
	return construct(Vector3Meta, { X = x or 0, Y = y or 0, Z = z or 0 })
end
Vector3Meta.zero = Vector3Meta.new(0, 0, 0)
Vector3Meta.__sub = function(left: any, right: any)
	return Vector3Meta.new(left.X - right.X, left.Y - right.Y, left.Z - right.Z)
end
Vector3Meta.__index = function(self: any, key: string)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	end
	return Vector3Meta[key]
end

-- Color3
local Color3Meta = numberType("Color3", { "R", "G", "B" })
Color3Meta.new = function(r: number, g: number, b: number)
	return construct(Color3Meta, { R = r, G = g, B = b })
end
Color3Meta.fromRGB = function(r: number, g: number, b: number)
	return Color3Meta.new(r / 255, g / 255, b / 255)
end
Color3Meta.fromHex = function(hex: string)
	if string.sub(hex, 1, 1) == "#" then
		hex = string.sub(hex, 2)
	end
	if #hex == 3 then
		hex = string.rep(string.sub(hex, 1, 1), 2)
			.. string.rep(string.sub(hex, 2, 2), 2)
			.. string.rep(string.sub(hex, 3, 3), 2)
	end
	return Color3Meta.fromRGB(tonumber(string.sub(hex, 1, 2), 16) or 0, tonumber(string.sub(hex, 3, 4), 16) or 0, tonumber(string.sub(hex, 5, 6), 16) or 0)
end
Color3Meta.Lerp = function(self: any, other: any, alpha: number)
	return Color3Meta.new(
		self.R + (other.R - self.R) * alpha,
		self.G + (other.G - self.G) * alpha,
		self.B + (other.B - self.B) * alpha
	)
end
Color3Meta.__eq = function(left: any, right: any)
	return left.R == right.R and left.G == right.G and left.B == right.B
end

-- CFrame
local CFrameMeta = numberType("CFrame", { "X", "Y", "Z" })
CFrameMeta.new = function(x: number?, y: number?, z: number?)
	return construct(CFrameMeta, { X = x or 0, Y = y or 0, Z = z or 0 })
end
CFrameMeta.Lerp = function(self: any, other: any, alpha: number)
	return CFrameMeta.new(
		self.X + (other.X - self.X) * alpha,
		self.Y + (other.Y - self.Y) * alpha,
		self.Z + (other.Z - self.Z) * alpha
	)
end

-- Rect
local RectMeta = numberType("Rect", { "Min", "Max" })
RectMeta.new = function(minX: number, minY: number, maxX: number, maxY: number)
	return construct(RectMeta, {
		Min = Vector2Meta.new(minX, minY),
		Max = Vector2Meta.new(maxX, maxY),
	})
end

-- ColorSequence
local KeypointMeta = numberType("ColorSequenceKeypoint", { "Time", "Value" })
KeypointMeta.new = function(time: number, value: any)
	return construct(KeypointMeta, { Time = time, Value = value })
end

local ColorSequenceMeta = numberType("ColorSequence", { "Keypoints" })
ColorSequenceMeta.new = function(points: any)
	return construct(ColorSequenceMeta, { Keypoints = points })
end

local NumberKeypointMeta = numberType("NumberSequenceKeypoint", { "Time", "Value" })
NumberKeypointMeta.new = function(time: number, value: number)
	return construct(NumberKeypointMeta, { Time = time, Value = value })
end

local NumberSequenceMeta = numberType("NumberSequence", { "Keypoints" })
NumberSequenceMeta.new = function(points: any)
	return construct(NumberSequenceMeta, { Keypoints = points })
end

-- Font
local FontMeta = numberType("Font", { "Family", "Weight", "Style" })
FontMeta.new = function(family: string, weight: any, style: any)
	return construct(FontMeta, { Family = family, Weight = weight, Style = style })
end
FontMeta.fromName = function(name: string, weight: any, style: any)
	return FontMeta.new(name, weight, style)
end
FontMeta.fromEnum = function(value: any)
	return FontMeta.new(tostring((value :: any).Name), (value :: any).Name, "Normal")
end

UDim = UDimMeta :: any
UDim2 = UDim2Meta :: any
Vector2 = Vector2Meta :: any
Vector3 = Vector3Meta :: any
Color3 = Color3Meta :: any
CFrame = CFrameMeta :: any
Rect = RectMeta :: any
ColorSequence = ColorSequenceMeta :: any
ColorSequenceKeypoint = KeypointMeta :: any
NumberSequence = NumberSequenceMeta :: any
NumberSequenceKeypoint = NumberKeypointMeta :: any
Font = FontMeta :: any

Stub.UDim = UDimMeta
Stub.UDim2 = UDim2Meta
Stub.Vector2 = Vector2Meta
Stub.Vector3 = Vector3Meta
Stub.Color3 = Color3Meta

--> ["Enum"]

local function enumGroup(name: string, items: { string })
	local group = { Name = name }
	local map = {}

	for index, item in items do
		map[item] = setmetatable({
			Name = item,
			Value = index - 1,
			EnumType = group,
		}, {
			__type = "EnumItem",
			__tostring = function(self: any)
				return `Enum.{name}.{self.Name}`
			end,
			__eq = function(left: any, right: any)
				return left.Name == right.Name and left.EnumType == right.EnumType
			end,
		})
	end

	function group.GetEnumItems()
		local out = {}
		for _, item in items do
			table.insert(out, map[item])
		end
		return out
	end

	return setmetatable(group, {
		__type = "Enum",
		__index = function(_self: any, key: string)
			if key == "GetEnumItems" then
				return group.GetEnumItems
			end
			if key == "Name" then
				return name
			end

			local hit = map[key]

			if hit == nil then
				-- Enum.TextXAlignment.Left also arrives as `Left`
				for item, value in map do
					if string.lower(item) == string.lower(key) then
						return value
					end
				end
			end

			return hit
		end,
		__tostring = function()
			return `Enum.{name}`
		end,
	})
end

local groups = {
	TextXAlignment = { "Left", "Center", "Right" },
	TextYAlignment = { "Top", "Center", "Bottom" },
	TextTruncate = { "None", "AtEnd", "SplitWord" },
	SortOrder = { "Name", "LayoutOrder", "Custom" },
	FillDirection = { "Horizontal", "Vertical" },
	HorizontalAlignment = { "Left", "Center", "Right" },
	VerticalAlignment = { "Top", "Center", "Bottom" },
	AutomaticSize = { "None", "X", "Y", "XY" },
	FontWeight = { "Regular", "Medium", "SemiBold", "Bold", "Light", "ExtraBold", "Thin", "Heavy" },
	FontStyle = { "Normal", "Italic" },
	ZIndexBehavior = { "Global", "Sibling" },
	SizeConstraint = { "RelativeXY", "RelativeXX", "RelativeYY" },
	ScaleType = { "Stretch", "Slice", "Tile", "Fit", "Crop" },
	FrameStyle = { "Custom", "ChatBlue", "ChatGreen", "ChatRed", "DropShadow", "RobloxRound" },
	ButtonStyle = { "Custom", "RobloxButton", "RobloxButtonDefault", "RobloxRoundButton", "RobloxRoundDefaultButton" },
	ScrollBarInset = { "None", "ScrollBar", "Always" },
	ScrollingDirection = { "XY", "X", "Y" },
	ElasticBehavior = { "WhenScrollable", "Always", "Never" },
	VerticalScrollBarPosition = { "Left", "Right" },
	BorderMode = { "Outline", "Middle", "Inset" },
	ResamplerMode = { "Default", "Pixelated" },
	ApplyStrokeMode = { "Contextual", "Border" },
	LineJoinMode = { "Round", "Bevel", "Miter" },
	AspectType = { "FitWithinMaxSize", "ScaleWithParentSize" },
	DominantAxis = { "Width", "Height" },
	NormalId = { "Front", "Back", "Left", "Right", "Top", "Bottom" },
	SelectionBehavior = { "Escape", "Stop" },
	ScreenInsets = { "None", "TopbarSafeInsets", "DeviceSafeInsets", "CoreUISafeInsets", "BottombarSafeInsets" },
	SafeAreaCompatibility = { "None", "FullscreenExtension" },
	SurfaceGuiSizingMode = { "FixedSize", "PixelsPerStud" },
	ReturnKeyType = { "Default", "Done", "Go", "Next", "Search", "Send" },
	StartCorner = { "TopLeft", "TopRight", "BottomLeft", "BottomRight" },
	TableMajorAxis = { "RowMajor", "ColumnMajor" },
	UIFlexAlignment = { "None", "Fill", "SpaceBetween", "SpaceAround", "SpaceEvenly" },
	UIFlexMode = { "Grow", "Shrink", "Fill", "Custom" },
	ItemLineAlignment = { "Automatic", "Start", "Center", "End", "Stretch" },
	Font = { "Legacy", "Arial", "ArialBold", "SourceSans", "SourceSansBold", "SourceSansLight", "Code", "Highway", "SciFi", "Fantasy", "Antique", "Gotham", "GothamSemibold", "Cartoon", "Bodoni", "Arcade", "Denver", "SpecialElite", "Michroma", "Roboto", "Zekton", "Creepster", "Bangers", "LuckiestGuy", "BuilderSans" },
}

Enum = setmetatable({} :: { [string]: any }, {
	__index = function(self: any, key: string)
		local items = (groups :: any)[key]
		if not items then
			return nil
		end
		self[key] = enumGroup(key, items)
		return self[key]
	end,
}) :: any

Stub.Enum = Enum

--> ["class hierarchy"]

local PARENTS: { [string]: string } = {
	Instance = nil :: any,
	Folder = "Instance",
	Configuration = "Instance",
	GuiBase2d = "Instance",
	GuiObject = "GuiBase2d",
	LayerCollector = "Instance",
	ScreenGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	Frame = "GuiObject",
	ScrollingFrame = "GuiObject",
	CanvasGroup = "GuiObject",
	ViewportFrame = "GuiObject",
	VideoFrame = "GuiObject",
	ImageLabel = "GuiObject",
	ImageButton = "ImageLabel",
	TextGuiObject = "GuiObject",
	TextLabel = "TextGuiObject",
	TextButton = "TextGuiObject",
	TextBox = "TextGuiObject",
	UIBase = "Instance",
	UICorner = "UIBase",
	UIStroke = "UIBase",
	UIPadding = "UIBase",
	UIScale = "UIBase",
	UIAspectRatioConstraint = "UIBase",
	UISizeConstraint = "UIBase",
	UITextSizeConstraint = "UIBase",
	UIGradient = "UIBase",
	UIGridStyleLayout = "UIBase",
	UIListLayout = "UIGridStyleLayout",
	UIGridLayout = "UIGridStyleLayout",
	UITableLayout = "UIGridStyleLayout",
	UIPageLayout = "UIGridStyleLayout",
	UIFlexItem = "UIBase",
}

Stub.PARENTS = PARENTS

local EVENTS: { [string]: { string } } = {
	Instance = { "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "Destroying", "AncestryChanged" },
	GuiObject = { "InputBegan", "InputChanged", "InputEnded", "MouseEnter", "MouseLeave", "MouseMoved", "SelectionGained", "SelectionLost", "TouchTap" },
	TextButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click" },
	ImageButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" },
	TextBox = { "Focused", "FocusLost", "ReturnPressedFromOnScreenKeyboard" },
}

local function eventsOf(className: string): { string }
	local out = {}
	local cursor: string? = className
	local guard = 0

	while cursor and guard < 16 do
		guard += 1
		for _, event in (EVENTS[cursor] or {}) :: { string } do
			table.insert(out, event)
		end
		cursor = PARENTS[cursor]
	end

	return out
end

--> ["signals"]

local Signal = {}
Signal.__index = Signal
Signal.__type = "RBXScriptSignal"

function Signal.new(name: string)
	return setmetatable({ name = name, callbacks = {} }, Signal)
end

function Signal.Connect(self: any, fn: (...any) -> ())
	table.insert(self.callbacks, fn)
	Stub.connectionCount += 1

	return {
		Connected = true,
		Disconnect = function(connection: any)
			connection.Connected = false
			local index = table.find(self.callbacks, fn)
			if index then
				table.remove(self.callbacks, index)
			end
			Stub.connectionCount -= 1
		end,
	}
end

function Signal.Fire(self: any, ...: any)
	for index = #self.callbacks, 1, -1 do
		self.callbacks[index](...)
	end
end

Stub.connectionCount = 0 :: number

--> ["Instance"]

local InstanceMeta = {} :: { [string]: any }
InstanceMeta.__type = "Instance"
InstanceMeta.__index = function(self: any, key: string)
	if InstanceMeta[key] ~= nil then
		return InstanceMeta[key]
	end

	-- Parent lives in _parent, because __newindex has to see it come in
	if key == "Parent" then
		return rawget(self, "_parent")
	end

	-- events are asked for by name
	for _, event in self._events do
		if event == key then
			self._signals[key] = self._signals[key] or Signal.new(key)
			return self._signals[key]
		end
	end

	-- anything else is a property, and unset properties are nil
	return nil
end

InstanceMeta.__newindex = function(self: any, key: string, value: any)
	if key == "Parent" then
		local previous = rawget(self, "_parent")

		if previous then
			local index = table.find(previous._children, self)
			if index then
				table.remove(previous._children, index)
			end
		end

		rawset(self, "_parent", value)

		if value then
			table.insert(value._children, self)
		end

		return
	end

	rawset(self, key, value)
end

InstanceMeta.__tostring = function(self: any)
	return self.Name
end

function InstanceMeta.Destroy(self: any)
	if rawget(self, "_destroyed") then
		return
	end

	rawset(self, "_destroyed", true)

	local parent = rawget(self, "_parent")
	if parent then
		local index = table.find(parent._children, self)
		if index then
			table.remove(parent._children, index)
		end
	end

	for _, child in self._children do
		InstanceMeta.Destroy(child)
	end

	local destroying = (self :: any).Destroying
	if destroying then
		Signal.Fire(destroying, self)
	end
end

function InstanceMeta.IsA(self: any, className: string): boolean
	local cursor: string? = self.ClassName
	local guard = 0

	while cursor and guard < 16 do
		guard += 1
		if cursor == className then
			return true
		end
		cursor = PARENTS[cursor]
	end

	return false
end

function InstanceMeta.GetChildren(self: any): { any }
	local out = {}
	for _, child in self._children do
		table.insert(out, child)
	end
	return out
end

function InstanceMeta.FindFirstChild(self: any, name: string, recursive: boolean?): any?
	for _, child in self._children do
		if child.Name == name then
			return child
		end
	end

	if recursive then
		for _, child in self._children do
			local hit = InstanceMeta.FindFirstChild(child, name, true)
			if hit then
				return hit
			end
		end
	end

	return nil
end

function InstanceMeta.WaitForChild(self: any, name: string, _timeout: number?): any?
	return InstanceMeta.FindFirstChild(self, name, true)
end

function InstanceMeta.GetAttributes(self: any): { [string]: any }
	return table.clone(self._attributes)
end

function InstanceMeta.SetAttribute(self: any, key: string, value: any)
	rawset(self._attributes, key, value)
end

function InstanceMeta.GetAttribute(self: any, key: string): any
	return self._attributes[key]
end

function InstanceMeta.GetFullName(self: any): string
	local parts = {}
	local cursor: any = self

	while cursor do
		table.insert(parts, 1, cursor.Name)
		cursor = rawget(cursor, "_parent")
	end

	return table.concat(parts, ".")
end

function InstanceMeta.Clone(self: any)
	local copy = Stub.Instance.new(self.ClassName)
	for key, value in pairs(self) do
		if string.sub(key, 1, 1) ~= "_" then
			copy[key] = value
		end
	end
	return copy
end

Stub.Instance = {} :: any

function Stub.Instance.new(className: string): any
	if type(className) ~= "string" then
		error("[Stub] Instance.new needs a class name", 2)
	end

	local instance = {
		ClassName = className,
		Name = className,
		Parent = nil,
		Archivable = true,
		_children = {},
		_attributes = {},
		_events = eventsOf(className),
		_signals = {},
		_parent = nil,
		_destroyed = false,
	}

	Stub.instances += 1

	setmetatable(instance, InstanceMeta)
	return instance
end

Instance = {
	new = function(className: string)
		return Stub.Instance.new(className)
	end,
} :: any

Stub.InstanceMeta = InstanceMeta
Stub.instances = 0 :: number
Stub.destroyed = 0 :: number

--> ["warn"]
-- Roblox has warn. The Luau CLI does not, and Kite leans on it for every
-- piece of guidance, so here it is: same shape, different colour.

warn = function(...: any)
	local parts = {}

	for index = 1, select("#", ...) do
		table.insert(parts, tostring((select(index, ...))))
	end

	print(table.concat(parts, " "))
end

Stub.warn = warn

--> ["services"]

local frameCallbacks = {}

local function serviceSignal()
	local signal = Signal.new("frame")
	local original = Signal.Connect

	function signal.Connect(_self: any, fn: (number) -> ())
		local connection = original(signal, fn)
		table.insert(frameCallbacks, { fn = fn, connection = connection })
		return connection
	end

	return signal
end

local RunService = {
	RenderStepped = serviceSignal(),
	Heartbeat = serviceSignal(),
	Stepped = serviceSignal(),
}

function RunService.IsClient(_self: any): boolean
	return true
end

function RunService.IsServer(_self: any): boolean
	return false
end

local CollectionService = { tags = {} }

function CollectionService.AddTag(_self: any, instance: any, tag: string)
	CollectionService.tags[tag] = CollectionService.tags[tag] or {}
	table.insert(CollectionService.tags[tag], instance)
	Stub.tags += 1
end

function CollectionService.RemoveTag(_self: any, instance: any, tag: string)
	local list = CollectionService.tags[tag]
	if not list then
		return
	end
	local index = table.find(list, instance)
	if index then
		table.remove(list, index)
	end
end

function CollectionService.HasTag(_self: any, instance: any, tag: string): boolean
	local list = CollectionService.tags[tag]
	if not list then
		return false
	end
	return table.find(list, instance) ~= nil
end

function CollectionService.GetTagged(_self: any, tag: string): { any }
	return table.clone(CollectionService.tags[tag] or {})
end

Stub.tags = 0 :: number

local Players = { LocalPlayer = nil }

game = {
	GetService = function(_self: any, name: string): any
		if name == "RunService" then
			return RunService
		end
		if name == "CollectionService" then
			return CollectionService
		end
		if name == "Players" then
			return Players
		end
		if name == "TextService" then
			return { GetTextSize = function() return Vector2Meta.new(0, 0) end }
		end
		error(`[Stub] no service called {name}`, 2)
	end,
	FindService = function(_self: any, name: string): any
		return nil
	end,
} :: any

Stub.game = game

--> ["the player"]
-- Kite defaults kite.mount to PlayerGui. Tests turn that on when they need it.

function Stub.login(): any
	if Players.LocalPlayer ~= nil then
		return Players.LocalPlayer
	end

	local playerGui = Stub.Instance.new("ScreenGui")
	playerGui.Name = "PlayerGui"

	local player = Stub.Instance.new("Folder")
	player.Name = "LocalPlayer"
	player.ClassName = "Player"

	function player.WaitForChild(_self: any, name: string): any
		if name == "PlayerGui" then
			return playerGui
		end
		error(`[Stub] the fake player has no {name}`, 2)
	end

	Players.LocalPlayer = player
	Stub.playerGui = playerGui

	return player
end

function Stub.logout()
	Players.LocalPlayer = nil
	Stub.playerGui = nil
end

Stub.playerGui = nil :: any
Stub.RunService = RunService
Stub.CollectionService = CollectionService

--> ["task"]
-- Luau outside Roblox does not always ship `task`, and Kite never waits on
-- a real clock in tests, so a synchronous task is the honest version here.

task = {
	wait = function(seconds: number?)
		return seconds or 0
	end,
	spawn = function(fn: () -> (), ...: any)
		fn(...)
	end,
	defer = function(fn: () -> (), ...: any)
		fn(...)
	end,
	delay = function(_seconds: number, fn: () -> (), ...: any)
		fn(...)
	end,
	cancel = function()
		-- nothing is pending
	end,
} :: any

Stub.task = task

--> ["frame stepping"]

function Stub.frame(delta: number?)
	local step = delta or 1 / 60

	for index = #frameCallbacks, 1, -1 do
		local entry = frameCallbacks[index]
		if entry.connection.Connected then
			entry.fn(step)
		else
			table.remove(frameCallbacks, index)
		end
	end

	Stub.frameCount += 1
end

function Stub.frames(count: number, delta: number?)
	for _ = 1, count do
		Stub.frame(delta)
	end
end

Stub.frameCount = 0 :: number

function Stub.reset()
	Stub.instances = 0
	Stub.tags = 0
	Stub.frameCount = 0
	table.clear(CollectionService.tags)
end

function Stub.stats()
	return {
		instances = Stub.instances,
		connections = Stub.connectionCount,
		tags = Stub.tags,
		frames = Stub.frameCount,
	}
end

--> ["exports"]
-- The Luau CLI gives every required module its own globals table, so the
-- package is bundled into one chunk for testing and the globals are handed
-- over as a table. This is that table.

function Stub.exports(): { [string]: any }
	return {
		Instance = Instance,
		UDim = UDim,
		UDim2 = UDim2,
		Vector2 = Vector2,
		Vector3 = Vector3,
		Color3 = Color3,
		CFrame = CFrame,
		Rect = Rect,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		Font = Font,
		Enum = Enum,
		game = game,
		workspace = game,
		task = task,
		warn = warn,
	}
end

return Stub
