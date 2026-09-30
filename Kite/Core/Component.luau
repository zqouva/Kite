--!strict
--[=[
	--> ["Kite : Component"]

	A component is a function that returns an element, plus a contract that
	says what it accepts.

	The contract is what makes components *guide* you. Spell a prop wrong
	and Kite names the component, the prop, and the shape it wanted:

		```lua
		const Card = kite.component(`Card`, function(props)
			return kite.create `Frame` { Size = props.size }
		end, {
			size = { type = `UDim2`, default = UDim2.fromOffset(200, 120) },
			title = { type = `string`, required = true },
		})

		Card { titel = `hello` }
		-- [Kite] Card does not take a prop called `titel`. did you mean `title`?
		--   Card { title = `hello`, size = UDim2.fromOffset(200, 120) }
		```

	Props that are sources or functions stay reactive. Props that are plain
	values are checked once and passed straight through.
]=]

const Util = require(script.Parent.Util)
const Config = require(script.Parent.Config)

export type Field = {
	type: string?,
	default: any?,
	required: boolean?,
	note: string?,
}

export type Component = {
	kind: string,
	name: string,
	build: (any) -> any,
	fields: { [string]: Field },
}

const Component = {}

Component.defined = 0 :: number
Component.built = 0 :: number

const registry: { [string]: Component } = {}
Component.registry = registry

--> ["define"]

function Component.define(name: string, build: (any) -> any, fields: { [string]: Field }?): Component
	if type(name) ~= "string" then
		error("[Kite] kite.component(name, build) needs a name string first.", 2)
	end

	if type(build) ~= "function" then
		error(`[Kite] component "{name}" needs a build function, got {Util.show(build)}.`, 2)
	end

	const definition: Component = {
		kind = "component",
		name = name,
		build = build,
		fields = fields or {},
	}

	registry[name] = definition
	Component.defined += 1

	local function call(props: { [any]: any }?): any
		Component.built += 1
		const resolved = Component.resolve(definition, props or {})
		return {
			kind = "component",
			name = name,
			props = resolved,
			definition = definition,
		}
	end

	return setmetatable(definition, {
		__type = "Kite.Component",
		__call = function(_self: any, props: { [any]: any }?)
			return call(props)
		end,
		__tostring = function(_self: any)
			return `Kite.Component({name})`
		end,
		__index = definition,
	}) :: any
end

Component.create = Component.define
Component.component = Component.define

--> ["resolve"]
-- Applies defaults, checks types, and reports in the language of the
-- component, not the language of Luau.

function Component.resolve(definition: Component, props: { [any]: any }): { [any]: any }
	const fields = definition.fields
	const out = {}

	if Config.validate then
		for key in props do
			if type(key) == "string" and fields[key] == nil then
				const nearest = Util.nearest(key, Util.keys(fields))

				const shape = {}
				for fieldName, field in fields do
					table.insert(shape, `{fieldName} = {Util.show(field.default)}`)
				end
				table.sort(shape)

				error(
					`[Kite] {definition.name} does not take a prop called "{key}".\n`
						.. (if nearest then `  did you mean "{nearest}"?\n` else "")
						.. `  {definition.name} takes: {table.concat(shape, ", ")}`,
					3
				)
			end
		end
	end

	for key, field in fields do
		const value = props[key]

		if value == nil then
			if field.required then
				error(
					`[Kite] {definition.name} needs "{key}" and you did not pass it.\n`
						.. `  {definition.name} ({key} = <{field.type or "value"}>)`,
					3
				)
			end

			if field.default ~= nil then
				out[key] = field.default
			end

			continue
		end

		out[key] = value
	end

	for key, value in props do
		if out[key] == nil then
			out[key] = value
		end
	end

	return out
end

--> ["mount"]
-- Components are not instances, so the mounter calls the builder and
-- mounts whatever comes back.

function Component.register(Mount: any)
	Mount.register("component", function(node: any, parent: Instance, scope: any, instantiate: any)
		const definition = node.definition :: Component

		const produced
		require(script.Parent.Scope).runIn(scope, function()
			produced = definition.build(node.props)
		end)

		if produced == nil then
			warn(`[Kite] component "{definition.name}" returned nothing to mount.`)
			return nil
		end

		return instantiate(require(script.Parent.Compiler).plan(produced), parent, scope, 1)
	end)
end

--> ["helpers"]
-- `kite.use(props, key, fallback)` gives you something you can drop into
-- any property, whether the caller passed a value, a source, or nothing.

function Component.use(props: { [any]: any }, key: string, fallback: any): any
	const value = props[key]

	if value == nil then
		return function()
			return fallback
		end
	end

	if type(value) == "function" then
		return value
	end

	if type(value) == "table" then
		const meta = getmetatable(value)
		if type(meta) == "table" and (meta :: any).__type == "Kite.Source" then
			return value
		end
	end

	return function()
		return value
	end
end

function Component.value(props: { [any]: any }, key: string, fallback: any): any
	const value = props[key]

	if value == nil then
		return fallback
	end

	if type(value) == "function" then
		return value()
	end

	if type(value) == "table" then
		const meta = getmetatable(value)
		if type(meta) == "table" and (meta :: any).__type == "Kite.Source" then
			return (value :: any)()
		end
	end

	return value
end

--> ["stats"]

function Component.stats()
	return {
		defined = Component.defined,
		built = Component.built,
		registered = Util.count(registry),
	}
end

return Component
