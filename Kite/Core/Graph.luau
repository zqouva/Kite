--!strict
--[=[
	--> ["Kite : Graph"]

	The reactive engine. Three shapes, one rule:

		source   a value that changes      count(1), count(), count:set(2)
		derive   a value that is computed  doubled = count:map(fn)
		effect   work that happens         count:watch(fn)

	--> ["the rule"]
	A derive and an effect remember what they read while they run.
	When a source they read changes, they run again.
	Nothing else. No dependency arrays, no manual wiring, no diffing.

	--> ["why it is fast"]
	- one table per node, reused in place
	- dependency links are plain `true` maps, no arrays to scan
	- derives are *pulled*: a derive nobody reads never computes
	- effects are *ordered*: they run shallowest-first, so you never see
	  a child update before its parent
	- writes inside `kite.batch` collapse into a single pass, so ten writes
	  to ten sources run the dependent effects once, not ten times
	- equality is checked before propagation, so setting the same value
	  is free

	--> ["glitch free"]
	If an effect reads `a` and `b`, and both change in the same batch, the
	effect runs exactly once, after both have settled.
]=]

const Util = require(script.Parent.Util)
const Scope = require(script.Parent.Scope)

export type Node = {
	kind: string,
	value: any,
	fn: ((...any) -> ...any)?,
	deps: { [Node]: boolean },
	subs: { [Node]: boolean },
	depth: number,
	dirty: boolean,
	evaluating: boolean,
	alive: boolean,
	equals: ((any, any) -> boolean)?,
	name: string?,
	watched: boolean,
	scope: Scope.Scope?,
	cleanups: { () -> () },
	meta: { [string]: any }?,
}

const Graph = {}

Graph.nodes = 0 :: number
Graph.reads = 0 :: number
Graph.writes = 0 :: number
Graph.computes = 0 :: number
Graph.effects = 0 :: number
Graph.batches = 0 :: number
Graph.flushes = 0 :: number

const current: Node? = nil
const batchDepth = 0
const queue: { Node } = {}
const queued: { [Node]: boolean } = {}
const epoch = 0

const Source = {} :: { [string]: any }
Source.__type = "Kite.Source"
Source.__index = Source

--> ["linking"]

local function watch(node: Node, seen: { [Node]: boolean }?)
	if node.watched then
		return
	end

	node.watched = true

	const visited = seen or {}

	if visited[node] then
		return
	end
	visited[node] = true

	for dep in node.deps do
		watch(dep, visited)
	end
end

local function link(observer: Node, dep: Node)
	if observer.deps[dep] then
		return
	end

	observer.deps[dep] = true
	dep.subs[observer] = true

	-- a derive that feeds an effect is settled eagerly, so an unchanged
	-- value stops the wave instead of running every effect behind it.
	-- a derive nobody watches stays lazy and never computes at all.
	if observer.kind == "effect" or observer.watched then
		watch(dep)
	end

	const wanted = dep.depth + 1
	if wanted > observer.depth then
		observer.depth = wanted
	end
end

local function detach(node: Node)
	for dep in node.deps do
		dep.subs[node] = nil
	end
	table.clear(node.deps)
end

--> ["depth cascade"]
-- Depth only grows, and only when the graph actually reshapes, so this is
-- rare work on a hot path.

local function cascade(node: Node, seen: { [Node]: boolean })
	if seen[node] then
		return
	end
	seen[node] = true

	const wanted = 0
	for dep in node.deps do
		if dep.depth + 1 > wanted then
			wanted = dep.depth + 1
		end
	end

	if wanted == node.depth then
		return
	end

	node.depth = wanted

	for sub in node.subs do
		cascade(sub, seen)
	end
end

--> ["evaluation"]

local function runNode(node: Node, fn: () -> any): any
	detach(node)

	const previous = current
	current = node
	node.evaluating = true

	const results = table.pack(pcall(fn))

	node.evaluating = false
	current = previous

	if not results[1] then
		const reason = results[2]
		const label = node.name or node.kind
		warn(
			`[Kite] {node.kind} "{label}" threw while it was running:\n  {reason}\n`
				.. "  the graph kept its previous value so your UI stays alive."
		)
		return node.value
	end

	if results.n > 1 then
		return results[2]
	end

	return nil
end

local function recompute(node: Node): boolean
	if not node.dirty then
		return false
	end

	if node.evaluating then
		warn(
			`[Kite] "{node.name or node.kind}" read itself while computing. `
				.. "A derive cannot depend on its own result."
		)
		node.dirty = false
		return false
	end

	-- pull the whole dirty chain first, so we never hand out a stale value
	for dep in node.deps do
		if dep.kind == "derive" and dep.dirty then
			recompute(dep)
		end
	end

	node.dirty = false

	const value = runNode(node, node.fn :: any)
	Graph.computes += 1

	const same = if node.equals then (node.equals :: any)(value, node.value) else Util.equal(value, node.value)

	if same then
		return false
	end

	node.value = value
	return true
end

--> ["reads"]

local function read(node: Node): any
	if node.kind == "derive" then
		recompute(node)
	end

	if current then
		link(current, node)
	end

	Graph.reads += 1
	return node.value
end

local function peek(node: Node): any
	if node.kind == "derive" then
		recompute(node)
	end
	return node.value
end

--> ["scheduling"]

local function schedule(node: Node)
	if queued[node] then
		return
	end
	queued[node] = true
	table.insert(queue, node)
end

local function propagate(node: Node)
	const stack: { Node } = { node }
	const head = 1

	while head <= #stack do
		const next = stack[head]
		head += 1

		for sub in next.subs do
			if sub.alive then
				if sub.kind == "effect" then
					sub.dirty = true
					schedule(sub)
				elseif sub.kind == "derive" and not sub.dirty then
					sub.dirty = true

					if sub.watched then
						-- settle it now: if the value did not move, the wave
						-- stops here and nothing downstream runs
						if recompute(sub) then
							table.insert(stack, sub)
						end
					else
						table.insert(stack, sub)
					end
				end
			end
		end
	end
end

local function runEffect(node: Node)
	if not node.alive then
		return
	end

	node.dirty = false

	if node.scope then
		Scope.destroy(node.scope)
	end

	node.scope = Scope.create("effect")
	Scope.push(node.scope)

	const cleanup = runNode(node, node.fn :: any)

	Scope.pop()

	if type(cleanup) == "function" then
		table.insert(node.scope.cleanups, cleanup)
	end

	Graph.effects += 1
end

local function flush()
	epoch += 1
	Graph.flushes += 1

	const guard = 0

	while #queue > 0 do
		const batch = queue
		queue = {}
		queued = {}

		table.sort(batch, function(left, right)
			return left.depth < right.depth
		end)

		for index = 1, #batch do
			runEffect(batch[index])
		end

		guard += 1
		if guard > 256 then
			warn(
				"[Kite] the graph did not settle after 256 passes. "
					.. "You probably write to a source from inside its own effect."
			)
			break
		end
	end
end

local function write(node: Node, value: any)
	if not node.alive then
		return
	end

	if node.kind ~= "source" then
		error(
			`[Kite] you tried to write to a {node.kind}. Only sources accept writes.\n`
				.. `  "{node.name or node.kind}" came from a derive, so it follows its inputs instead.`,
			2
		)
	end

	const same = if node.equals then (node.equals :: any)(value, node.value) else value == node.value

	if same then
		return
	end

	node.value = value
	Graph.writes += 1

	propagate(node)

	if batchDepth == 0 then
		flush()
	end
end

--> ["construction"]

local function make(kind: string, value: any, fn: (() -> any)?): Node
	const node: Node = {
		kind = kind,
		value = value,
		fn = fn,
		deps = {},
		subs = {},
		depth = 0,
		dirty = kind ~= "source",
		evaluating = false,
		alive = true,
		equals = nil,
		name = nil,
		watched = false,
		scope = nil,
		cleanups = {},
	}

	Graph.nodes += 1
	return node
end

--> ["public : source"]

function Graph.source<T>(value: T, options: { equals: ((any, any) -> boolean)?, name: string? }?): Node
	const node = make("source", value, nil)

	if options then
		node.equals = options.equals
		node.name = options.name
	end

	return setmetatable(node, Source) :: any
end

--> ["public : derive"]

function Graph.derive<T>(fn: () -> T, options: { equals: ((any, any) -> boolean)?, name: string? }?): Node
	const node = make("derive", nil, fn :: any)

	if options then
		node.equals = options.equals
		node.name = options.name
	end

	return setmetatable(node, Source) :: any
end

--> ["public : effect"]

function Graph.effect(fn: () -> ()): Node
	const owner = Scope.current()
	const node = make("effect", nil, fn :: any)
	node.scope = Scope.create("effect")

	runEffect(node)

	-- the scope that made this effect owns it: destroy the scope and the
	-- effect stops listening
	if owner then
		Scope.cleanup(function()
			Graph.destroy(node)
		end)
	end

	return setmetatable(node, Source) :: any
end

--> ["public : batch"]
--- Collapses every write inside `fn` into one propagation pass.
---
--- Example:
--- ```lua
--- kite.batch(function()
---     health:set(10)
---     shield:set(0)
--- end) -- the UI updates once, not twice
--- ```

function Graph.batch<T...>(fn: (T...) -> any, ...: T...): any
	batchDepth += 1
	Graph.batches += 1

	const results = table.pack(pcall(fn, ...))

	batchDepth -= 1

	if batchDepth <= 0 then
		batchDepth = 0
		if not results[1] then
			flush()
			error(results[2], 2)
		end
		flush()
	elseif not results[1] then
		error(results[2], 2)
	end

	return table.unpack(results, 1, results.n)
end

--> ["public : untrack"]
--- Reads inside `fn` do not become dependencies.
---
--- Example:
--- ```lua
--- const label = kite.derive(function()
---     return kite.untrack(function() return theme:get(`accent`) end)
--- end)
--- ```

function Graph.untrack<T...>(fn: (T...) -> any, ...: T...): any
	const previous = current
	current = nil
	const results = table.pack(pcall(fn, ...))
	current = previous

	if not results[1] then
		error(results[2], 2)
	end

	return table.unpack(results, 1, results.n)
end

--> ["public : peek"]

function Graph.peek<T>(node: Node): T
	return peek(node) :: any
end

function Graph.read<T>(node: Node): T
	return read(node) :: any
end

function Graph.isNode(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Source
end

--> ["public : record"]
--- A table of sources, from a plain table. Nested tables become nested
--- records, so deep state stays reactive with no proxy.
---
--- Example:
--- ```lua
--- const stats = kite.record { hp = 100, aura = { grace = 1 } }
--- stats.hp(80)
--- stats.aura.grace(4)
--- ```

function Graph.record(values: { [string]: any }): any
	const out = {}

	for key, value in values do
		if type(value) == "table" and #value == 0 then
			out[key] = Graph.record(value :: any)
		else
			out[key] = Graph.source(value, { name = key })
		end
	end

	return setmetatable(out, {
		__type = "Kite.Record",
		__index = function(self, key)
			error(`[Kite] record has no field "{tostring(key)}"`, 2)
		end,
	})
end

--> ["node methods"]
-- These are the autocomplete surface. They exist so Studio can *guide* you:
-- type `count:` and the whole vocabulary shows up.

function Source.get(self: Node): any
	return read(self)
end

function Source.peek(self: Node): any
	return peek(self)
end

function Source.set(self: Node, value: any)
	write(self, value)
end

function Source.update(self: Node, fn: (any) -> any)
	write(self, fn(peek(self)))
end

function Source.map<T>(self: Node, fn: (any) -> T, name: string?): Node
	return Graph.derive(function()
		return fn(read(self))
	end, { name = name })
end

function Source.pick(self: Node, key: any, name: string?): Node
	return Graph.derive(function()
		const value = read(self)
		return if type(value) == "table" then (value :: any)[key] else nil
	end, { name = name })
end

function Source.watch(self: Node, fn: (any) -> ()): () -> ()
	const owner = Scope.current()
	const node: Node = make("effect", nil, function()
		fn(read(self))
	end :: any)

	node.name = if self.name then `{self.name}:watch` else "watch"
	node.scope = Scope.create("watch")

	runEffect(node)

	if owner then
		Scope.cleanup(function()
			Graph.destroy(node)
		end)
	end

	return function()
		Graph.destroy(node)
	end
end

function Source.effect(self: Node, fn: (any) -> ()): () -> ()
	return Source.watch(self, fn)
end

function Source.when(self: Node, truthy: any, falsy: any): Node
	return Source.map(self, function(value)
		return if value then truthy else falsy
	end)
end

function Source.toggle(self: Node): any
	write(self, not peek(self))
	return peek(self)
end

function Source.tostring(self: Node): Node
	return Source.map(self, function(value)
		return tostring(value)
	end)
end

function Source.freeze(self: Node)
	self.alive = false
end

function Source.unfreeze(self: Node)
	self.alive = true
end

function Source.name(self: Node, label: string): Node
	self.name = label
	return self
end

function Source.destroy(self: Node)
	Graph.destroy(self)
end

function Source.depth(self: Node): number
	return self.depth
end

function Source.watchers(self: Node): number
	return Util.count(self.subs)
end

function Source.dependencies(self: Node): number
	return Util.count(self.deps)
end

--> ["install"]
-- Lets a sibling module bolt methods onto every source without a require
-- cycle. Spring uses this for `:spring`, `:tween`, and `:damp`.

function Graph.install(key: string, fn: any)
	Source[key] = fn
end

--> ["destroy"]

function Graph.destroy(node: Node)
	if not node.alive then
		return
	end

	node.alive = false

	if node.scope then
		Scope.destroy(node.scope)
		node.scope = nil
	end

	for index = #node.cleanups, 1, -1 do
		pcall(node.cleanups[index])
	end
	table.clear(node.cleanups)

	detach(node)

	for sub in node.subs do
		sub.deps[node] = nil
	end
	table.clear(node.subs)

	queued[node] = nil
	Graph.nodes -= 1
end

--> ["stats"]

function Graph.stats()
	return {
		nodes = Graph.nodes,
		reads = Graph.reads,
		writes = Graph.writes,
		computes = Graph.computes,
		effects = Graph.effects,
		batches = Graph.batches,
		flushes = Graph.flushes,
		epoch = epoch,
		queued = #queue,
	}
end

function Graph.reset()
	Graph.reads = 0
	Graph.writes = 0
	Graph.computes = 0
	Graph.effects = 0
	Graph.batches = 0
	Graph.flushes = 0
end

--> ["debug"]
-- Used by the inspector. Returns the raw adjacency so a report can draw it.

function Graph.describe(node: Node): { deps: { Node }, subs: { Node } }
	return {
		deps = Util.keys(node.deps),
		subs = Util.keys(node.subs),
	}
end

Graph.Source = Source

--> ["call"]
-- `count()` reads, `count(5)` writes. One call, both directions.

function Source.__call(self: Node, ...: any): any
	if select("#", ...) == 0 then
		return read(self)
	end

	write(self, (...))
	return read(self)
end

function Source.__tostring(self: Node): string
	const kind = if self.kind == "source" then "source" else self.kind
	const label = if self.name then ` "{self.name}"` else ""
	return `Kite.{kind}{label}({Util.show(self.value)})`
end

function Source.__eq(left: Node, right: Node): boolean
	return left.value == right.value
end

return Graph
