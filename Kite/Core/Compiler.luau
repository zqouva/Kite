--!strict
--[=[
	--> ["Kite : Compiler"]

	A Kite tree is a plain table. The compiler turns that table into a plan:
	static properties in one flat array, dynamic properties in another,
	events, attributes, tags, refs, and children already resolved.

	Mounting then walks the plan with no string compares, no type checks,
	and no decisions left to make.

		author once  ->  kite.compile(tree)
		mount many   ->  the same plan, reused

	Plans are cached weakly against the tree table, so the second mount of
	the same tree is a table lookup, not another walk.
]=]

const Util = require(script.Parent.Util)
const Types = require(script.Parent.Types)
const Config = require(script.Parent.Config)

export type Plan = {
	kind: string,
	class: string?,
	name: string?,
	statics: { { [number]: any } }?,
	dynamics: { { [number]: any } }?,
	events: { { [number]: any } }?,
	attrs: { [string]: any }?,
	tags: { string }?,
	refs: { any }?,
	effects: { any }?,
	children: { any }?,
	feed: any?,
	key: any?,
	node: any?,
}

const Compiler = {}

Compiler.compiled = 0 :: number
Compiler.cacheHits = 0 :: number
Compiler.sugar = 0 :: number

const cache = (setmetatable({}, { __mode = "k" }) :: any) :: { [any]: Plan }

--> ["markers"]
-- Special keys are frozen tables, so they can never collide with a real
-- Roblox property name.

const markers = {}
Compiler.markers = markers

local function marker(name: string)
	const value = table.freeze(setmetatable({ __special = name }, {
		__type = "Kite.Special",
		__tostring = function()
			return `kite.{name}`
		end,
		__call = function(_self: any, payload: any)
			return { kind = "special", name = name, value = payload }
		end,
	}))

	markers[name] = value
	return value
end

marker("on")
marker("ref")
marker("attr")
marker("tags")
marker("children")
marker("live")
marker("key")
marker("bind")

local function markerOf(value: any): string?
	if type(value) ~= "table" then
		return nil
	end

	const meta = getmetatable(value)
	if type(meta) == "table" and (meta :: any).__type == "Kite.Special" then
		return (value :: any).__special
	end

	return nil
end

Compiler.markerOf = markerOf

local function callable(value: any): boolean
	if type(value) == "function" then
		return true
	end

	if type(value) ~= "table" then
		return false
	end

	const meta = getmetatable(value)

	if type(meta) == "table" then
		if type((meta :: any).__call) == "function" then
			return true
		end
		if (meta :: any).__type == "Kite.Source" then
			return true
		end
		if (meta :: any).__type == "Kite.Motion" then
			return true
		end
	end

	return false
end

Compiler.callable = callable

--> ["sugar"]
-- Creative and performance modes take shorthands. Strict mode refuses them
-- and hands you the long form.

local function childOf(class: string, props: { [string]: any }): Plan
	return Compiler.plan({
		kind = "element",
		class = class,
		props = props,
	} :: any)
end

local function pushSugar(plan: Plan, key: string, value: any, children: { any })
	Compiler.sugar += 1

	if key == "padding" then
		const top, right, bottom, left
		if typeof(value) == "number" then
			top, right, bottom, left = value, value, value, value
		elseif typeof(value) == "UDim" then
			top, right, bottom, left = value, value, value, value
		elseif typeof(value) == "table" then
			const entry = value :: any
			if entry[1] ~= nil and entry[2] ~= nil and entry[3] == nil then
				top, bottom = entry[1], entry[1]
				left, right = entry[2], entry[2]
			elseif entry[1] ~= nil then
				top, right, bottom, left = entry[1], entry[2] or entry[1], entry[3] or entry[1], entry[4] or entry[2] or entry[1]
			else
				top = entry.top or entry.Top or 0
				right = entry.right or entry.Right or 0
				bottom = entry.bottom or entry.Bottom or 0
				left = entry.left or entry.Left or 0
			end
		end

		table.insert(children, childOf("UIPadding", {
			PaddingTop = Util.padding(top or 0),
			PaddingRight = Util.padding(right or 0),
			PaddingBottom = Util.padding(bottom or 0),
			PaddingLeft = Util.padding(left or 0),
		}))
		return
	end

	if key == "corner" then
		table.insert(children, childOf("UICorner", { CornerRadius = Util.padding(value) }))
		return
	end

	if key == "stroke" then
		if typeof(value) == "Color3" or typeof(value) == "string" then
			table.insert(children, childOf("UIStroke", { Color = Util.hex(value) }))
		else
			const entry = value :: any
			table.insert(children, childOf("UIStroke", {
				Color = Util.hex(entry.color or entry.Color or entry[1] or "#ffffff"),
				Thickness = entry.thickness or entry.Thickness or entry[2] or 1,
				Transparency = entry.transparency or entry.Transparency or entry[3] or 0,
			}))
		end
		return
	end

	if key == "gradient" then
		const entry = value :: any
		const colors = entry.colors or entry.Colors or entry
		const rotation = entry.rotation or entry.Rotation or 90

		const points = {}
		const total = math.max(1, #colors - 1)

		for index, color in colors do
			table.insert(points, ColorSequenceKeypoint.new((index - 1) / total, Util.hex(color)))
		end

		if #points == 1 then
			table.insert(points, ColorSequenceKeypoint.new(1, Util.hex(colors[1])))
		end

		table.insert(children, childOf("UIGradient", {
			Color = ColorSequence.new(points),
			Rotation = rotation,
		}))
		return
	end

	if key == "list" then
		const entry = value :: any

		if typeof(entry) == "string" then
			table.insert(children, childOf("UIListLayout", {
				FillDirection = if entry == "horizontal" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}))
		else
			const props = {}
			for propKey, propValue in entry do
				props[Util.title(propKey)] = propValue
			end
			if props.SortOrder == nil then
				props.SortOrder = Enum.SortOrder.LayoutOrder
			end
			table.insert(children, childOf("UIListLayout", props))
		end
		return
	end

	if key == "scale" then
		table.insert(children, childOf("UIScale", { Scale = value }))
		return
	end

	if key == "aspect" then
		table.insert(children, childOf("UIAspectRatioConstraint", { AspectRatio = value }))
		return
	end
end

const SUGAR = table.freeze({
	size = "Size",
	position = "Position",
	anchor = "AnchorPoint",
	color = "BackgroundColor3",
	textColor = "TextColor3",
	strokeColor = "Color",
	rotate = "Rotation",
	zindex = "ZIndex",
	clip = "ClipsDescendants",
	textSize = "TextSize",
	font = "FontFace",
})

const SUGAR_CHILD = table.freeze({
	padding = "UIPadding",
	corner = "UICorner",
	stroke = "UIStroke",
	gradient = "UIGradient",
	list = "UIListLayout",
	scale = "UIScale",
	aspect = "UIAspectRatioConstraint",
})

local function sugarProperty(key: string, value: any): any
	if key == "size" or key == "position" then
		return Util.size(value)
	end

	if key == "anchor" then
		if typeof(value) == "number" then
			return Vector2.new(value, value)
		end
		if typeof(value) == "string" then
			if value == "center" then
				return Vector2.new(0.5, 0.5)
			end
			if value == "top" then
				return Vector2.new(0.5, 0)
			end
			if value == "bottom" then
				return Vector2.new(0.5, 1)
			end
			if value == "left" then
				return Vector2.new(0, 0.5)
			end
			if value == "right" then
				return Vector2.new(1, 0.5)
			end
		end
		if typeof(value) == "table" then
			return Vector2.new((value :: any)[1] or (value :: any).x or 0, (value :: any)[2] or (value :: any).y or 0)
		end
		return value
	end

	if key == "color" or key == "textColor" or key == "strokeColor" then
		return Util.hex(value)
	end

	if key == "font" then
		if typeof(value) == "string" then
			return Font.fromName(value, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
		end
		if typeof(value) == "table" then
			const entry = value :: any
			return Font.new(entry[1], entry[2] or Enum.FontWeight.Regular, entry[3] or Enum.FontStyle.Normal)
		end
		return value
	end

	return value
end

--> ["plan"]

local function planElement(element: any, report: { any }?): Plan
	const class = element.class :: string
	const props = element.props or {}

	const plan: Plan = {
		kind = "element",
		class = class,
		name = nil,
		statics = nil,
		dynamics = nil,
		events = nil,
		attrs = nil,
		tags = nil,
		refs = nil,
		effects = nil,
		children = nil,
		feed = nil,
		key = nil,
		node = nil,
	}

	const statics: { { [number]: any } } = {}
	const dynamics: { { [number]: any } } = {}
	const events: { { [number]: any } } = {}
	const children: { any } = {}
	const validate = Config.validate

	--> ["special keys"]
	-- Specials arrive two ways, and both are valid:
	--   [kite.ref] = box        computed key, the classic shape
	--   kite.ref(box)           callable, reads better in a list of children

	local function applySpecial(name: string, value: any)
		if name == "on" then
			for eventName, handler in value do
				table.insert(events, { eventName, handler })
			end
		elseif name == "attr" then
			plan.attrs = value
		elseif name == "tags" then
			plan.tags = value
		elseif name == "ref" then
			const refs = plan.refs or {}
			table.insert(refs, value)
			plan.refs = refs
		elseif name == "live" then
			const effects = plan.effects or {}
			table.insert(effects, value)
			plan.effects = effects
		elseif name == "key" then
			plan.key = value
		elseif name == "bind" then
			for propKey, fn in value do
				table.insert(dynamics, { propKey, fn })
			end
		elseif name == "children" then
			if type(value) == "table" then
				for _, child in value do
					table.insert(children, Compiler.plan(child))
				end
			else
				table.insert(children, Compiler.plan(value))
			end
		end
	end

	for key, value in props do
		const special = markerOf(key)

		if special then
			applySpecial(special, value)
			continue
		end

		if type(key) == "number" then
			if type(value) == "table" and (value :: any).kind == "special" then
				applySpecial((value :: any).name, (value :: any).value)
			elseif callable(value) then
				table.insert(children, Compiler.plan({ kind = "dynamic", render = value }))
			else
				table.insert(children, Compiler.plan(value))
			end
			continue
		end

		if type(key) ~= "string" then
			continue
		end

		const mapped = (SUGAR :: any)[key]
		const childSugar = (SUGAR_CHILD :: any)[key]

		if (mapped or childSugar) and not Config.sugar then
			if report then
				const long = if mapped then `{mapped} = ...` else `a {SUGAR_CHILD[key]} child`
				table.insert(report, {
					key = key,
					message = `"{key}" is Kite sugar and strict mode refuses sugar`,
					hint = `write it long form: {long}. switch modes with kite.mode "creative"`,
					level = "error",
				})
			end
			continue
		end

		if childSugar then
			pushSugar(plan, key, value, children)
			continue
		end

		if mapped then
			const sugarKey = key
			key = mapped
			value = sugarProperty(sugarKey, value)
		end

		-- events come first: a handler is a function, but it is not a binding
		if type(value) == "function" and Types.isEvent(class, key) then
			table.insert(events, { key, value })
			continue
		end

		if callable(value) then
			table.insert(dynamics, { key, value })
			continue
		end

		if key == "Name" then
			plan.name = value
		end

		if validate then
			const ok, coerced, problem = Types.check(class, key, value, Config.mode == "strict")

			if not ok and problem then
				if report then
					table.insert(report, problem)
				end
				if problem.level == "error" and Config.guard then
					continue
				end
			else
				table.insert(statics, { key, coerced })
				continue
			end
		end

		table.insert(statics, { key, value })
	end

	if #statics > 0 then
		plan.statics = statics
	end

	plan.dynamics = if #dynamics > 0 then dynamics else nil
	plan.events = if #events > 0 then events else nil
	plan.children = if #children > 0 then children else nil

	return plan
end

function Compiler.plan(node: any, report: { any }?): Plan
	if node == nil then
		return nil :: any
	end

	const kind = type(node) == "table" and (node :: any).kind or nil

	if kind == nil then
		if typeof(node) == "Instance" then
			return {
				kind = "instance",
				node = node,
			} :: Plan
		end

		error(
			`[Kite] a child in your tree is {Util.show(node)}, which is not something Kite can mount.\n`
				.. "  children are elements (kite.create \"Frame\" { ... }), instances, or dynamic nodes.",
			3
		)
	end

	if kind == "element" then
		const hit = cache[node]
		if hit and Config.cache then
			Compiler.cacheHits += 1
			return hit
		end

		const plan = planElement(node, report)
		Compiler.compiled += 1
		Util.freeze(plan)

		if Config.cache then
			cache[node] = plan
		end

		return plan
	end

	-- dynamic nodes (keys, indexes, when, switch, component, instance, motion)
	const plan: Plan = {
		kind = kind,
		class = nil,
		name = nil,
		statics = nil,
		dynamics = nil,
		events = nil,
		attrs = nil,
		tags = nil,
		refs = nil,
		effects = nil,
		children = nil,
		feed = node.feed,
		key = node.key,
		node = if kind == "instance" then (node :: any).node else node,
	}

	return plan
end

function Compiler.compile(node: any): Plan
	return Compiler.plan(node)
end

function Compiler.forget()
	table.clear(cache)
end

function Compiler.stats()
	return {
		compiled = Compiler.compiled,
		cacheHits = Compiler.cacheHits,
		cached = Util.count(cache),
		sugar = Compiler.sugar,
	}
end

function Compiler.reset()
	Compiler.compiled = 0
	Compiler.cacheHits = 0
	Compiler.sugar = 0
end

return Compiler
