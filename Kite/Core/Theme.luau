--!strict
--[=[
	--> ["Kite : Theme"]

	Tokens, not colour literals scattered through your trees.

	Every token is a source. Switch the theme and every property that read
	the token updates, with no re-render and no extra work from you.

	```lua
	const theme = kite.theme {
		mode = `dark`,
		dark = {
			ink   = `#0d181b`,
			panel = `#112126`,
			text  = `#eeeeee`,
			accent = `#3ddad7`,
		},
		light = {
			ink   = `#f4f7f7`,
			panel = `#e2eaec`,
			text  = `#142224`,
			accent = `#0f8f8d`,
		},
	}

	kite.create `TextLabel` {
		TextColor3 = theme.text,
		BackgroundColor3 = theme.panel,
	}

	theme:set(`light`) -- everything moves
	```

	A single palette works too:
	```lua
	const theme = kite.theme { ink = `#0d181b`, accent = `#3ddad7` }
	```
]=]

const Util = require(script.Parent.Util)

export type Theme = {
	kind: string,
	tokens: { [string]: any },
	names: { string },
	mode: any,
	get: (Theme, string) -> any,
	value: (Theme, string) -> any,
	set: (Theme, string) -> any,
	has: (Theme, string) -> boolean,
	list: (Theme) -> { string },
	blend: (Theme, string, string, number) -> any,
}

const Theme = {}

Theme.defined = 0 :: number

local function tokensOf(palette: { [string]: any }): { string }
	const names = {}
	for key in palette do
		if type(key) == "string" then
			table.insert(names, key)
		end
	end
	table.sort(names)
	return names
end

const RESERVED = table.freeze({ mode = true })

function Theme.define(palettes: { [any]: any }): Theme
	const Graph = require(script.Parent.Graph) :: any

	const single = true

	for key, value in palettes do
		if type(value) == "table" and key ~= "mode" then
			single = false
			break
		end
	end

	const modes: { [string]: { [string]: any } } = {}

	if single then
		const flat = {}
		for key, value in palettes do
			if type(key) == "string" and not RESERVED[key] and typeof(value) ~= "table" then
				flat[key] = value
			end
		end
		modes.default = flat
	else
		for key, value in palettes do
			if type(key) == "string" and not RESERVED[key] and type(value) == "table" then
				modes[key] = value :: any
			end
		end
	end

	if Util.count(modes) == 0 then
		error(
			"[Kite] a theme needs at least one palette.\n"
				.. '  kite.theme { ink = "#0d181b" }\n'
				.. '  kite.theme { dark = { ink = "#0d181b" }, light = { ink = "#f4f7f7" } }',
			3
		)
	end

	const names: { string } = {}
	const seen: { [string]: boolean } = {}

	for _, palette in modes do
		for _, name in tokensOf(palette) do
			if not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end

	table.sort(names)

	const starting = (palettes :: any).mode

	if starting == nil then
		const keys = Util.sorted(Util.keys(modes))
		starting = keys[1]
	end

	const tokens: { [string]: any } = {}

	for _, name in names do
		const value = (modes[starting] :: any)[name]
		if value == nil then
			for _, palette in modes do
				if (palette :: any)[name] ~= nil then
					value = (palette :: any)[name]
					break
				end
			end
		end
		tokens[name] = Graph.source(Util.hex(value), { name = `theme.{name}` })
	end

	const modeSource = Graph.source(starting, { name = "theme.mode" })

	const theme = {
		kind = "theme",
		tokens = tokens,
		names = names,
		modes = modes,
		mode = modeSource,
	} :: any

	function theme.get(_self: any, name: string): any
		const token = tokens[name]

		if token == nil then
			const nearest = Util.nearest(name, names)
			error(
				`[Kite] the theme has no token called "{name}".\n`
					.. (if nearest then `  did you mean "{nearest}"?\n` else "")
					.. `  this theme has: {table.concat(names, ", ")}`,
				3
			)
		end

		return token
	end

	function theme.value(_self: any, name: string): any
		return theme.get(nil, name)()
	end

	function theme.has(_self: any, name: string): boolean
		return tokens[name] ~= nil
	end

	function theme.list(_self: any): { string }
		return table.clone(names)
	end

	function theme.tokens(_self: any): { [string]: any }
		return table.clone(tokens)
	end

	function theme.set(_self: any, name: string)
		const palette = modes[name]

		if palette == nil then
			const nearest = Util.nearest(name, Util.keys(modes))
			error(
				`[Kite] the theme has no mode called "{name}".\n`
					.. (if nearest then `  did you mean "{nearest}"?\n` else "")
					.. `  modes: {table.concat(Util.sorted(Util.keys(modes)), ", ")}`,
				3
			)
		end

		const GraphInner = require(script.Parent.Graph) :: any

		GraphInner.batch(function()
			modeSource(name)
			for key, token in tokens do
				const next = (palette :: any)[key]
				if next ~= nil then
					token(Util.hex(next))
				end
			end
		end)

		return theme
	end

	function theme.toggle(_self: any)
		const order = Util.sorted(Util.keys(modes))
		const index = table.find(order, modeSource()) or 1
		const next = order[(index % #order) + 1]
		theme.set(nil, next)
		return next
	end

	function theme.blend(_self: any, leftName: string, rightName: string, alpha: number?): any
		const GraphInner = require(script.Parent.Graph) :: any

		const left = theme.get(nil, leftName)
		const right = theme.get(nil, rightName)
		const amount = alpha or 0.5

		return GraphInner.derive(function()
			return left():Lerp(right(), amount)
		end, { name = `theme.{leftName}+{rightName}` })
	end

	function theme.extend(_self: any, extra: { [string]: any })
		const GraphInner = require(script.Parent.Graph) :: any

		for key, value in extra do
			if tokens[key] == nil then
				table.insert(names, key)
			end
			tokens[key] = GraphInner.source(Util.hex(value), { name = `theme.{key}` })
		end

		return theme
	end

	Theme.defined += 1

	return setmetatable(theme, {
		__type = "Kite.Theme",
		__index = function(self: any, key: string)
			if tokens[key] then
				return tokens[key]
			end

			const field = (theme :: any)[key]
			if field ~= nil then
				return field
			end

			const nearest = Util.nearest(key, names)
			error(
				`[Kite] the theme has no token called "{key}".\n`
					.. (if nearest then `  did you mean "{nearest}"?\n` else "")
					.. `  tokens: {table.concat(names, ", ")}`,
				2
			)
		end,
		__tostring = function(self: any)
			return `Kite.Theme({modeSource()}, {#names} tokens)`
		end,
	})
end

function Theme.stats()
	return {
		defined = Theme.defined,
	}
end

return Theme
