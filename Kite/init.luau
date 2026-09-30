--!strict
--[=[
	--> ["Kite : v.0.1.0 : the wind took it"]
	made by Makel/Savi (@sacredludt or @.makel)

	--> ["paradigm"]
	Kite is a reactive UI package for Roblox.

	It is not a framework. It does not own your game, your folder layout,
	or your idea of a component. It gives you three shapes and one rule,
	and then it gets out of the way:

		source   a value that changes
		derive   a value that is computed
		effect   work that happens

	A derive and an effect remember what they read while they run. When
	one of those things changes, they run again. That is the whole model.

	--> ["origin"]
	Respect to Vide, and to Fusion before it. They proved reactive UI
	belongs in Roblox. Kite is what I wanted after using them: a source you
	call in one motion, a tree that compiles once, motion that shares a
	single frame connection, and a linter that answers like a person
	instead of a parser.

	--> ["what Kite does instead"]
	```text
	                       Vide                    Kite
	read and write         count()()  count()(v)   count()  count(v)
	springs                spring(fn, a, b)        spring(fn, { speed, damping })
	methods on sources     no                      count:map(count:watch(count:spring
	tree compiled          no                      yes, cached against the table
	shorthands             no                      yes, in creative mode
	lint modes             no                      strict, creative, performance
	profile and inspect    no                      yes, text, json, and html
	hover docs             no                      every public function
	```

	--> ["code"]
	code is a reflection of how we as humans operate.
	Kite is what happens when you stop fighting the library.

	--> ["identity"]
	i am confident.
	i am loving.
	i do not want.
	i understand.
	i speak it into existance.
	i create.

	i do not speak on what it FEELS like.

	I AM WHAT IT IS.
	AND I AM WHAT IT WILL BE.
	I AM THE SOUL THAT KITE IS.
	KITE IS ME.

	--> ["this is...kite"]
]=]

const Graph = require(script.Core.Graph)
const Scope = require(script.Core.Scope)
const Spring = require(script.Core.Spring)
const Mount = require(script.Core.Mount)
const Keys = require(script.Core.Keys)
const Compiler = require(script.Core.Compiler)
const Component = require(script.Core.Component)
const Theme = require(script.Core.Theme)
const Lint = require(script.Core.Lint)
const Profiler = require(script.Core.Profiler)
const Inspector = require(script.Core.Inspector)
const Docs = require(script.Core.Docs)
const Config = require(script.Core.Config)
const Types = require(script.Core.Types)
const Util = require(script.Core.Util)

--> ["wire"]
-- Spring adds :spring, :tween, and :damp to every source. Keys and
-- components teach Mount how to build their nodes. None of it is a cycle.

Spring.install(Graph)
Keys.register(Mount)
Component.register(Mount)

const Kite = {}

Kite.VERSION = "0.1.0"
Kite.AUTHOR = "Makel/Savi (@sacredludt or @.makel)"
Kite.SOURCE = "github.com/zqouva/Kite"

--> ["types"]

export type Source<T> = typeof(setmetatable({} :: {
	kind: string,
	value: T,
	get: (any) -> T,
	set: (any, T) -> (),
	map: (any, (T) -> any) -> any,
	watch: (any, (T) -> ()) -> () -> (),
}, Graph.Source))

export type Element = { [any]: any }
export type Handle = Mount.Handle
export type Report = Lint.Report
export type Topic = Docs.Topic

--> ["reactivity"]

--[=[
	Creates a source: a value Kite watches.

	Call it with nothing to read it. Call it with a value to write it.
	`count:set(v)` and `count:get()` are the explicit forms, and Studio
	shows every method as soon as you type `count:`.

	Example:
	```lua
	const count = kite.source(0)

	count()            -- 0
	count(4)           -- write
	count:set(5)       -- write, explicit
	count:update(function(v) return v + 1 end)

	kite.create `TextLabel` { Text = count }  -- sources bind directly
	```

	@param value any -- the starting value
	@param options table? -- `{ equals = function(a, b) end, name = string }`
	@return Source -- callable, with methods
]=]
function Kite.source(value: any, options: any?): any
	return Graph.source(value, options)
end

--[=[
	Creates a derive: a value that is computed from other values.

	It only recomputes when something it actually read has changed, and
	only when somebody is reading it. A derive nobody reads never runs.

	Example:
	```lua
	const hp = kite.source(100)

	const status = kite.derive(function()
		return if hp() > 0 then `alive` else `down`
	end)

	print(status())  -- `alive`
	hp(0)
	print(status())  -- `down`
	```

	@param fn function -- reads sources, returns a value
	@param options table? -- `{ equals, name }`
	@return Source -- read only
]=]
function Kite.derive(fn: () -> any, options: any?): any
	return Graph.derive(fn, options)
end

--[=[
	Creates an effect: work that runs now, and again whenever what it read
	changes.

	Return a function from it and Kite calls that function before the next
	run, so connections and instances clean themselves up.

	Example:
	```lua
	const stop = kite.effect(function()
		print(`count is`, count())
	end)

	count(2)  -- prints again
	stop()    -- never again
	```

	@param fn function -- runs immediately, re-runs on change
	@return any -- the effect node, destroy it with :destroy()
]=]
function Kite.effect(fn: () -> ()): any
	return Graph.effect(fn)
end

--[=[
	Groups writes so the graph settles once.

	Ten writes inside a batch cost one propagation pass. Outside a batch
	they cost ten.

	Example:
	```lua
	kite.batch(function()
		health(10)
		shield(0)
		ammo(30)
	end)  -- the UI updates once
	```

	@param fn function -- the block to run
	@return any -- whatever `fn` returned
]=]
function Kite.batch(fn: () -> any): any
	return Graph.batch(fn)
end

--[=[
	Reads inside the block without subscribing to them.

	Use it when you need a value *right now* but do not want this block to
	re-run when that value moves.

	Example:
	```lua
	kite.effect(function()
		const quiet = kite.untrack(function() return debugMode() end)
		if quiet then return end
		print(name())
	end)
	```

	@param fn function -- the block to run untracked
	@return any -- whatever `fn` returned
]=]
function Kite.untrack(fn: () -> any): any
	return Graph.untrack(fn)
end

--[=[
	Turns a plain table into a table of sources. Nested tables become
	nested records, so deep state stays reactive.

	Example:
	```lua
	const stats = kite.record { hp = 100, aura = { grace = 1 } }

	stats.hp(80)
	stats.aura.grace(4)

	kite.create `TextLabel` { Text = stats.hp }
	```

	@param values table -- any plain table
	@return table -- a record whose fields are sources
]=]
function Kite.record(values: { [string]: any }): any
	return Graph.record(values)
end

--[=[
	A scope owns things. Everything Kite creates inside it is destroyed
	when it dies, in reverse order.

	You rarely need this by hand: every mount, every effect run, and every
	keyed row already has one.

	Example:
	```lua
	const scope = kite.scope(function()
		kite.mount(tree, playerGui)
	end)

	scope:destroy()  -- the UI goes away
	```

	@param fn function -- runs inside a fresh scope
	@return any -- the scope
]=]
function Kite.scope(fn: () -> ()): any
	const scope = Scope.create("kite.scope")

	Scope.push(scope)
	const ok, reason = pcall(fn)
	Scope.pop()

	if not ok then
		Scope.destroy(scope)
		error(reason, 2)
	end

	return setmetatable({
		kind = "scope",
		scope = scope,
		destroy = function()
			Scope.destroy(scope)
		end,
	}, {
		__type = "Kite.Scope",
		__tostring = function()
			return "Kite.Scope"
		end,
	})
end

--[=[
	Registers work to run when the running scope dies.

	Example:
	```lua
	kite.effect(function()
		const connection = signal:Connect(onStuff)
		kite.cleanup(function() connection:Disconnect() end)
	end)
	```

	@param fn function -- the cleanup to run later
	@return function -- call it to unregister
]=]
function Kite.cleanup(fn: () -> ()): () -> ()
	return Scope.cleanup(fn)
end

--[=[
	True when the value came out of `kite.source` or `kite.derive`.

	@param value any
	@return boolean
]=]
function Kite.isSource(value: any): boolean
	return Graph.isNode(value)
end

--[=[
	Reads a source or derive without subscribing to it.

	@param node any -- a source or derive
	@return any -- the current value
]=]
function Kite.peek(node: any): any
	return Graph.peek(node)
end

--[=[
	Destroys a node, its scope, and everything it owned.

	@param node any -- a source, derive, or effect
]=]
function Kite.destroy(node: any)
	Graph.destroy(node)
end

--> ["motion"]

--[=[
	Physics motion. It overshoots, it settles, it feels like it weighs
	something.

	Hand it a source, or a function that reads sources. It gives you a
	something you can drop into any property. Works on numbers, Vector2,
	Vector3, UDim, UDim2, Color3, and CFrame.

	Example:
	```lua
	const open = kite.source(false)

	kite.create `Frame` {
		Position = kite.spring(function()
			return if open() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 1.2)
		end, { speed = 0.28, damping = 0.9 }),
	}

	-- or straight off the source
	const fade = open:spring(0.28)
	```

	@param target any -- a source, or a function returning a value
	@param options any -- `{ speed = 1, damping = 1, precision = 0.0015 }`, or just a speed number
	@return any -- a source holding the moving value
]=]
function Kite.spring(target: any, options: any, third: any): any
	return Spring.spring(target, options, third)
end

--[=[
	Time based motion with an easing curve. Exact duration, no surprises.

	Example:
	```lua
	kite.create `Frame` {
		BackgroundTransparency = kite.tween(function()
			return if open() then 0.1 else 1
		end, { time = 0.24, ease = kite.ease.CubicOut }),
	}
	```

	@param target any -- a source, or a function returning a value
	@param options any -- `{ time = 0.3, ease = kite.ease.QuadOut }`, or just a duration
	@return any -- a source holding the moving value
]=]
function Kite.tween(target: any, options: any, third: any): any
	return Spring.tween(target, options, third)
end

--[=[
	Exponential smoothing. Frame rate safe and it never overshoots, which
	is why cameras and follow cursors like it.

	Example:
	```lua
	kite.create `Frame` {
		Position = kite.damp(function() return target() end, 14),
	}
	```

	@param target any -- a source, or a function returning a value
	@param rate any -- higher is snappier, or `{ speed = 12, precision = 0.001 }`
	@return any -- a source holding the moving value
]=]
function Kite.damp(target: any, options: any, third: any): any
	return Spring.damp(target, options, third)
end

--[=[
	A source that ticks once per frame with the seconds since it was made.

	Every clock in your game shares one frame connection with every spring.

	Example:
	```lua
	const clock = kite.clock()

	kite.create `ImageLabel` {
		Rotation = clock:map(function(t) return t * 90 end),
	}
	```

	@return any -- a source of seconds
]=]
function Kite.clock(): any
	return Spring.clock()
end

--[=[
	Easing curves, by name: Linear, Quad, Cubic, Quart, Quint, Sine, Expo,
	Circ, Back, Elastic, Bounce. Each one comes as `Name`, `NameIn`,
	`NameOut`, and `NameInOut`.

	Example:
	```lua
	kite.tween(source, { time = 0.3, ease = kite.ease.BackOut })
	```
]=]
Kite.ease = Spring.ease

--> ["trees"]

--[=[
	Declares an instance.

	String keys are properties. A function or a source is a binding. Array
	entries and `kite.children` are children. Event names take handlers.

	Example:
	```lua
	kite.create `Frame` {
		Name = `Card`,
		Size = UDim2.fromOffset(220, 120),
		BackgroundColor3 = `#112126`,

		Text = function() return label() end,  -- a binding
		Visible = open,                        -- a source, bound directly
		Activated = function() print(`hi`) end,

		kite.create `UICorner` { CornerRadius = UDim.new(0, 10) },
	}
	```

	@param className string -- any Roblox class: `Frame`, `TextLabel`, ...
	@return function -- call it with the props table
]=]
function Kite.create(className: string, props: { [any]: any }?): any
	if props ~= nil then
		return Mount.element(className, props)
	end
	return Mount.create(className)
end

--[=[
	Declares an instance in one call, instead of `kite.create `Frame` { }`.

	Example:
	```lua
	kite.new(`TextLabel`, { Text = `hi` })
	```

	@param className string
	@param props table? -- properties, bindings, and children
	@return any -- the element
]=]
function Kite.new(className: string, props: { [any]: any }?): any
	return Mount.element(className, props)
end

--[=[
	Builds the tree and puts it on screen. That is the whole ceremony.

	The function runs inside a scope, so every source, derive, effect, and
	spring you make in it dies with the tree. Nothing to tear down by hand.

	No parent? It goes to PlayerGui.

	Example:
	```lua
	const Kite = require(ReplicatedStorage.Packages.Kite)

	return Kite.go(function()
		const count = Kite.source(0)

		return Kite.create `ScreenGui` {
			Name = `Counter`,

			Kite.create `TextLabel` {
				Text = count,
			},

			Kite.create `TextButton` {
				Text = `add one`,
				Activated = function() count(count() + 1) end,
			},
		}
	end)
	```

	@param build function -- returns the tree
	@param options table? -- `{ mode = `strict`, name = `hud`, parent = someFrame }`
	@return Handle -- `{ instance, destroy, find, wait }`
]=]
function Kite.go(build: () -> any, options: any?): any
	return Mount.go(build, options)
end

--[=[
	Where trees go when you do not say. PlayerGui, cached.

	@return Instance
]=]
function Kite.home(): any
	return Mount.home()
end

--[=[
	Builds a tree under a parent and gives you a handle that owns every
	instance, connection, and motion inside it.

	Leave the parent out and it goes to PlayerGui. `kite.go` is shorter if
	you are writing the whole screen at once.

	The tree is compiled once and cached, so mounting the same table twice
	is a table lookup the second time.

	Example:
	```lua
	const handle = kite.mount(kite.create `ScreenGui` {
		ResetOnSpawn = false,
		kite.create `TextLabel` { Text = `hello` },
	})

	handle:destroy()
	handle:find(`TextLabel`)
	```

	@param element any -- from kite.create
	@param parent Instance? -- where it goes, defaults to PlayerGui
	@param options table? -- `{ mode = `strict`, name = `hud` }`
	@return Handle -- `{ instance, destroy, find, wait }`
]=]
function Kite.mount(element: any, parent: Instance?, options: any?): any
	return Mount.mount(element, parent, options)
end

--[=[
	Takes over an instance that already exists, instead of building a new
	one. Use it when the frame was laid out in Studio and Kite should fill
	it.

	Example:
	```lua
	kite.hydrate(kite.create `Frame` {
		kite.keys(function() return rows() end, renderRow),
	}, script.Parent.List)
	```

	@param element any -- the tree to apply
	@param instance Instance -- the instance to apply it to
	@return Handle
]=]
function Kite.hydrate(element: any, instance: Instance): any
	return Mount.hydrate(element, instance)
end

--[=[
	Drops a real instance into a Kite tree, so Studio made frames and Kite
	made frames can live in the same list.

	@param instance Instance
	@return any -- the element
]=]
function Kite.instance(instance: Instance): any
	return Mount.from(instance)
end

--[=[
	Keeps a handle on the instance you just declared.

	`kite.ref()` makes one. `kite.ref` as a key attaches it.

	Example:
	```lua
	const box = kite.ref()

	kite.create `TextBox` {
		kite.ref = box,
		ClearTextOnFocus = false,
	}

	box()              -- the TextBox
	box():CaptureFocus()
	```

	@return any -- call it to get the instance
]=]
--[=[
	Mounts a tree into a different part of the hierarchy while it stays
	owned by the scope it was written in. Tooltips, drag layers, world
	space UI.

	Example:
	```lua
	kite.create `Frame` {
		kite.portal(kite.create `TextLabel` { Text = `floating` }, game.Players.LocalPlayer.PlayerGui),
	}
	```

	@param element any
	@param target Instance -- where it should actually live
	@return any
]=]
function Kite.portal(element: any, target: Instance): any
	return Mount.portal(element, target)
end

--> ["lists"]

--[=[
	A list that reuses rows by identity, so a row keeps its state when the
	list reorders.

	The third argument is the key function. Without it Kite matches rows by
	value, which is fine for strings and wrong for tables.

	Kite reorders by writing `LayoutOrder` instead of reparenting, so use a
	`UIListLayout` with `SortOrder = Enum.SortOrder.LayoutOrder`.

	Example:
	```lua
	kite.keys(function() return items() end, function(item, index)
		return kite.create `TextButton` {
			Text = function() return item().name end,
			Activated = function() pick(item()) end,
		}
	end, function(item) return item.id end)
	```

	@param source any -- a source or function returning an array
	@param render function -- `(item, index) -> element`, item is a source
	@param keyOf function? -- `(item) -> key`
	@return any -- the list node
]=]
function Kite.keys(source: any, render: any, keyOf: any?): any
	return Keys.keys(source, render, keyOf)
end

--[=[
	A list that reuses rows by position. Cheaper than `kite.keys` when rows
	have no identity, and the right answer for log lines.

	Example:
	```lua
	kite.indexes(function() return lines() end, function(line, index)
		return kite.create `TextLabel` { Text = line }
	end)
	```

	@param source any -- a source or function returning an array
	@param render function -- `(item, index) -> element`
	@return any -- the list node
]=]
function Kite.indexes(source: any, render: any): any
	return Keys.indexes(source, render)
end

--[=[
	Mounts one branch while a condition is true, and unmounts it after.

	Example:
	```lua
	kite.create `Frame` {
		kite.when(function() return loading() end,
			kite.create `TextLabel` { Text = `loading` },
			kite.create `TextLabel` { Text = `ready` }
		),
	}
	```

	@param condition any -- a source or function
	@param element any -- mounted while true
	@param fallback any? -- mounted while false
	@return any -- the branch node
]=]
function Kite.when(condition: any, element: any, fallback: any?): any
	return Keys.when(condition, element, fallback)
end

--[=[
	Picks one branch out of a table of them, by value.

	Example:
	```lua
	kite.switch(function() return state() end, {
		idle = kite.create `TextLabel` { Text = `idle` },
		busy = kite.create `TextLabel` { Text = `working` },
	}, kite.create `TextLabel` { Text = `unknown` })
	```

	@param source any -- a source or function returning a key
	@param cases table -- key -> element
	@param fallback any? -- element when nothing matches
	@return any -- the branch node
]=]
function Kite.switch(source: any, cases: { [any]: any }, fallback: any?): any
	return Keys.switch(source, cases, fallback)
end

--[=[
	Re-renders a block whenever anything it reads changes. The escape hatch
	for the rare case `keys` and `when` do not cover.

	Example:
	```lua
	kite.create `Frame` {
		function()
			if mode() == `list` then return listTree() else return gridTree() end
		end,
	}
	```

	@param render function -- returns an element or an array of them
	@return any -- the dynamic node
]=]
function Kite.dynamic(render: any): any
	return Keys.dynamic(render)
end

--> ["components"]

--[=[
	Defines a component: a function that returns an element, plus a
	contract of what it accepts.

	Spell a prop wrong and Kite names the component, the prop, and the
	shape it wanted.

	Example:
	```lua
	const Card = kite.component(`Card`, function(props)
		return kite.create `Frame` {
			Size = kite.use(props, `size`, UDim2.fromOffset(220, 120)),
			kite.create `TextLabel` { Text = kite.use(props, `title`, ``) },
		}
	end, {
		size  = { type = `UDim2`, default = UDim2.fromOffset(220, 120) },
		title = { type = `string`, required = true },
	})

	Card { title = `hello` }
	```

	@param name string -- used in every error message
	@param build function -- `(props) -> element`
	@param fields table? -- `{ name = { type, default, required } }`
	@return any -- call it with props to get an element
]=]
function Kite.component(name: string, build: any, fields: any?): any
	return Component.define(name, build, fields)
end

--[=[
	Reads a prop as something you can put in a property, whether the caller
	passed a plain value, a source, or nothing at all.

	Example:
	```lua
	kite.create `TextLabel` { Text = kite.use(props, `title`, `untitled`) }
	```

	@param props table
	@param key string
	@param fallback any
	@return function -- a binding
]=]
function Kite.use(props: { [any]: any }, key: string, fallback: any): any
	return Component.use(props, key, fallback)
end

--[=[
	Reads a prop as a plain value, calling it if it happens to be a
	binding.

	@param props table
	@param key string
	@param fallback any
	@return any -- the value, right now
]=]
function Kite.value(props: { [any]: any }, key: string, fallback: any): any
	return Component.value(props, key, fallback)
end

--> ["theme"]

--[=[
	Makes a theme: named colour tokens that are sources.

	Switch the theme and every property that read a token updates. No
	re-render, no extra work, no prop drilling.

	Example:
	```lua
	const theme = kite.theme {
		mode = `dark`,
		dark  = { ink = `#0d181b`, accent = `#3ddad7` },
		light = { ink = `#f4f7f7`, accent = `#0f8f8d` },
	}

	kite.create `TextLabel` { TextColor3 = theme.accent }

	theme:set(`light`)
	theme:toggle()
	```

	@param palettes table -- `{ mode = `dark`, dark = {...}, light = {...} }`, or one flat palette
	@return any -- the theme: `theme.accent`, `theme:get(`accent`)`, `theme:set(`light`)`
]=]
function Kite.theme(palettes: { [any]: any }): any
	return Theme.define(palettes)
end

--> ["modes and guidance"]

--[=[
	Sets the mode Kite compiles and lints in.

	- `strict` — nothing implicit. Sugar is an error, types are checked,
	  guidance is loud. Ship with this.
	- `creative` — sugar expands, types coerce, structure is still checked.
	  Build with this.
	- `performance` — nothing is checked, the linter talks about cost.
	  Measure with this.

	Example:
	```lua
	kite.mode `strict`
	kite.mode `creative`
	```

	@param mode string -- `strict` | `creative` | `performance`
]=]
function Kite.mode(mode: string)
	Config.apply(mode)
end

--[=[
	The mode Kite is in right now.

	@return string
]=]
function Kite.modeOf(): string
	return Config.mode
end

--[=[
	Turns the plan cache on or off.

	On, Kite compiles a tree once and reuses the plan every time it sees
	that table again. Off, it walks the tree every mount.

	@param state boolean
]=]
function Kite.cache(state: boolean)
	Config.cache = state
	if not state then
		Compiler.forget()
	end
end

--[=[
	Reads a tree before you run it, in one of the three modes, and hands
	back a report.

	Example:
	```lua
	const report = kite.strict(tree)

	if not report:isOk() then
		print(report:text())
	end

	print(report:html())  -- standalone, no dependencies
	```

	@param tree any -- from kite.create
	@param options table? -- `{ maxDepth = 8, maxInstances = 160 }`
	@return Report -- `:text()`, `:html()`, `:json()`, `:isOk()`, `:print()`
]=]
function Kite.strict(tree: any, options: any?): any
	return Lint.strict(tree, options)
end

--[=[
	Same as `kite.strict`, in creative mode: sugar is allowed, structure is
	still checked.

	@param tree any
	@param options table?
	@return Report
]=]
function Kite.creative(tree: any, options: any?): any
	return Lint.creative(tree, options)
end

--[=[
	Same as `kite.strict`, in performance mode: correctness is skipped, and
	cost is what gets reported.

	@param tree any
	@param options table?
	@return Report
]=]
function Kite.performance(tree: any, options: any?): any
	return Lint.performance(tree, options)
end

--[=[
	Reads a tree in whichever mode you name.

	@param tree any
	@param mode string? -- defaults to the current mode
	@param options table?
	@return Report
]=]
function Kite.lint(tree: any, mode: string?, options: any?): any
	return Lint.inspect(tree, mode, options)
end

--[=[
	Teaches Kite about a class it does not know, so the linter can help
	with it too.

	Example:
	```lua
	kite.know(`ShinyFrame`, `Frame`, { Glow = `number` })
	```

	@param className string
	@param parent string? -- `Frame`, `GuiObject`, `Instance`, ...
	@param props table -- `{ PropertyName = `type` }`
	@param events table? -- `{ `EventName` }`
]=]
function Kite.know(className: string, parent: string?, props: { [string]: string }, events: { [string]: string }?)
	Types.learn(className, parent, props, events)
end

--[=[
	Compiles a tree once and gives you the plan, so you can mount the same
	plan many times without walking the table again.

	Example:
	```lua
	const plan = kite.compile(row)
	```

	@param tree any
	@return table -- the plan
]=]
function Kite.compile(tree: any): any
	return Compiler.compile(tree)
end

--> ["profiler and inspector"]

--[=[
	Turns profiling on. The counters run either way; this is about whether
	Kite says so in its reports.

	@param state boolean?
]=]
function Kite.profile(state: boolean?)
	Profiler.enable(state)
end

--[=[
	Times one call, and gives you both the result and how long it took.

	Example:
	```lua
	const built = kite.measure(`shop`, function() return buildShop() end)
	print(built.milliseconds)
	print(built.value)
	```

	@param label string
	@param fn function
	@return any -- `{ label, milliseconds, value }`
]=]
function Kite.measure(label: string, fn: () -> any): any
	return Profiler.measure(label, fn)
end

--[=[
	Reads every counter in the package: graph, mount, compile, keys, motion,
	components, and scopes.

	Example:
	```lua
	print(kite.profiler():text())
	print(kite.profiler():html())
	print(kite.profiler():json())
	kite.profiler():reset()
	```

	@return any -- `:text()`, `:html()`, `:json()`, `:snapshot()`, `:reset()`
]=]
function Kite.profiler(): any
	return Profiler.report()
end

--[=[
	Looks at what Kite built, after it built it.

	Example:
	```lua
	const view = kite.inspector(handle.instance)

	print(view:tree())         -- the instance tree
	print(view:html())         -- standalone report
	print(view:dump())         -- one instance, its properties
	print(view:graph(count))   -- the reactive graph behind a source
	print(view:dot(count))     -- graphviz
	```

	@param instance Instance
	@return any -- the inspector
]=]
function Kite.inspector(instance: Instance): any
	return Inspector.of(instance)
end

--> ["help"]

--[=[
	Reads a topic straight into the output, with an example you can paste.

	Example:
	```lua
	kite.help()          -- every topic
	kite.help(`spring`)  -- one topic
	kite.topics()        -- just the names
	```

	@param name string? -- omit for the index
]=]
function Kite.help(name: string?)
	Docs.help(name)
end

--[=[
	Every topic `kite.help` can talk about.

	@return { string }
]=]
function Kite.topics(): { string }
	return Docs.list()
end

--[=[
	Adds a topic to `kite.help`, so your own components can document
	themselves the same way Kite does.

	@param entry table -- `{ name, summary, usage, example, see, note }`
]=]
function Kite.teach(entry: { [string]: any })
	Docs.add(entry :: any)
end

--[=[
	The same thing `kite.help` prints, handed back as a string, so your own
	console, your own docs panel, or your own command palette can show it.

	Example:
	```lua
	print(Kite.topic(`spring`))
	print(Kite.topic())          -- the index of every topic
	```

	@param name string? -- omit for the index
	@return string
]=]
function Kite.topic(name: string?): string
	if name == nil then
		return Docs.index()
	end
	return Docs.render(name)
end

--> ["math and color"]
-- Small helpers that come up in every UI file.

function Kite.clamp(value: number, low: number, high: number): number
	return Util.clamp(value, low, high)
end

function Kite.lerp(from: number, to: number, alpha: number): number
	return Util.lerp(from, to, alpha)
end

function Kite.map(value: number, inLow: number, inHigh: number, outLow: number, outHigh: number): number
	return Util.map(value, inLow, inHigh, outLow, outHigh)
end

--[=[
	Turns ``#3ddad7``, ``3ddad7``, ``#3dd``, or `{ r, g, b }` into a Color3.

	@param source any
	@return Color3
]=]
function Kite.hex(source: any): Color3
	return Util.hex(source)
end

--[=[
	Builds a UDim2 from a shorthand: `kite.size(220, 120)`,
	`kite.size { 0, 220, 0, 120 }`, `kite.size `fill``.

	@param source any
	@return UDim2
]=]
function Kite.size(source: any, second: any, third: any, fourth: any): UDim2
	if second == nil and third == nil and fourth == nil then
		return Util.size(source)
	end
	return UDim2.new(source, second, third, fourth)
end

--[=[
	Builds a UDim from a number or `{ scale, offset }`.

	@param source any
	@return UDim
]=]
function Kite.padding(source: any): UDim
	return Util.padding(source)
end

--[=[
	Builds a Vector2 from a number, `{ x, y }`, or a named anchor like
	``center``, ``top``, ``bottom``, ``left``, ``right``.

	@param source any
	@return Vector2
]=]
function Kite.anchor(source: any, second: any?): Vector2
	if typeof(source) == "number" then
		return Vector2.new(source, second or source)
	end
	if typeof(source) == "string" then
		if source == "center" then
			return Vector2.new(0.5, 0.5)
		end
		if source == "top" then
			return Vector2.new(0.5, 0)
		end
		if source == "bottom" then
			return Vector2.new(0.5, 1)
		end
		if source == "left" then
			return Vector2.new(0, 0.5)
		end
		if source == "right" then
			return Vector2.new(1, 0.5)
		end
	end
	if typeof(source) == "table" then
		return Vector2.new((source :: any)[1] or (source :: any).x or 0, (source :: any)[2] or (source :: any).y or 0)
	end
	return Vector2.new(0, 0)
end

--[=[
	Capitalises a word, which is what every label made out of a key needs.

	@param text string
	@return string
]=]
function Kite.title(text: string): string
	return Util.title(text)
end

--> ["special keys"]
-- These are the keys that are not properties. Each one is callable, so it
-- reads the way you would say it, and each one also works as a computed
-- key if that is how you like to write it.
--
--   kite.on { Activated = fn }     [kite.on] = { Activated = fn }
--   kite.ref(box)                  [kite.ref] = box
--   kite.attr { Rank = 3 }         [kite.attr] = { Rank = 3 }
--   kite.tags { `Hud` }            [kite.tags] = { `Hud` }
--   kite.children { ... }          [kite.children] = { ... }
--   kite.bind { Text = fn }        [kite.bind] = { Text = fn }
--   kite.live(function(inst) end)  [kite.live] = function(inst) end
--   kite.key(value)                [kite.key] = value

const markers = Compiler.markers

local function expose(name: string): any
	return setmetatable({}, {
		__type = "Kite.Special",
		__index = markers[name],
		__call = function(_self: any, value: any)
			return (markers[name] :: any)(value)
		end,
		__tostring = function()
			return `kite.{name}`
		end,
	})
end

--[=[
	Attaches event handlers by name.

	Example:
	```lua
	kite.create `TextButton` {
		kite.on {
			Activated = function() print(`one`) end,
			MouseButton2Click = function() print(`two`) end,
		},
	}
	```

	Assigning the handler straight to the event name works too.
]=]
Kite.on = expose("on")

--[=[
	Sets attributes on the instance.

	Example:
	```lua
	kite.create `Frame` { kite.attr { Rank = 3, Title = `witness` } }
	```
]=]
Kite.attr = expose("attr")

--[=[
	Adds CollectionService tags.

	Example:
	```lua
	kite.create `Frame` { kite.tags { `Hud`, `Animated` } }
	```
]=]
Kite.tags = expose("tags")

--[=[
	Children, when you would rather name them than line them up.

	Example:
	```lua
	kite.create `Frame` { kite.children { kite.create `TextLabel` { Text = `hi` } } }
	```
]=]
Kite.children = expose("children")

--[=[
	Bindings, written out instead of handed over as functions.

	Example:
	```lua
	kite.create `TextLabel` { kite.bind { Text = function() return label() end } }
	```
]=]
Kite.bind = expose("bind")

--[=[
	The identity of a row inside `kite.keys`.

	Example:
	```lua
	kite.create `TextButton` { kite.key(item().id) }
	```
]=]
Kite.key = expose("key")

--[=[
	Runs a function with the instance once it exists, and cleans up after it.

	Example:
	```lua
	kite.create `TextBox` {
		kite.live(function(instance)
			instance:CaptureFocus()
			return function() instance:ReleaseFocus() end
		end),
	}
	```
]=]
Kite.live = expose("live")

--[=[
	Attaches a ref. Call it with nothing to make one, call it with a ref
	inside a props table to attach it.

	Example:
	```lua
	const box = kite.ref()

	kite.create `TextBox` {
		kite.ref(box),
		ClearTextOnFocus = false,
	}

	box()            -- the TextBox
	box():CaptureFocus()
	```
]=]
Kite.ref = setmetatable({}, {
	__type = "Kite.Special",
	__index = markers.ref,
	__call = function(_self: any, value: any)
		if value == nil then
			return Mount.ref()
		end
		return (markers.ref :: any)(value)
	end,
	__tostring = function()
		return "kite.ref"
	end,
})

--> ["stats"]

function Kite.stats()
	return {
		version = Kite.VERSION,
		mode = Config.mode,
		graph = Graph.stats(),
		mount = Mount.stats(),
		compile = Compiler.stats(),
		keys = Keys.stats(),
		motion = Spring.stats(),
		component = Component.stats(),
		theme = Theme.stats(),
		scope = Scope.stats(),
	}
end

--[=[
	Drops every compiled plan. Only needed if you mutate trees after
	mounting them, which you should not.

	@return number -- how many plans were dropped
]=]
function Kite.forget(): number
	const before = Compiler.stats().cached
	Compiler.forget()
	return before
end

return Kite
