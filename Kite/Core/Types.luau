--!strict
--[=[
	--> ["Kite : Types"]

	A registry of what actually exists on a Roblox Instance.

	This is the module that lets Kite *teach* you instead of throwing
	`Text is not a valid member of Frame` at runtime.

		```lua
		kite.create `Frame` { Text = `hi` }
		-- [Kite] Frame does not have a property called `Text`.
		--   did you mean: Visible?
		--   Frame draws nothing. Use a TextLabel for text.
		--   kite.help(`text`) walks through it.
		```

	Strict mode reads this table on every compile. Creative mode reads it
	to coerce shorthands. Performance mode skips it entirely.
]=]

const Util = require(script.Parent.Util)

const Types = {}

export type Range = { number }

export type Class = {
	parent: string?,
	props: { [string]: string },
	events: { [string]: boolean },
	ranges: { [string]: Range },
	note: string?,
}

const classes: { [string]: Class } = {}

local function define(name: string, parent: string?, props: { [string]: string }, events: { string }?, note: string?)
	const eventMap = {}
	if events then
		for _, event in events do
			eventMap[event] = true
		end
	end

	classes[name] = {
		parent = parent,
		props = props,
		events = eventMap :: { [string]: boolean },
		ranges = {},
		note = note,
	}
end

local function range(class: string, key: string, low: number, high: number)
	const entry = classes[class]
	if entry then
		entry.ranges[key] = { low, high }
	end
end

--> ["Instance"]

define("Instance", nil, {
	Name = "string",
	Archivable = "boolean",
}, {
	"AncestryChanged",
	"AttributeChanged",
	"Changed",
	"ChildAdded",
	"ChildRemoved",
	"DescendantAdded",
	"DescendantRemoving",
	"Destroying",
})

define("Folder", "Instance", {})
define("Configuration", "Instance", {})

--> ["GuiBase2d"]

define("LayerCollector", "Instance", {
	Enabled = "boolean",
	ResetOnSpawn = "boolean",
	ZIndexBehavior = "Enum.ZIndexBehavior",
	DisplayOrder = "number",
	IgnoreGuiInset = "boolean",
	ScreenInsets = "Enum.ScreenInsets",
	ClipToDeviceSafeArea = "boolean",
	SafeAreaCompatibility = "Enum.SafeAreaCompatibility",
})

define("ScreenGui", "LayerCollector", {
	DisplayOrder = "number",
	IgnoreGuiInset = "boolean",
})

define("BillboardGui", "LayerCollector", {
	Active = "boolean",
	Adornee = "Instance",
	AlwaysOnTop = "boolean",
	Brightness = "number",
	ClipsDescendants = "boolean",
	DistanceLowerLimit = "number",
	DistanceStep = "number",
	DistanceUpperLimit = "number",
	ExtentsOffset = "Vector3",
	ExtentsOffsetWorldSpace = "Vector3",
	LightInfluence = "number",
	MaxDistance = "number",
	PlayerToHideFrom = "Instance",
	Size = "UDim2",
	SizeOffset = "Vector2",
	StudsOffset = "Vector3",
	StudsOffsetWorldSpace = "Vector3",
})

define("SurfaceGui", "LayerCollector", {
	Adornee = "Instance",
	Active = "boolean",
	AlwaysOnTop = "boolean",
	Brightness = "number",
	CanvasSize = "Vector2",
	ClipsDescendants = "boolean",
	Face = "Enum.NormalId",
	LightInfluence = "number",
	PixelsPerStud = "number",
	SizingMode = "Enum.SurfaceGuiSizingMode",
	ToolPunchThroughDistance = "number",
	ZOffset = "number",
})

define("GuiBase2d", "Instance", {
	AbsolutePosition = "Vector2",
	AbsoluteRotation = "number",
	AbsoluteSize = "Vector2",
	AutoLocalize = "boolean",
	RootLocalizationTable = "Instance",
	SelectionBehaviorDown = "Enum.SelectionBehavior",
	SelectionBehaviorLeft = "Enum.SelectionBehavior",
	SelectionBehaviorRight = "Enum.SelectionBehavior",
	SelectionBehaviorUp = "Enum.SelectionBehavior",
	SelectionGroup = "boolean",
	SelectionBehavior = "Enum.SelectionBehavior",
})

define("GuiObject", "GuiBase2d", {
	Active = "boolean",
	AnchorPoint = "Vector2",
	AutomaticSize = "Enum.AutomaticSize",
	BackgroundColor3 = "Color3",
	BackgroundTransparency = "number",
	BorderColor3 = "Color3",
	BorderMode = "Enum.BorderMode",
	BorderSizePixel = "number",
	ClipsDescendants = "boolean",
	LayoutOrder = "number",
	NextSelectionDown = "Instance",
	NextSelectionLeft = "Instance",
	NextSelectionRight = "Instance",
	NextSelectionUp = "Instance",
	Position = "UDim2",
	Rotation = "number",
	Selectable = "boolean",
	SelectionImageObject = "Instance",
	Size = "UDim2",
	SizeConstraint = "Enum.SizeConstraint",
	Transparency = "number",
	Visible = "boolean",
	ZIndex = "number",
}, {
	"InputBegan",
	"InputChanged",
	"InputEnded",
	"MouseEnter",
	"MouseLeave",
	"MouseMoved",
	"MouseWheelBackward",
	"MouseWheelForward",
	"SelectionGained",
	"SelectionLost",
	"TouchLongPress",
	"TouchMoved",
	"TouchPan",
	"TouchPinch",
	"TouchRotate",
	"TouchSwipe",
	"TouchTap",
})

range("GuiObject", "BackgroundTransparency", 0, 1)
range("GuiObject", "Transparency", 0, 1)
range("GuiObject", "Rotation", -360, 360)

define("Frame", "GuiObject", {
	Style = "Enum.FrameStyle",
}, nil, "Frame draws a rectangle. It has no Text property; reach for TextLabel.")

define("ScrollingFrame", "GuiObject", {
	AutomaticCanvasSize = "Enum.AutomaticSize",
	BottomImage = "string",
	CanvasPosition = "Vector2",
	CanvasSize = "UDim2",
	ElasticBehavior = "Enum.ElasticBehavior",
	HorizontalScrollBarInset = "Enum.ScrollBarInset",
	MidImage = "string",
	ScrollBarImageColor3 = "Color3",
	ScrollBarImageTransparency = "number",
	ScrollBarThickness = "number",
	ScrollingDirection = "Enum.ScrollingDirection",
	ScrollingEnabled = "boolean",
	TopImage = "string",
	VerticalScrollBarInset = "Enum.ScrollBarInset",
	VerticalScrollBarPosition = "Enum.VerticalScrollBarPosition",
}, nil, "ScrollingFrame needs CanvasSize set or it will not scroll.")

range("ScrollingFrame", "ScrollBarImageTransparency", 0, 1)

define("CanvasGroup", "GuiObject", {
	GroupColor3 = "Color3",
	GroupTransparency = "number",
}, nil, "CanvasGroup renders its children into one texture. Children do not inherit ZIndex across it.")

range("CanvasGroup", "GroupTransparency", 0, 1)

define("ViewportFrame", "GuiObject", {
	Ambient = "Color3",
	CurrentCamera = "Instance",
	ImageColor3 = "Color3",
	ImageTransparency = "number",
	LightColor = "Color3",
	LightDirection = "Vector3",
})

define("VideoFrame", "GuiObject", {
	Looped = "boolean",
	Playing = "boolean",
	TimePosition = "number",
	Video = "string",
	Volume = "number",
})

define("ImageLabel", "GuiObject", {
	Image = "string",
	ImageColor3 = "Color3",
	ImageRectOffset = "Vector2",
	ImageRectSize = "Vector2",
	ImageTransparency = "number",
	ResampleMode = "Enum.ResamplerMode",
	ScaleType = "Enum.ScaleType",
	SliceCenter = "Rect",
	SliceScale = "number",
	TileSize = "UDim2",
})

range("ImageLabel", "ImageTransparency", 0, 1)

define("ImageButton", "ImageLabel", {
	HoverImage = "string",
	PressedImage = "string",
	SelectedImage = "string",
	Style = "Enum.ButtonStyle",
	AutoButtonColor = "boolean",
	Modal = "boolean",
	Selected = "boolean",
}, {
	"Activated",
	"MouseButton1Click",
	"MouseButton1Down",
	"MouseButton1Up",
	"MouseButton2Click",
	"MouseButton2Down",
	"MouseButton2Up",
})

define("TextGuiObject", "GuiObject", {
	FontFace = "Font",
	Font = "Enum.Font",
	LineHeight = "number",
	MaxVisibleGraphemes = "number",
	RichText = "boolean",
	Text = "string",
	TextColor3 = "Color3",
	TextScaled = "boolean",
	TextSize = "number",
	TextStrokeColor3 = "Color3",
	TextStrokeTransparency = "number",
	TextTransparency = "number",
	TextTruncate = "Enum.TextTruncate",
	TextWrapped = "boolean",
	TextXAlignment = "Enum.TextXAlignment",
	TextYAlignment = "Enum.TextYAlignment",
	ContentText = "string",
	Localize = "boolean",
})

range("TextGuiObject", "TextTransparency", 0, 1)
range("TextGuiObject", "TextStrokeTransparency", 0, 1)
range("TextGuiObject", "TextSize", 1, 100)

define("TextLabel", "TextGuiObject", {}, nil, "TextLabel has no Activated event. Use TextButton if it should be clickable.")

define("TextButton", "TextGuiObject", {
	AutoButtonColor = "boolean",
	Modal = "boolean",
	Selected = "boolean",
	Style = "Enum.ButtonStyle",
}, {
	"Activated",
	"MouseButton1Click",
	"MouseButton1Down",
	"MouseButton1Up",
	"MouseButton2Click",
	"MouseButton2Down",
	"MouseButton2Up",
})

define("TextBox", "TextGuiObject", {
	ClearTextOnFocus = "boolean",
	CursorPosition = "number",
	ManualFocusRelease = "boolean",
	MultiLine = "boolean",
	OverlayNativeInput = "boolean",
	PlaceholderColor3 = "Color3",
	PlaceholderText = "string",
	ReturnKeyType = "Enum.ReturnKeyType",
	ShowNativeInput = "boolean",
	TextEditable = "boolean",
}, {
	"FocusLost",
	"Focused",
	"ReturnPressedFromOnScreenKeyboard",
	"CursorMoved",
})

--> ["modifiers and layouts"]

define("UIBase", "Instance", {})

define("UICorner", "UIBase", {
	CornerRadius = "UDim",
})

define("UIStroke", "UIBase", {
	ApplyStrokeMode = "Enum.ApplyStrokeMode",
	Color = "Color3",
	Enabled = "boolean",
	LineJoinMode = "Enum.LineJoinMode",
	Thickness = "number",
	Transparency = "number",
})

range("UIStroke", "Transparency", 0, 1)

define("UIPadding", "UIBase", {
	PaddingBottom = "UDim",
	PaddingLeft = "UDim",
	PaddingRight = "UDim",
	PaddingTop = "UDim",
})

define("UIScale", "UIBase", {
	Scale = "number",
})

define("UIAspectRatioConstraint", "UIBase", {
	AspectRatio = "number",
	AspectType = "Enum.AspectType",
	DominantAxis = "Enum.DominantAxis",
})

define("UISizeConstraint", "UIBase", {
	MaxSize = "Vector2",
	MinSize = "Vector2",
})

define("UITextSizeConstraint", "UIBase", {
	MaxTextSize = "number",
	MinTextSize = "number",
})

define("UIGradient", "UIBase", {
	Color = "ColorSequence",
	Enabled = "boolean",
	Offset = "Vector2",
	Rotation = "number",
	Transparency = "NumberSequence",
})

define("UIGridStyleLayout", "UIBase", {
	FillDirection = "Enum.FillDirection",
	HorizontalAlignment = "Enum.HorizontalAlignment",
	SortOrder = "Enum.SortOrder",
	VerticalAlignment = "Enum.VerticalAlignment",
	HorizontalFlex = "Enum.UIFlexAlignment",
	VerticalFlex = "Enum.UIFlexAlignment",
	ItemLineAlignment = "Enum.ItemLineAlignment",
})

define("UIListLayout", "UIGridStyleLayout", {
	Padding = "UDim",
	Wraps = "boolean",
	FillDirection = "Enum.FillDirection",
	HorizontalAlignment = "Enum.HorizontalAlignment",
	VerticalAlignment = "Enum.VerticalAlignment",
	SortOrder = "Enum.SortOrder",
}, nil, "UIListLayout sizes siblings. It must be a direct child of the frame it lays out.")

define("UIGridLayout", "UIGridStyleLayout", {
	CellPadding = "UDim2",
	CellSize = "UDim2",
	FillDirectionMaxCells = "number",
	StartCorner = "Enum.StartCorner",
})

define("UITableLayout", "UIGridStyleLayout", {
	FillEmptySpaceColumns = "boolean",
	FillEmptySpaceRows = "boolean",
	MajorAxis = "Enum.TableMajorAxis",
	Padding = "UDim2",
})

define("UIPageLayout", "UIGridStyleLayout", {
	Animated = "boolean",
	Circular = "boolean",
	EasingDirection = "Enum.EasingDirection",
	EasingStyle = "Enum.EasingStyle",
	GamepadInputEnabled = "boolean",
	Padding = "UDim",
	ScrollWheelInputEnabled = "boolean",
	TouchInputEnabled = "boolean",
	TweenTime = "number",
}, { "PageEnter", "PageLeave" })

define("UIFlexItem", "UIBase", {
	FlexMode = "Enum.UIFlexMode",
	ItemFlexRatio = "number",
})

-- not frozen: kite.know adds to it at runtime
Types.classes = classes

--> ["resolution"]

const resolved: { [string]: { props: { [string]: string }, events: { [string]: boolean }, ranges: { [string]: Range }, chain: { string } } } =
	{}

function Types.resolve(className: string)
	const hit = resolved[className]
	if hit then
		return hit
	end

	const props: { [string]: string } = {}
	const events: { [string]: boolean } = {}
	const ranges: { [string]: Range } = {}
	const chain: { string } = {}

	const cursor: string? = className
	const guard = 0

	while cursor and guard < 32 do
		guard += 1
		table.insert(chain, cursor)
		const entry = classes[cursor]

		if not entry then
			break
		end

		for key, kind in entry.props do
			if props[key] == nil then
				props[key] = kind
			end
		end

		for key in entry.events do
			events[key] = true
		end

		for key, span in entry.ranges do
			if ranges[key] == nil then
				ranges[key] = span
			end
		end

		cursor = entry.parent
	end

	const out = {
		props = table.freeze(props),
		events = table.freeze(events),
		ranges = table.freeze(ranges),
		chain = table.freeze(chain),
	}

	resolved[className] = out
	return out
end

function Types.known(className: string): boolean
	return if classes[className] then true else false
end

--> ["coercion"]

local function coerceEnum(kind: string, value: any, strict: boolean): any?
	const name = string.match(kind, "^Enum%.(.+)$")
	if not name then
		return nil
	end

	if Util.kindOf(value) == "EnumItem" then
		return value
	end

	-- enum items that arrive as plain tables, which is what a test stub
	-- or a deserialized payload gives you
	if type(value) == "table" then
		const label = (value :: any).Name
		if type(label) == "string" then
			return value
		end
		return nil
	end

	if type(value) ~= "string" then
		return nil
	end

	-- strict mode wants the real thing, not a spelling of it
	if strict then
		const group = (Enum :: any)[name]
		return (group :: any)[value]
	end

	const group = (Enum :: any)[name]
	if not group then
		return nil
	end

	const hit = (group :: any)[value]

	if not hit then
		-- Accept `Left`, `left`, `Enum.TextXAlignment.Left`, `TextXAlignment.Left`
		const bare = string.match(value, "%.([%w_]+)$") or value
		for _, item in (group :: any):GetEnumItems() do
			if string.lower(item.Name) == string.lower(bare) then
				return item
			end
		end
	end

	return hit
end

local function coerceTo(kind: string, value: any, strict: boolean): any?
	if type(value) == "function" then
		return nil
	end

	const got = Util.kindOf(value)

	-- strict mode does not reshape your values. it tells you about them.
	if strict and got ~= kind then
		if not string.find(kind, "^Enum%.") then
			return nil
		end
	end

	if kind == "Color3" then
		if got == "Color3" then
			return value
		end
		if got == "string" then
			return Util.hex(value)
		end
		if got == "table" then
			return Util.hex(value)
		end
		return nil
	end

	if kind == "UDim2" then
		if got == "UDim2" then
			return value
		end
		if got == "number" or got == "string" or got == "table" then
			return Util.size(value)
		end
		return nil
	end

	if kind == "UDim" then
		if got == "UDim" then
			return value
		end
		if got == "number" then
			return UDim.new(0, value)
		end
		if got == "table" then
			return Util.padding(value)
		end
		return nil
	end

	if kind == "Vector2" then
		if got == "Vector2" then
			return value
		end
		if got == "table" then
			return Vector2.new((value :: any)[1] or 0, (value :: any)[2] or 0)
		end
		if got == "number" then
			return Vector2.new(value, value)
		end
		return nil
	end

	if kind == "Vector3" then
		if got == "Vector3" then
			return value
		end
		if got == "table" then
			return Vector3.new((value :: any)[1] or 0, (value :: any)[2] or 0, (value :: any)[3] or 0)
		end
		return nil
	end

	if kind == "ColorSequence" then
		if got == "ColorSequence" then
			return value
		end
		if got == "table" then
			const points = {}
			for index, color in value do
				const at = if type(index) == "number" then (index - 1) / math.max(1, #value - 1) else 0
				table.insert(points, ColorSequenceKeypoint.new(at, Util.hex(color)))
			end
			if #points == 1 then
				table.insert(points, ColorSequenceKeypoint.new(1, Util.hex((value :: any)[1])))
			end
			return ColorSequence.new(points)
		end
		return nil
	end

	if kind == "number" then
		if got == "number" then
			return value
		end
		if got == "string" then
			return tonumber(value)
		end
		return nil
	end

	if kind == "boolean" then
		if got == "boolean" then
			return value
		end
		return nil
	end

	if kind == "string" then
		if got == "string" then
			return value
		end
		if got == "number" then
			return tostring(value)
		end
		return nil
	end

	if kind == "Font" then
		if got == "Font" then
			return value
		end
		if got == "EnumItem" then
			return Font.fromEnum(value)
		end
		if got == "string" then
			return Font.fromName(value, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
		end
		return nil
	end

	if kind == "Instance" then
		return if got == "Instance" then value else nil
	end

	if string.sub(kind, 1, 5) == "Enum." then
		return coerceEnum(kind, value, strict)
	end

	return value
end

Types.coerce = coerceTo

--> ["check"]
-- Returns (ok, value, problem). `problem` is already written for humans.

export type Problem = {
	key: string,
	message: string,
	hint: string?,
	level: string,
}

function Types.check(className: string, key: string, value: any, strict: boolean): (boolean, any, Problem?)
	const info = Types.resolve(className)
	const kind = info.props[key]

	if kind == nil then
		const nearest = Util.nearest(key, Util.keys(info.props))

		const hint
		if nearest then
			hint = `did you mean "{nearest}"?`
		elseif classes[className] and classes[className].note then
			hint = classes[className].note
		elseif info.events[key] then
			hint = `"{key}" is an event on {className}. Events go through kite.on, or assign the handler directly.`
		end

		return false, value, {
			key = key,
			message = `{className} has no property called "{key}"`,
			hint = hint,
			level = "error",
		}
	end

	if type(value) == "function" then
		return true, value, nil
	end

	const coerced = coerceTo(kind, value, strict)

	if coerced == nil then
		const got = Util.kindOf(value)

		return false, value, {
			key = key,
			message = `{className}.{key} expects {kind}, but you gave it {Util.show(value)}`,
			hint = if strict and got ~= kind
				then `{Util.title(got)} is not {kind}, and strict mode will not reshape it for you.`
				else `a {kind} looks like this in Kite: {Types.exampleOf(kind)}`,
			level = "error",
		}
	end

	const span = info.ranges[key]

	if span and Util.kindOf(coerced) == "number" then
		if coerced < span[1] or coerced > span[2] then
			return false, coerced, {
				key = key,
				message = `{className}.{key} should sit between {span[1]} and {span[2]}, you gave {Util.show(coerced)}`,
				hint = `clamp it: kite.clamp({coerced}, {span[1]}, {span[2]})`,
				level = "error",
			}
		end
	end

	return true, coerced, nil
end

--> ["fit"]
-- A binding writes on every frame, so this does not get to be clever. It
-- resolves the property kind once per Class.property, then stays out of
-- the way. Anything it cannot fix is handed back untouched.

const kindCache: { [string]: any } = {}

function Types.fit(className: string, key: string, value: any): any
	if type(value) == "function" then
		return value
	end

	const cacheKey = `{className}.{key}`
	const cached = kindCache[cacheKey]

	const kind: string?

	if cached == nil then
		const info = Types.resolve(className)
		kind = info.props[key]
		kindCache[cacheKey] = if kind then kind else false
	elseif cached ~= false then
		kind = cached :: string
	end

	if kind == nil then
		return value
	end

	return coerceTo(kind :: string, value, false) or value
end

function Types.exampleOf(kind: string): string
	if kind == "UDim2" then
		return "UDim2.fromOffset(200, 46)  or  kite.size(200, 46)"
	end
	if kind == "UDim" then
		return "UDim.new(0, 8)  or  8"
	end
	if kind == "Vector2" then
		return "Vector2.new(0.5, 0.5)  or  kite.anchor(0.5, 1)"
	end
	if kind == "Color3" then
		return `Color3.fromHex("3ddad7")  or  "#3ddad7"`
	end
	if kind == "ColorSequence" then
		return `gradient = \{ "#112126", "#0d181b" \}`
	end
	if kind == "Font" then
		return `Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Medium)`
	end
	if string.sub(kind, 1, 5) == "Enum." then
		return `{kind}.{Util.title(string.match(kind, "%.(.+)$") or "Value")}  or  "{string.match(kind, "%.(.+)$")}"`
	end
	return `a {kind}`
end

--> ["events"]

--> ["teach"]
-- Kite ships with the classes it knows. When you meet one it does not,
-- say so once and the linter starts helping with it too.

function Types.learn(className: string, parent: string?, props: { [string]: string }, events: { string }?)
	define(className, parent or "Instance", props, events)

	-- drop the memoized chains so the new class shows up everywhere
	for key in resolved do
		resolved[key] = nil
	end
end

function Types.isEvent(className: string, key: string): boolean
	const info = Types.resolve(className)
	return info.events[key] == true
end

function Types.hasProperty(className: string, key: string): boolean
	return Types.resolve(className).props[key] ~= nil
end

return Types
