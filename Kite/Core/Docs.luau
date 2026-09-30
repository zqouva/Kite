--!strict
--[=[
	--> ["Kite : Docs"]

	The package that reads itself out loud.

		kite.help()            the map of everything
		kite.help(`spring`)    one topic, with an example you can paste
		kite.topics()          every topic name

	Every public function in `init.luau` also carries a doc comment, so
	hovering it in Studio shows the same explanation and example. This
	module is the console version of that hover.

	--> ["why this exists"]
	You should not have to leave the editor to remember what a spring
	accepts. Kite answers in the console, in the same voice the linter
	uses.
]=]

const Util = require(script.Parent.Util)

const Docs = {}

export type Topic = {
	name: string,
	summary: string,
	usage: string?,
	example: string?,
	see: { string }?,
	note: string?,
}

const topics: { [string]: Topic } = {}

local function topic(entry: Topic)
	topics[entry.name] = entry
end

--> ["reactivity"]

topic({
	name = "source",
	summary = "A value that Kite watches. Call it to read, call it with an argument to write.",
	usage = "const count = kite.source(0)",
	example = [[
const count = kite.source(0)

count()          -- 0
count(4)         -- writes 4
count:set(5)     -- same, explicit
count:set(count:get() + 1)
count:update(function(v) return v + 1 end)]],
	see = { "derive", "effect", "batch" },
})

topic({
	name = "derive",
	summary = "A value computed from other values. It only recomputes when something it read changes.",
	usage = "const doubled = count:map(function(v) return v * 2 end)",
	example = [[
const hp = kite.source(100)
const dead = kite.derive(function()
	return hp() <= 0
end)

dead()  -- false
hp(0)
dead()  -- true, recomputed because hp moved]],
	see = { "source", "effect" },
})

topic({
	name = "effect",
	summary = "Work that happens when what it reads changes. Returns a function that stops it.",
	usage = "const stop = count:watch(function(v) print(v) end)",
	example = [[
const stop = hp:watch(function(value)
	print(`hp is now`, value)
end)

stop()  -- no more printing]],
	see = { "derive", "batch" },
})

topic({
	name = "batch",
	summary = "Groups writes so the graph settles once instead of once per write.",
	usage = "kite.batch(function() a(1) b(2) end)",
	example = [[
kite.batch(function()
	health(10)
	shield(0)
	ammo(30)
end)
-- one settle, one frame of UI work, not three]],
	see = { "source", "untrack" },
})

topic({
	name = "untrack",
	summary = "Reads without subscribing. The block is invisible to the effect around it.",
	usage = "kite.untrack(function() return something() end)",
	example = [[
kite.effect(function()
	const name = player.Name              -- tracked
	const quiet = kite.untrack(function() return debugFlag() end)
	print(name, quiet)
end)]],
	see = { "batch", "source" },
})

topic({
	name = "record",
	summary = "A table of sources. Nested tables become nested records.",
	usage = "const stats = kite.record { hp = 100, aura = { grace = 1 } }",
	example = [[
const stats = kite.record { hp = 100, aura = { grace = 1 } }

stats.hp(80)
stats.aura.grace(4)

kite.create `TextLabel` { Text = stats.hp }]],
	see = { "source" },
})

--> ["motion"]

topic({
	name = "spring",
	summary = "Physics motion. Overshoots, settles, and reads like something with weight.",
	usage = "kite.spring(sourceOrFunction, { speed = 1, damping = 1 })",
	example = [[
const open = kite.source(false)
const slide = kite.spring(function()
	return if open() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 1.2)
end, { speed = 0.28, damping = 0.9 })

kite.create `Frame` { Position = slide }

-- shorter, straight off the source
const fade = open:spring(0.28):map(function(v) return if v > 0.5 then 0 else 1 end)]],
	see = { "tween", "damp", "clock" },
})

topic({
	name = "tween",
	summary = "Time based motion with an easing curve. Exact duration, no overshoot unless you ask.",
	usage = 'kite.tween(source, { time = 0.3, ease = kite.ease.QuadOut })',
	example = [[
kite.create `Frame` {
	BackgroundTransparency = kite.tween(function()
		return if open() then 0.1 else 1
	end, { time = 0.24, ease = kite.ease.CubicOut }),
}]],
	see = { "spring", "damp" },
})

topic({
	name = "damp",
	summary = "Exponential smoothing. Frame rate safe, never overshoots. Ideal for cameras.",
	usage = "kite.damp(source, 12)",
	example = [[
kite.create `Frame` {
	Position = kite.damp(function() return target() end, 14),
}]],
	see = { "spring", "tween" },
})

topic({
	name = "clock",
	summary = "A source that ticks once per frame with seconds since it was made.",
	usage = "const clock = kite.clock()",
	example = [[
const clock = kite.clock()

kite.create `ImageLabel` {
	Rotation = clock:map(function(t) return t * 90 end),
}]],
	see = { "spring" },
})

--> ["trees"]

topic({
	name = "create",
	summary = "Declares an instance. Strings keys are properties, functions are bindings, array entries are children.",
	usage = 'kite.create "TextLabel" { Text = "hi" }',
	example = [[
kite.create `Frame` {
	Name = `Card`,
	Size = UDim2.fromOffset(220, 120),
	BackgroundColor3 = `#112126`,

	-- a binding: a function, or a source handed straight over
	Text = function() return label() end,
	Visible = open,

	Activated = function() print(`clicked`) end,

	kite.create `UICorner` { CornerRadius = UDim.new(0, 10) },
	kite.create `TextLabel` { Text = `inside` },
}]],
	see = { "go", "mount", "on", "ref", "sugar" },
})

topic({
	name = "go",
	summary = "Builds the tree and puts it on screen. Build it, parent it, own it. One call.",
	usage = "const handle = kite.go(build)",
	example = [[
return kite.go(function()
	const count = kite.source(0)

	return kite.create `ScreenGui` {
		kite.create `TextLabel` { Text = count },
		kite.create `TextButton` {
			Text = "add one",
			Activated = function() count(count() + 1) end,
		},
	}
end)  -- parented to PlayerGui, owned, done]],
	see = { "mount", "create" },
})

topic({
	name = "mount",
	summary = "Builds a tree under a parent and gives you a handle that owns it. No parent means PlayerGui.",
	usage = "const handle = kite.mount(tree)",
	example = [[
const handle = kite.mount(kite.create `ScreenGui` {
	ResetOnSpawn = false,
	kite.create `TextLabel` { Text = `hello` },
}, playerGui)

handle:destroy()  -- everything, in order]],
	see = { "go", "hydrate", "create" },
})

topic({
	name = "hydrate",
	summary = "Takes over an instance that already exists in Studio, instead of building a new one.",
	usage = "kite.hydrate(tree, existingFrame)",
	example = [[
kite.hydrate(kite.create `Frame` {
	kite.keys(function() return rows() end, renderRow),
}, script.Parent.List)]],
	see = { "mount" },
})

topic({
	name = "on",
	summary = "Events, when you would rather name them. You can also just assign the handler to the event name.",
	usage = "kite.on { Activated = function() end }",
	example = [[
kite.create `TextButton` {
	Activated = function() print(`one`) end,
	kite.on { MouseButton2Click = function() print(`two`) end },
}]],
	see = { "create", "ref" },
})

topic({
	name = "ref",
	summary = "Keeps a handle on the instance you just declared.",
	usage = "const box = kite.ref()",
	example = [[
const box = kite.ref()

kite.create `TextBox` {
	kite.ref = box,
	ClearTextOnFocus = false,
}

box()            -- the TextBox
box():CaptureFocus()]],
	see = { "on", "create" },
})

topic({
	name = "sugar",
	summary = "Shorthands, in creative and performance mode. Strict mode refuses them on purpose.",
	usage = 'kite.mode "creative"',
	example = [[
kite.create `Frame` {
	size = { 220, 120 },       -- UDim2
	position = { 0.5, 0, 0.5, 0 },
	anchor = `center`,
	color = `#112126`,
	corner = 10,               -- a UICorner child
	padding = { 12, 16 },      -- a UIPadding child
	stroke = { `#2e5053`, 1 },
	gradient = { `#16303a`, `#112126` },
	list = `vertical`,
	scale = 1,
	aspect = 1.6,
}]],
	see = { "modes", "create" },
})

--> ["lists"]

topic({
	name = "keys",
	summary = "A list that reuses rows by identity. Rows keep their state when the list moves.",
	usage = "kite.keys(source, render, keyOf)",
	example = [[
kite.keys(function() return items() end, function(item, index)
	return kite.create `TextButton` {
		Text = function() return item().name end,
		Activated = function() pick(item()) end,
	}
end, function(item) return item.id end)]],
	see = { "indexes", "when", "switch" },
	note = "Kite writes LayoutOrder to reorder instead of reparenting. Use a UIListLayout with SortOrder = LayoutOrder.",
})

topic({
	name = "indexes",
	summary = "A list that reuses rows by position. Cheaper when the rows have no identity.",
	usage = "kite.indexes(source, render)",
	example = [[
kite.indexes(function() return lines() end, function(line, index)
	return kite.create `TextLabel` {
		Text = function() return line() end,
		TextColor3 = function() return if index() % 2 == 0 then `#7f9ba1` else `#eeeeee` end,
	}
end)]],
	see = { "keys", "when" },
})

topic({
	name = "when",
	summary = "One branch, mounted only while the condition is true.",
	usage = "kite.when(condition, element, fallback)",
	example = [[
kite.create `Frame` {
	kite.when(function() return loading() end,
		kite.create `TextLabel` { Text = `loading` },
		kite.create `TextLabel` { Text = `ready` }
	),
}]],
	see = { "switch", "keys" },
})

topic({
	name = "switch",
	summary = "Picks one branch out of a table of them.",
	usage = "kite.switch(source, { idle = ..., busy = ... }, fallback)",
	example = [[
kite.create `Frame` {
	kite.switch(function() return state() end, {
		idle = kite.create `TextLabel` { Text = `idle` },
		busy = kite.create `TextLabel` { Text = `working` },
	}, kite.create `TextLabel` { Text = `unknown` }),
}]],
	see = { "when", "keys" },
})

--> ["structure"]

topic({
	name = "component",
	summary = "A function that returns an element, plus a contract of what it accepts.",
	usage = 'kite.component("Card", builder, fields)',
	example = [[
const Card = kite.component(`Card`, function(props)
	return kite.create `Frame` {
		Size = kite.use(props, `size`, UDim2.fromOffset(220, 120)),
		kite.create `TextLabel` { Text = kite.use(props, `title`, ``) },
	}
end, {
	size = { type = `UDim2`, default = UDim2.fromOffset(220, 120) },
	title = { type = `string`, required = true },
})

Card { title = `hello` }]],
	see = { "create", "theme" },
})

topic({
	name = "theme",
	summary = "Named colour tokens that are sources. Switch the theme and the UI follows.",
	usage = 'kite.theme { dark = { ink = "#0d181b" }, light = { ink = "#f4f7f7" } }',
	example = [[
const theme = kite.theme {
	mode = `dark`,
	dark  = { ink = `#0d181b`, accent = `#3ddad7` },
	light = { ink = `#f4f7f7`, accent = `#0f8f8d` },
}

kite.create `TextLabel` { TextColor3 = theme.accent }
theme:set(`light`)]],
	see = { "component", "create" },
})

topic({
	name = "modes",
	summary = "Kite has three modes. They change what the compiler accepts and what the linter writes.",
	usage = 'kite.mode "creative"',
	example = [[
-- strict       nothing implicit, sugar is an error, guidance is loud
-- creative     sugar expands, types coerce, structure still checked
-- performance  nothing is checked, the linter reports cost instead

kite.mode `strict`
kite.strict(tree):print()]],
	see = { "lint", "sugar" },
})

topic({
	name = "lint",
	summary = "Reads a tree before you run it and reports in the mode you name.",
	usage = "kite.strict(tree):print()",
	example = [[
const report = kite.strict(tree)

if not report:isOk() then
	print(report:text())
end

-- reports come as text, json, or a standalone html file
print(report:html())]],
	see = { "modes", "profiler" },
})

topic({
	name = "profiler",
	summary = "Counters that were always running. Reads, writes, computes, mounts, motions.",
	usage = "print(kite.profiler():text())",
	example = [[
kite.profile(true)

const built = kite.measure(`shop`, function() return buildShop() end)
print(built.milliseconds)

print(kite.profiler():text())
print(kite.profiler():html())]],
	see = { "lint", "inspector" },
})

topic({
	name = "inspector",
	summary = "Draws what Kite built: the instance tree, the reactive graph, and a text dump.",
	usage = "print(kite.inspector(handle.instance):tree())",
	example = [[
const view = kite.inspector(handle.instance)

print(view:tree())
print(view:html())
print(view:graph(count))  -- the reactive graph behind a source]],
	see = { "profiler", "lint" },
})

topic({
	name = "help",
	summary = "This. Reads a topic straight into the output.",
	usage = 'kite.help("spring")',
	example = [[
kite.help()          -- every topic
kite.help(`keys`)    -- one topic with an example
kite.topics()        -- just the names]],
	see = { "modes" },
})

Docs.topics = topics

--> ["access"]

function Docs.has(name: string): boolean
	return topics[name] ~= nil
end

function Docs.get(name: string): Topic?
	return topics[name]
end

function Docs.list(): { string }
	return Util.sorted(Util.keys(topics))
end

function Docs.add(entry: Topic)
	topics[entry.name] = entry
end

--> ["render"]

const WIDTH = 74

local function rule(character: string): string
	return string.rep(character, WIDTH)
end

function Docs.render(name: string): string
	const entry = topics[name]

	if not entry then
		const nearest = Util.nearest(name, Docs.list())
		return table.concat({
			rule("-"),
			`kite.help("{name}")`,
			"",
			`Kite has no topic called "{name}".`,
			if nearest then `did you mean "{nearest}"?` else "", 
			"",
			`topics: {table.concat(Docs.list(), ", ")}`,
			rule("-"),
		}, "\n")
	end

	const lines = {
		rule("-"),
		`kite.help("{entry.name}")`,
		"",
	}

	for _, line in Util.wrap(entry.summary, WIDTH - 4) do
		table.insert(lines, `  {line}`)
	end

	table.insert(lines, "")

	if entry.usage then
		table.insert(lines, "  usage")
		table.insert(lines, `    {entry.usage}`)
		table.insert(lines, "")
	end

	if entry.example then
		table.insert(lines, "  example")
		for _, line in string.split(entry.example, "\n") do
			table.insert(lines, `    {line}`)
		end
		table.insert(lines, "")
	end

	if entry.note then
		table.insert(lines, "  note")
		for _, line in Util.wrap(entry.note, WIDTH - 6) do
			table.insert(lines, `    {line}`)
		end
		table.insert(lines, "")
	end

	if entry.see then
		table.insert(lines, `  see also: {table.concat(entry.see, ", ")}`)
	end

	table.insert(lines, rule("-"))

	return table.concat(lines, "\n")
end

function Docs.help(name: string?)
	if name == nil then
		print(Docs.index())
		return
	end

	print(Docs.render(name))
end

function Docs.index(): string
	const lines = {
		rule("-"),
		"kite.help()",
		"",
		"  Kite is a reactive UI package. These are the topics it can talk about.",
		`  ask for one with kite.help("spring").`,
		"",
	}

	const names = Docs.list()
	const columns = 3
	const width = math.floor(WIDTH / columns)

	for index = 1, #names, columns do
		const row = {}
		for offset = 0, columns - 1 do
			const entry = names[index + offset]
			if entry then
				table.insert(row, Util.pad(entry, width))
			end
		end
		table.insert(lines, `    {table.concat(row, "")}`)
	end

	table.insert(lines, "")
	table.insert(lines, rule("-"))

	return table.concat(lines, "\n")
end

return Docs
