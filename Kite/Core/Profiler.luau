--!strict
--[=[
	--> ["Kite : Profiler"]

	Counters that are already in the package, waiting to be read. No hooks
	are installed when you are not profiling: the counters are plain number
	increments on paths Kite walks anyway.

	```lua
	kite.profile(true)

	const profiler = kite.profiler()
	print(profiler:text())

	-- or measure one thing
	const timing = kite.measure(`build the shop`, function()
		buildShop()
	end)
	print(timing.milliseconds)
	```

	--> ["what is counted"]
	```text
	graph     nodes, reads, writes, computes, effects, batches, flushes
	mount     mounts, instances, writes, bindings, events
	compile   compiled, cache hits, cached plans, sugar expanded
	keys      created, reused, destroyed, moves
	motion    frames, steps, live motions, connections
	```
]=]

const Util = require(script.Parent.Util)

const Profiler = {}

Profiler.enabled = false
Profiler.started = os.clock()
Profiler.runs = 0 :: number
Profiler.milliseconds = 0 :: number

const marks: { { label: string, at: number, ms: number? } } = {}

--> ["toggle"]

function Profiler.enable(state: boolean?)
	Profiler.enabled = if state == nil then true else state

	if Profiler.enabled then
		Profiler.started = os.clock()
	end
end

function Profiler.isEnabled(): boolean
	return Profiler.enabled
end

--> ["measure"]
--- Times one call. Returns the value the call returned plus how long it took.
---
--- Example:
--- ```lua
--- const built = kite.measure(`shop`, function() return buildShop() end)
--- print(built.milliseconds, built.value)
--- ```

function Profiler.measure<T...>(label: string, fn: (T...) -> any, ...: T...): any
	const at = os.clock()
	const results = table.pack(pcall(fn, ...))
	const took = (os.clock() - at) * 1000

	if not results[1] then
		error(results[2], 2)
	end

	Profiler.runs += 1
	Profiler.milliseconds += took

	table.insert(marks, { label = label, at = at, ms = took })

	if #marks > 64 then
		table.remove(marks, 1)
	end

	return setmetatable({
		label = label,
		milliseconds = took,
		value = results[2],
		n = results.n - 1,
	}, {
		__type = "Kite.Measure",
		__tostring = function(self: any)
			return `{label} took {string.format("%.3f", took)}ms`
		end,
	}) :: any
end

function Profiler.marks(): { { label: string, at: number, ms: number? } }
	return table.clone(marks)
end

--> ["snapshot"]

function Profiler.snapshot()
	const Graph = require(script.Parent.Graph)
	const Mount = require(script.Parent.Mount)
	const Compiler = require(script.Parent.Compiler)
	const Keys = require(script.Parent.Keys)
	const Spring = require(script.Parent.Spring)
	const Component = require(script.Parent.Component)
	const Scope = require(script.Parent.Scope)

	return {
		enabled = Profiler.enabled,
		uptime = os.clock() - Profiler.started,
		graph = Graph.stats(),
		mount = Mount.stats(),
		compile = Compiler.stats(),
		keys = Keys.stats(),
		motion = Spring.stats(),
		component = Component.stats(),
		scope = Scope.stats(),
		measure = {
			runs = Profiler.runs,
			milliseconds = Profiler.milliseconds,
		},
	}
end

function Profiler.reset()
	const Graph = require(script.Parent.Graph)
	const Mount = require(script.Parent.Mount)
	const Compiler = require(script.Parent.Compiler)
	const Keys = require(script.Parent.Keys)
	const Spring = require(script.Parent.Spring)

	Graph.reset()
	Mount.reset()
	Compiler.reset()
	Keys.reset()
	Spring.reset()

	Profiler.runs = 0
	Profiler.milliseconds = 0
	table.clear(marks)
end

--> ["report"]

function Profiler.report(): any
	const out = {} :: { [string]: any }
	out.snapshot = function()
		return Profiler.snapshot()
	end
	out.text = function()
		return Profiler.text()
	end
	out.html = function()
		return Profiler.html()
	end
	out.json = function()
		return Profiler.json()
	end
	out.reset = function()
		Profiler.reset()
	end

	return out
end

function Profiler.text(): string
	const snap = Profiler.snapshot()
	const lines = {}

	local function row(group: string, key: string, value: any)
		table.insert(lines, `  {Util.pad(group, 9)}{Util.pad(key, 12)}{value}`)
	end

	table.insert(lines, "Kite profiler")
	table.insert(lines, `  uptime {string.format("%.3f", snap.uptime)}s` .. (if not snap.enabled then "   (profiling is off, counts still accumulate)" else ""))
	table.insert(lines, "")

	row("graph", "nodes", snap.graph.nodes)
	row("graph", "reads", snap.graph.reads)
	row("graph", "writes", snap.graph.writes)
	row("graph", "computes", snap.graph.computes)
	row("graph", "effects", snap.graph.effects)
	row("graph", "batches", snap.graph.batches)
	row("graph", "flushes", snap.graph.flushes)
	row("graph", "epoch", snap.graph.epoch)
	table.insert(lines, "")

	row("mount", "mounts", snap.mount.mounts)
	row("mount", "instances", snap.mount.instances)
	row("mount", "writes", snap.mount.writes)
	row("mount", "bindings", snap.mount.bindings)
	row("mount", "events", snap.mount.events)
	table.insert(lines, "")

	row("compile", "compiled", snap.compile.compiled)
	row("compile", "cacheHits", snap.compile.cacheHits)
	row("compile", "cached", snap.compile.cached)
	row("compile", "sugar", snap.compile.sugar)
	table.insert(lines, "")

	row("keys", "created", snap.keys.created)
	row("keys", "reused", snap.keys.reused)
	row("keys", "destroyed", snap.keys.destroyed)
	row("keys", "moves", snap.keys.moves)
	table.insert(lines, "")

	row("motion", "frames", snap.motion.frames)
	row("motion", "steps", snap.motion.steps)
	row("motion", "live", snap.motion.motions)
	row("motion", "connections", snap.motion.connections)
	table.insert(lines, "")

	row("component", "defined", snap.component.defined)
	row("component", "built", snap.component.built)
	table.insert(lines, "")

	row("scope", "scopes", snap.scope.scopes)
	row("scope", "cleanups", snap.scope.cleanups)
	table.insert(lines, "")

	row("measure", "runs", snap.measure.runs)
	row("measure", "total ms", string.format("%.3f", snap.measure.milliseconds))

	if #marks > 0 then
		table.insert(lines, "")
		table.insert(lines, "  last marks")
		for index = math.max(1, #marks - 7), #marks do
			const mark = marks[index]
			table.insert(lines, `    {Util.pad(mark.label, 28)}{string.format("%.3f", mark.ms or 0)}ms`)
		end
	end

	return table.concat(lines, "\n")
end

function Profiler.json(): string
	const snap = Profiler.snapshot()

	local function dump(value: any, indent: number): string
		const pad = string.rep("  ", indent)

		if type(value) ~= "table" then
			if type(value) == "string" then
				return `"{value}"`
			end
			return tostring(value)
		end

		const parts = {}
		for key, inner in value do
			table.insert(parts, `{pad}  "{tostring(key)}": {dump(inner, indent + 1)}`)
		end

		if #parts == 0 then
			return "{}"
		end

		return "{\n" .. table.concat(parts, ",\n") .. `\n{pad}}`
	end

	return dump(snap, 0)
end

function Profiler.html(): string
	const snap = Profiler.snapshot()

	const groups = {
		{ "graph", snap.graph },
		{ "mount", snap.mount },
		{ "compile", snap.compile },
		{ "keys", snap.keys },
		{ "motion", snap.motion },
		{ "component", snap.component },
		{ "scope", snap.scope },
	}

	const cards = {}

	for _, group in groups do
		const name = group[1] :: string
		const values = group[2] :: { [string]: any }
		const rows = {}

		for key, value in Util.sorted(Util.keys(values)) do
			table.insert(rows, string.format(
				[[          <tr><td>%s</td><td class="num">%s</td></tr>]],
				tostring(key),
				tostring((values :: any)[key])
			))
		end

		table.insert(cards, string.format(
			[[      <div class="card">
        <h2>%s</h2>
        <table>
%s
        </table>
      </div>]],
			name,
			table.concat(rows, "\n")
		))
	end

	return string.format(
		[[<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Kite profiler</title>
<style>
  body { background: #0d181b; color: #eeeeee; font: 13px/1.5 ui-monospace, monospace; margin: 24px; }
  h1 { font-size: 15px; color: #3ddad7; letter-spacing: .12em; text-transform: uppercase; }
  .wrap { display: flex; flex-wrap: wrap; gap: 14px; }
  .card { background: #112126; border: 1px solid #2e5053; border-radius: 10px; padding: 12px 14px; min-width: 220px; }
  h2 { font-size: 11px; letter-spacing: .14em; text-transform: uppercase; color: #7f9ba1; margin: 0 0 8px; }
  td { padding: 2px 0; }
  td:first-child { color: #7f9ba1; padding-right: 16px; }
  .num { text-align: right; color: #3ddad7; }
</style>
</head>
<body>
  <h1>Kite profiler</h1>
  <div class="meta">uptime %s s</div>
  <div class="wrap">
%s
  </div>
</body>
</html>]],
		string.format("%.3f", snap.uptime),
		table.concat(cards, "\n")
	)
end

return Profiler
