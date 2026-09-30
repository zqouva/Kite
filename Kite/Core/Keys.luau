--!strict
--[=[
	--> ["Kite : Keys"]

	Lists. The part of a UI library that decides whether your inventory
	screen drops frames.

		kite.keys      reuse by identity   rows move, rows keep their state
		kite.indexes   reuse by position   rows change what they show
		kite.when      one branch on or off
		kite.switch    one branch out of many
		kite.dynamic   re-render a block when its sources change

	--> ["why keys does not reparent"]
	Reordering by reparenting is the slowest thing you can do to a Roblox
	list. Kite writes `LayoutOrder` instead and lets the UIListLayout do
	the sorting, so a moving row costs one number, not a tree rebuild.

	--> ["example"]
	```lua
	kite.keys(function() return items() end, function(item, index)
		return kite.create `TextButton` {
			Text = function() return item().name end,
			Activated = function() pick(index()) end,
		}
	end, function(item) return item.id end)
	```
]=]

const Util = require(script.Parent.Util)
const Scope = require(script.Parent.Scope)
const Graph = require(script.Parent.Graph)
const Compiler = require(script.Parent.Compiler)

const Keys = {}

Keys.created = 0 :: number
Keys.reused = 0 :: number
Keys.destroyed = 0 :: number
Keys.moves = 0 :: number

export type Entry = {
	key: any,
	item: any,
	scope: Scope.Scope,
	instance: Instance?,
	mounted: boolean,
	order: number,
}

--> ["descriptors"]

function Keys.keys(source: any, render: any, keyOf: any?): any
	if type(render) ~= "function" then
		error(
			"[Kite] kite.keys(source, render) needs render to be a function.\n"
				.. "  render receives (item, index) where item is a source you call: item()\n"
				.. "  kite.help(\"keys\") shows the whole pattern.",
			2
		)
	end

	return {
		kind = "keys",
		source = source,
		render = render,
		keyOf = keyOf,
	}
end

function Keys.indexes(source: any, render: any): any
	return {
		kind = "keys",
		source = source,
		render = render,
		keyOf = function(_item: any, index: number)
			return index
		end,
		byIndex = true,
	}
end

function Keys.when(condition: any, element: any, fallback: any?): any
	return {
		kind = "when",
		condition = condition,
		element = element,
		fallback = fallback,
	}
end

function Keys.switch(source: any, cases: { [any]: any }, fallback: any?): any
	return {
		kind = "switch",
		source = source,
		cases = cases,
		fallback = fallback,
	}
end

function Keys.dynamic(render: any): any
	return {
		kind = "dynamic",
		render = render,
	}
end

--> ["shared mount helper"]

local function mountProduced(produced: any, parent: Instance, scope: Scope.Scope, instantiate: any, index: number?): Instance?
	if produced == nil then
		return nil
	end

	if type(produced) == "table" and (produced :: any)[1] ~= nil then
		const first: Instance? = nil
		for childIndex, child in produced do
			const made = instantiate(Compiler.plan(child), parent, scope, childIndex)
			if made and first == nil then
				first = made
			end
		end
		return first
	end

	return instantiate(Compiler.plan(produced), parent, scope, index)
end

Keys.mountProduced = mountProduced

--> ["handlers"]

local function handlerForKeys(node: any, parent: Instance, scope: Scope.Scope, instantiate: any)
	const source = node.source
	const render = node.render
	const keyOf = node.keyOf

	const entries: { Entry } = {}
	const byKey: { [any]: Entry } = {}
	const active: { [any]: boolean } = {}

	Graph.effect(function()
		const list = source()

		if type(list) ~= "table" then
			warn(
				"[Kite] kite.keys expected a table from its source, got "
					.. `{Util.show(list)}. The list stayed the way it was.`
			)
			return
		end

		table.clear(active)

		for index, item in list do
			const key = if keyOf then keyOf(item, index) else item

			if key == nil then
				warn(`[Kite] key was nil at index {index}, so that row was skipped.`)
				continue
			end

			active[key] = true

			const entry = byKey[key]

			if entry then
				Keys.reused += 1
				entry.item(item)
			else
				const itemSource = Graph.source(item, { name = "item" })
				const entryScope = Scope.child(scope, "key")

				entry = {
					key = key,
					item = itemSource,
					scope = entryScope,
					instance = nil,
					mounted = false,
					order = index,
				}

				byKey[key] = entry
				table.insert(entries, entry)
				Keys.created += 1
			end

			entry.order = index
		end

		for index = #entries, 1, -1 do
			const entry = entries[index]

			if not active[entry.key] then
				Scope.destroy(entry.scope)
				byKey[entry.key] = nil
				table.remove(entries, index)
				Keys.destroyed += 1
			end
		end

		-- mount what is new, then settle the order with LayoutOrder
		for index, item in list do
			const key = if keyOf then keyOf(item, index) else item
			const entry = byKey[key]

			if entry and not entry.mounted then
				entry.mounted = true

				Scope.runIn(entry.scope, function()
					const produced = render(entry.item, index)
					entry.instance = mountProduced(produced, parent, entry.scope, instantiate, index)
				end)
			end

			if entry and entry.instance then
				const instance = entry.instance :: Instance
				if instance:IsA("GuiObject") and instance.LayoutOrder ~= entry.order then
					instance.LayoutOrder = entry.order
					Keys.moves += 1
				end
			end
		end
	end)

	return nil
end

local function handlerForWhen(node: any, parent: Instance, scope: Scope.Scope, instantiate: any)
	const condition = node.condition
	const element = node.element
	const fallback = node.fallback

	const childScope: Scope.Scope? = nil
	const mounted: any = nil

	Graph.effect(function()
		const value = if type(condition) == "function" then condition() else condition
		const wanted = if value then element else fallback

		if wanted == mounted then
			return
		end

		if childScope then
			Scope.destroy(childScope)
			childScope = nil
		end

		mounted = wanted

		if wanted then
			childScope = Scope.child(scope, "when")
			Scope.runIn(childScope, function()
				mountProduced(wanted, parent, childScope, instantiate, 1)
			end)
		end
	end)

	return nil
end

local function handlerForSwitch(node: any, parent: Instance, scope: Scope.Scope, instantiate: any)
	const source = node.source
	const cases = node.cases
	const fallback = node.fallback

	const childScope: Scope.Scope? = nil
	const mountedKey: any = nil

	Graph.effect(function()
		const value = if type(source) == "function" then source() else source
		const wanted = cases[value]

		if wanted == nil then
			wanted = fallback
		end

		const key = if wanted == nil then nil else (if type(wanted) == "table" then tostring(wanted) else wanted)

		if key == mountedKey then
			return
		end

		if childScope then
			Scope.destroy(childScope)
			childScope = nil
		end

		mountedKey = key

		if wanted then
			childScope = Scope.child(scope, "switch")
			Scope.runIn(childScope, function()
				mountProduced(wanted, parent, childScope, instantiate, 1)
			end)
		end
	end)

	return nil
end

local function handlerForDynamic(node: any, parent: Instance, scope: Scope.Scope, instantiate: any)
	const render = node.render
	const childScope: Scope.Scope? = nil

	Graph.effect(function()
		if childScope then
			Scope.destroy(childScope)
			childScope = nil
		end

		childScope = Scope.child(scope, "dynamic")

		Scope.runIn(childScope, function()
			const produced = render()
			mountProduced(produced, parent, childScope, instantiate, 1)
		end)
	end)

	return nil
end

--> ["register"]
-- Called once by init.luau, after Mount exists. No require cycle.

function Keys.register(Mount: any)
	Mount.register("keys", handlerForKeys)
	Mount.register("indexes", handlerForKeys)
	Mount.register("when", handlerForWhen)
	Mount.register("switch", handlerForSwitch)
	Mount.register("dynamic", handlerForDynamic)
end

function Keys.stats()
	return {
		created = Keys.created,
		reused = Keys.reused,
		destroyed = Keys.destroyed,
		moves = Keys.moves,
	}
end

function Keys.reset()
	Keys.created = 0
	Keys.reused = 0
	Keys.destroyed = 0
	Keys.moves = 0
end

return Keys
