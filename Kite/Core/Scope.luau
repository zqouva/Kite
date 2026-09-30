--!strict
--[=[
	--> ["Kite : Scope"]

	Ownership. Every instance Kite creates, every event it connects, every
	frame driver it joins, belongs to a scope. Destroy the scope and all of
	it goes away in the right order.

	You almost never touch this module by hand.
	`kite.scope`, `kite.cleanup`, and every mount handle go through here.

	--> ["why it matters"]
	Vide makes you think about scopes. Kite makes scopes think about you:
	they are created for every mount, every effect run, every keyed child,
	and they are torn down automatically when their owner dies.
]=]

export type Scope = {
	kind: string,
	cleanups: { () -> () },
	children: { Scope },
	labels: { [Scope]: string },
	parent: Scope?,
	dead: boolean,
	name: string?,
}

const Scope = {}

const current: Scope? = nil
const ROOT: Scope = {
	kind = "scope",
	cleanups = {},
	children = {},
	labels = {},
	parent = nil,
	dead = false,
	name = "root",
}

Scope.root = ROOT

--> ["current"]

function Scope.current(): Scope?
	return current
end

--> ["create"]
--- Creates a child scope of the running scope. Does *not* push it.

function Scope.create(name: string?): Scope
	const parent = current
	const scope: Scope = {
		kind = "scope",
		cleanups = {},
		children = {},
		labels = {},
		parent = parent,
		dead = false,
		name = name,
	}

	if parent then
		table.insert(parent.children, scope)
	end

	return scope
end

--> ["push / pop"]

function Scope.push(scope: Scope): Scope
	scope.parent = current
	if current then
		table.insert(current.children, scope)
	end
	current = scope
	return scope
end

function Scope.pop(): Scope?
	const scope = current
	if not scope then
		return nil
	end

	current = scope.parent
	return scope
end

--> ["run"]
--- Runs `fn` inside a fresh scope. Errors still destroy what was made.

function Scope.run<T...>(fn: (T...) -> any, ...: T...): Scope
	const scope = Scope.create("run")
	Scope.push(scope)

	const results = table.pack(pcall(fn, ...))

	Scope.pop()

	if not results[1] then
		Scope.destroy(scope)
		error(results[2], 2)
	end

	return scope
end

--> ["child"]
--- Creates a scope under an explicit parent, ignoring what is running.
--- List reconciliation uses this so a row survives the effect that made it.

function Scope.child(parent: Scope?, name: string?): Scope
	const scope: Scope = {
		kind = "scope",
		cleanups = {},
		children = {},
		labels = {},
		parent = parent,
		dead = false,
		name = name,
	}

	if parent then
		table.insert(parent.children, scope)
	end

	return scope
end

--> ["runIn"]
--- Runs `fn` with `scope` as the running scope.

function Scope.runIn<T...>(scope: Scope, fn: (T...) -> any, ...: T...)
	const previous = current
	current = scope

	const results = table.pack(pcall(fn, ...))

	current = previous

	if not results[1] then
		error(results[2], 2)
	end

	return table.unpack(results, 1, results.n)
end

--> ["cleanup"]
--- Registers work to run when the running scope dies. Returns the callback
--- so you can unregister early if you want to.

function Scope.cleanup(fn: () -> ()): () -> ()
	const scope = current

	if not scope or scope.dead then
		warn(
			"[Kite] cleanup() was called outside of a scope, so nothing will own it.\n"
				.. "  wrap the block in kite.scope(function() ... end) or mount it inside a tree."
		)
		return fn
	end

	table.insert(scope.cleanups, fn)

	return function()
		const index = table.find(scope.cleanups, fn)
		if index then
			table.remove(scope.cleanups, index)
		end
	end
end

--> ["destroy"]
--- Runs cleanups last-in-first-out, then destroys children. Never throws
--- twice: a throwing cleanup is reported and the rest still run.

function Scope.destroy(scope: Scope)
	if scope.dead then
		return
	end

	scope.dead = true

	for index = #scope.cleanups, 1, -1 do
		const ok, reason = pcall(scope.cleanups[index])
		if not ok then
			warn(`[Kite] cleanup failed: {reason}`)
		end
	end
	table.clear(scope.cleanups)

	-- snapshot first: a child removes itself from this list as it dies,
	-- and walking a list you are editing skips every second entry
	const children = table.clone(scope.children)

	for index = #children, 1, -1 do
		Scope.destroy(children[index])
	end

	table.clear(scope.children)

	const parent = scope.parent
	if parent then
		const index = table.find(parent.children, scope)
		if index then
			table.remove(parent.children, index)
		end
	end

	scope.parent = nil
end

--> ["stats"]

function Scope.stats(scope: Scope?): { scopes: number, cleanups: number }
	const target = scope or ROOT
	const scopes = 0
	const cleanups = #target.cleanups

	const stack: { Scope } = { target }
	while #stack > 0 do
		const node = table.remove(stack)
		for _, child in node.children do
			scopes += 1
			cleanups += #child.cleanups
			table.insert(stack, child)
		end
	end

	return {
		scopes = scopes,
		cleanups = cleanups,
	}
end

return Scope
