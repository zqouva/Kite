# Kite : v.0.1.0 : the wind took it
made by Makel/Savi (@sacredludt or @.makel)

`--> ["what this is"]`

Kite is a reactive UI package for Roblox.

It is not a framework. It does not own your game, your folder layout, or your
idea of what a component is. It gives you three shapes and one rule, and then
it gets out of the way.

```text
source   a value that changes
derive   a value that is computed
effect   work that happens
```

**The rule:** a derive and an effect remember what they read while they run.
When one of those things changes, they run again. That is the whole model.

```lua
const Kite = require(ReplicatedStorage.Packages.Kite)

Kite.go(function()
	const count = Kite.source(0)               -- a value that changes
	const doubled = count:map(function(v)      -- a value that is computed
		return v * 2
	end)

	return Kite.create("TextLabel", {
		Text = doubled,                        -- bound, not wired
	})
end)

-- it is on screen. count(4) and the label says 8
```

No dependency arrays. No manual cleanup. No diffing. No `:setState`.

---

`--> ["why it exists"]`

Respect to Vide, and to Fusion before it. They proved reactive UI belongs in
Roblox, and Vide in particular proved it can be small.

Kite is what I wanted after using them:

```text
                          what bugged me                       what Kite does
reading and writing       count()() / count()(v)  clunky      count() / count(4)
methods on a source       none, it is all free functions      count:map  count:watch  count:spring
tree cost                 walked again on every mount         compiled once, cached against the table
mounting                  mount(fn, parent) and a handle      kite.go(fn), parent defaults to PlayerGui
shorthands                none                                padding = 12  corner = 8  color = "#112126"
mistakes                  runtime errors from Roblox          "Frame has no property called Text"
motion                    a connection per property           one connection for every motion in the game
performance               trust me                            three lint modes, a profiler, and an inspector
learning it               read the source                     hover any function, or kite.help("spring")
```

Vide is good. Kite is what I wanted Vide to feel like.

---

`--> ["package shape"]`

```text
Kite/
  init.luau
  README.md
  Core/
    Graph.luau        the reactive engine: source, derive, effect, batch
    Scope.luau        ownership, cleanup, destroy
    Spring.luau       spring, tween, damp, clock, easing
    Types.luau        what actually exists on a Roblox Instance
    Config.luau       the three modes
    Compiler.luau     trees -> plans, cached
    Mount.luau        plans -> instances
    Keys.luau         keys, indexes, when, switch, dynamic
    Component.luau    components with contracts
    Theme.luau        colour tokens that are sources
    Lint.luau         strict, creative, performance
    Profiler.luau     counters, measure, reports
    Inspector.luau    tree, graph, and html reports
    Docs.luau         the text behind hover and kite.help
    Util.luau         small helpers
  Examples/
    Counter.client.luau      the whole model in one file
    CommandBar.client.luau   a real screen: log, autocomplete, history
    Inventory.client.luau    keys, components, theme switching
    Boot.client.luau         the workflow: build, lint, profile, ask
    Benchmarks/
      BenchmarksVSvide.client.luau
  Validation/
    ReactivityValidation.client.luau
    MountValidation.client.luau
    LintValidation.client.luau
    ProfilerValidation.client.luau
    README.md
    StudioChecklist.md
```

---

`--> ["install"]`

```text
ReplicatedStorage/
  Packages/
    Kite/          <- this folder
```

or drag `Releases/Kite 0.1.0.rbxmx` into Studio and drop the folder in
ReplicatedStorage.

```lua
const Kite = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Kite"))
```

---

`--> ["the three shapes"]`

## source

A value Kite watches.

```lua
const count = Kite.source(0)

count()          -- 0        read
count(4)         -- 4        write, same call
count:set(5)     --          write, explicit
count:get()      -- 5        read, explicit
count:update(function(v) return v + 1 end)
count:toggle()   --          booleans only
count:peek()     --          read without subscribing
```

`count:map`, `count:watch`, `count:spring`, `count:tween`, `count:damp`,
`count:when`, `count:pick`, `count:tostring`, `count:name`,
`count:dependencies`, `count:watchers`, `count:destroy`.

Type `count:` in Studio and the whole list shows up. That is the point.

## derive

A value computed from other values.

```lua
const hp = Kite.source(100)

const status = Kite.derive(function()
	return if hp() > 0 then "alive" else "down"
end)

status()   -- "alive"
hp(0)
status()   -- "down"
```

A derive is **lazy**: a derive nobody reads never computes, and a derive whose
value lands on the same thing never wakes anything downstream.

## effect

Work that happens.

```lua
const stop = Kite.effect(function()
	print("hp is", hp())
end)

hp(50)   -- prints again
stop()   -- never again
```

Return a function and Kite calls it before the next run, so connections and
instances clean themselves up.

```lua
Kite.effect(function()
	const connection = signal:Connect(onThing)
	return function()
		connection:Disconnect()
	end
end)
```

---

`--> ["batching"]`

Ten writes outside a batch cost ten propagation passes. Inside a batch they
cost one, and no effect ever sees half a change.

```lua
Kite.batch(function()
	health(10)
	shield(0)
	ammo(30)
end)  -- the UI settles once
```

Effects run **shallowest first**, so a parent has always settled before
anything that depends on it runs.

---

`--> ["trees"]`

A tree is a plain table. String keys are properties, a function or a source is
a binding, array entries are children.

```lua
const Card = Kite.create("Frame", {
	Name = "Card",
	Size = UDim2.fromOffset(220, 120),
	BackgroundColor3 = "#112126",

	-- bindings
	Text = function() return label() end,   -- a function
	Visible = open,                         -- a source, bound directly
	Rotation = angle:spring(0.3),           -- a motion

	-- events
	Activated = function() print("hi") end,

	-- children
	Kite.create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	Kite.create("TextLabel", { Text = "inside" }),
})

const handle = Kite.mount(Card)

handle:destroy()             -- everything, in order
handle:find("TextLabel")     -- Instance?
```

`Kite.create "Frame" { ... }` works too, if you like the call style.

## special keys

Each one is callable, so it reads the way you would say it, and each one also
works as a computed key.

```lua
Kite.create("Frame", {
	kite.on { Activated = fn }              [kite.on] = { Activated = fn }
	kite.ref(box)                           [kite.ref] = box
	kite.attr { Rank = 3 }                  [kite.attr] = { Rank = 3 }
	kite.tags { "Hud" }                     [kite.tags] = { "Hud" }
	kite.children { ... }                   [kite.children] = { ... }
	kite.bind { Text = fn }                 [kite.bind] = { Text = fn }
	kite.live(function(inst) end)           [kite.live] = fn
	kite.key(value)                         [kite.key] = value
})
```

In the package the namespace is `Kite`, so it is `Kite.on { ... }` and
`Kite.ref(box)`.

## mounting and taking over

```lua
Kite.go(function() return tree end)     -- build it, parent it, own it
Kite.mount(tree)                        -- or mount it yourself
Kite.mount(tree, parent, { mode = "strict" })
Kite.hydrate(tree, existingFrame)       -- take over something built in Studio
Kite.instance(realInstance)             -- drop one into a Kite tree
Kite.portal(tree, somewhereElse)        -- own it here, parent it there
Kite.compile(tree)                      -- plan it once, mount it many times
```

---

`--> ["lists"]`

```lua
-- by identity: rows keep their state when the list moves
Kite.keys(function() return items() end, function(item, index)
	return Kite.create("TextButton", {
		Text = function() return item().name end,
		Activated = function() pick(item()) end,
	})
end, function(item) return item.id end)

-- by position: cheaper when rows have no identity
Kite.indexes(function() return lines() end, function(line, index)
	return Kite.create("TextLabel", { Text = line })
end)

-- one branch
Kite.when(loading(), spinner, content)

-- one of many
Kite.switch(state, { idle = idleView, busy = busyView }, fallback)

-- the escape hatch
function()
	if mode() == "list" then return listTree() else return gridTree() end
end
```

`item` and `line` are **sources**: call them to read. `index` is a plain
number, so `LayoutOrder = index` just works.

Kite reorders by writing `LayoutOrder`, never by reparenting, so a moving row
costs one number instead of a tree rebuild. Give the list a `UIListLayout`
with `SortOrder = Enum.SortOrder.LayoutOrder`.

---

`--> ["motion"]`

```lua
const open = Kite.source(false)

Kite.create("Frame", {
	Position = Kite.spring(function()
		return if open() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 1.2)
	end, { speed = 0.28, damping = 0.9 }),

	BackgroundTransparency = open:tween({ time = 0.24, ease = Kite.ease.CubicOut }),

	Rotation = Kite.clock():map(function(t) return t * 90 end),

	CanvasPosition = Kite.damp(follow, 14),
})
```

- `spring` — physics. Overshoots, settles, feels like it weighs something.
- `tween` — exact duration, eased. `Kite.ease` has Linear, Quad, Cubic, Quart,
  Quint, Sine, Expo, Circ, Back, Elastic, Bounce, each as `Name`, `NameIn`,
  `NameOut`, `NameInOut`.
- `damp` — exponential, never overshoots. Cameras like it.
- `clock` — a source of seconds, one per frame.

All four work on numbers, Vector2, Vector3, UDim, UDim2, Color3, and CFrame.
All four share **one** frame connection, however many you make, and the driver
disconnects itself when nothing is moving.

---

`--> ["components"]`

A component is a function and a contract. The contract is what makes a typo
into a sentence.

```lua
const Card = Kite.component("Card", function(props)
	return Kite.create("Frame", {
		Size = Kite.use(props, "size", UDim2.fromOffset(220, 120)),
		Kite.create("TextLabel", { Text = Kite.use(props, "title", "") }),
	})
end, {
	size  = { type = "UDim2", default = UDim2.fromOffset(220, 120) },
	title = { type = "string", required = true },
})

Card { title = "hello" }
-- Card { titel = "hello" }
--   [Kite] Card does not take a prop called "titel".
--     did you mean "title"?
--     Card takes: size = ..., title = ...
-- Card {}
--   [Kite] Card needs "title" and you did not pass it.
--     Card { title = <string> }
```

`Kite.use(props, key, fallback)` hands you something you can drop into any
property, whether the caller passed a value, a source, or nothing.
`Kite.value(props, key, fallback)` hands you the plain value, right now.

---

`--> ["theme"]`

```lua
const theme = Kite.theme {
	mode = "dark",
	dark  = { ink = "#0d181b", accent = "#3ddad7" },
	light = { ink = "#f4f7f7", accent = "#0f8f8d" },
}

Kite.create("TextLabel", { TextColor3 = theme.accent })

theme:set("light")     -- everything that read a token moves
theme:toggle()
theme:get("accent")    -- the source itself
theme:extend { gold = "#e8b736" }
theme:blend("ink", "accent", 0.5)
```

Every token is a source. Switching a theme is one batched write per token.
No re-render, no prop drilling, no `ThemeProvider`.

---

`--> ["the three modes"]`

Merveille has its modes. Kite has three of its own, and they change what the
compiler accepts and what the linter says.

```lua
Kite.mode "strict"        -- nothing implicit, sugar is an error, guidance is loud
Kite.mode "creative"      -- sugar expands, types coerce, structure still checked
Kite.mode "performance"   -- nothing is checked, the linter reports cost instead
```

```text
                        strict   creative   performance
unknown property        error    error      -
type mismatch            error    hint       -
value range              error    error      -
sugar                    error    hint       hint
unkeyed list             error    warn       warn
deep tree                hint     hint       warn
large tree               -        hint       warn
animated layout          -        hint       warn
dynamics per instance    -        -          hint
respawn behaviour        hint     hint       hint
```

Build in creative. Ship in strict. Measure in performance.

## the linter

```lua
const report = Kite.strict(tree)

if not report:isOk() then
	print(report:text())
end

print(report:json())
print(report:html())   -- a standalone file, no dependencies
```

```text
Kite lint : strict : 1 error(s), 0 warning(s), 1 hint(s)
  tree builds 1 instance(s), 0 reactive propert(y|ies), 1 level(s) deep

  error property  tree.Text
        Frame has no property called "Text"
        -> Frame draws a rectangle. It has no Text property; reach for TextLabel.
  hint  noname    tree.Name
        Frame has no Name
        -> Name = "frame" makes the inspector readable
```

Every message names the class, the key, what Kite expected, and the line you
would write instead. A linter that says `invalid property` teaches nothing.

## sugar (creative and performance)

```lua
Kite.create("Frame", {
	size = { 220, 120 },          -- UDim2, two numbers means pixels
	position = { 0.5, 0, 0.5, 0 },
	anchor = "center",            -- or "top" "bottom" "left" "right" or { x, y }
	color = "#112126",            -- BackgroundColor3
	textColor = "#eeeeee",        -- TextColor3
	rotate = 90,
	zindex = 4,
	clip = true,

	corner = 10,                  -- a UICorner child
	padding = { 12, 16 },         -- a UIPadding child
	stroke = { "#2e5053", 1 },    -- a UIStroke child
	gradient = { "#16303a", "#112126" },
	list = "vertical",            -- a UIListLayout child
	scale = 1.2,                  -- a UIScale child
	aspect = 1.6,                 -- a UIAspectRatioConstraint child
})
```

Strict mode refuses sugar and hands you the long form on purpose.

---

`--> ["profiler and inspector"]`

```lua
Kite.profile(true)

const built = Kite.measure("shop", function() return buildShop() end)
print(built.milliseconds, built.value)

const view = Kite.profiler()
print(view:text())
print(view:json())
print(view:html())
view:reset()
```

```text
Kite profiler
  uptime 12.407s

  graph     nodes        148
  graph     reads        9120
  graph     writes       1204
  graph     computes     3310
  graph     effects      1204
  graph     batches      8
  graph     flushes      1210

  mount     mounts       3
  mount     instances    214
  mount     writes       1904
  mount     bindings     96
  mount     events       12

  compile   compiled     24
  compile   cacheHits    188
  compile   cached       24
  compile   sugar        61

  keys      created      40
  keys      reused       2920
  keys      destroyed    12
  keys      moves        188

  motion    frames       742
  motion    steps        12
  motion    live         2
  motion    connections  1
```

The counters are plain increments on paths Kite walks anyway. Nothing is
hooked, nothing is proxied, and the whole thing can be ignored.

```lua
const view = Kite.inspector(handle.instance)

print(view:tree())          -- the instance tree, with the properties that matter
print(view:html())          -- the same thing, styled, standalone
print(view:dump())          -- one instance, every property
print(view:graph(count))    -- the reactive graph behind a source
print(view:dot(count))      -- graphviz, if you like pictures
```

---

`--> ["it guides you"]`

Hover any public function in Studio and you get what it does, what it takes,
and an example. That is not a doc website, it is the editor.

```lua
Kite.help()           -- every topic
Kite.help("keys")     -- one topic, with an example you can paste
Kite.topics()         -- just the names
Kite.topic("spring")  -- the same text, as a string, for your own console
Kite.teach({          -- add your own
	name = "shop",
	summary = "how the shop screen works here",
	example = "openShop()",
})
```

Topics: `batch, clock, component, create, damp, derive, effect, go, help,
hydrate, indexes, inspector, keys, lint, modes, mount, on, profiler, record,
ref, source, spring, sugar, switch, theme, tween, untrack, when`.

---

`--> ["quick start"]`

## 1) a value

```lua
const count = Kite.source(0)
```

## 2) something that follows it

```lua
const doubled = count:map(function(v) return v * 2 end)
```

## 3) a screen

```lua
const Hud = Kite.create("ScreenGui", {
	Name = "Hud",
	ResetOnSpawn = false,

	Kite.children({
		Kite.create("TextLabel", {
			Name = "Count",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(200, 40),
			Text = doubled,
			TextColor3 = "#eeeeee",
			TextSize = 20,
		}),
	}),
})
```

## 4) mount it

```lua
const handle = Kite.mount(Hud)
```

## 5) move it

```lua
count(count() + 1)
```

---

`--> ["scopes and cleanup"]`

You almost never write these, because every mount, every effect run, and every
keyed row already has one. They are here when you need them.

```lua
const scope = Kite.scope(function()
	Kite.mount(tree)
	Kite.cleanup(function()
		print("bye")
	end)
end)

scope:destroy()   -- everything, in reverse order, including nested effects
```

A nested effect dies with the run that made it. A spring dies with the scope
that made it. An event connection dies with the instance it was on.

---

`--> ["performance notes"]`

What Kite actually does to be fast:

- **one table per node**, reused in place, no per-update allocation
- **dependency links are maps**, nothing is scanned to find subscribers
- **derives are pulled**: one nobody reads never computes
- **derives settle propagation**: an unchanged value wakes nothing downstream
- **effects are ordered by depth**, so nothing runs twice or out of order
- **batching collapses writes** into a single pass
- **equality is checked before propagation**, so writing the same value is free
- **trees compile once** into a plan of flat arrays, cached against the table
- **one effect per instance**, however many reactive properties it has
- **one frame connection** for every motion in the game
- **lists reorder with LayoutOrder**, never with reparenting
- **parent is assigned last**, so Roblox lays the tree out once
- **statics are hoisted**, so a static property is one assignment, ever

What it does not do: it does not diff, it does not keep a virtual tree, and it
does not run a scheduler of its own. Reactive updates happen when you write,
inside your own frame.

---

`--> ["errors that teach"]`

```lua
Kite.create("Frame", { Text = "hi" })
-- [Kite] Frame has no property called "Text".
--   did you mean: Visible?
--   Frame draws a rectangle. It has no Text property; reach for TextLabel.

Kite.create("TextLabel", { TextColor3 = "blue" })
-- [Kite] TextLabel.TextColor3 expects Color3, but you gave it "blue"
--   a Color3 looks like this in Kite: Color3.fromHex("3ddad7")  or  "#3ddad7"

Kite.create("Frame", { BackgroundTransparency = 4 })
-- [Kite] Frame.BackgroundTransparency should sit between 0 and 1, you gave 4
--   clamp it: kite.clamp(4, 0, 1)

kite.mode "stricct"
-- [Kite] "stricct" is not a mode. Kite has three: strict, creative, performance.
--   did you mean "strict"?

theme:get("accentt")
-- [Kite] the theme has no token called "accentt".
--   did you mean "accent"?
```

---

`--> ["limits"]`

- the property registry covers the Gui classes, not all of Roblox. Teach it
  more with `Kite.know("ClassName", "Frame", { Prop = "string" })`
- `keys` matches by the key you hand it. Hand it nothing and it matches by
  value, which is fine for strings and wrong for tables
- the linter reads trees, it does not read your mind: it cannot see inside a
  function you wrote
- validation and benchmarks are written for Studio execution
- no benchmark rerun is claimed here, and no proof against Vide in production
  is claimed either. The benchmark file is in the package, run it yourself
- native compilation is not a thing inside Roblox Luau, so Kite pushes
  compiled plans, cached lookups, one connection, and batching instead of
  pretending otherwise

---

`--> ["files to read first"]`

```text
Kite/init.luau
Kite/Core/Graph.luau
Kite/Core/Compiler.luau
Kite/Core/Mount.luau
Kite/Core/Keys.luau
Kite/Core/Spring.luau
Kite/Core/Lint.luau
Kite/Examples/Counter.client.luau
Kite/Examples/CommandBar.client.luau
Kite/Validation/StudioChecklist.md
```

---

`--> ["execution state"]`

This documentation describes the package as it stands in source.

The package is tested outside Studio as well: 95 assertions run headlessly
against the real modules, on a Roblox stub, with the Luau CLI.

```bash
python3 build.py --luau
luau Tests/run.luau
./tools/analyze.sh
```

- I hope you enjoy using this package. It took me a while, and this one did
  not make me cry. It made me want to build screens again.
