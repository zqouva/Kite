--!strict
--[=[
	--> ["Kite : Mount"]

	Takes a plan and builds the real thing.

	The mount order is deliberate:

		1. create the instance
		2. write every static property
		3. mount children
		4. attach attributes, tags, and refs
		5. parent it, once, last
		6. open bindings and events

	Parenting last is what keeps Roblox from laying the tree out once per
	property. Bindings open after parenting so the first frame is already
	correct.

	--> ["one effect per instance"]
	Every dynamic property on an instance shares a single effect. Ten
	animated properties on one frame is one node in the graph, not ten.
]=]

const Util = require(script.Parent.Util)
const Scope = require(script.Parent.Scope)
const Graph = require(script.Parent.Graph)
const Config = require(script.Parent.Config)
const Types = require(script.Parent.Types)
const Compiler = require(script.Parent.Compiler)

const CollectionService = game:GetService("CollectionService")

export type Handle = {
	kind: string,
	instance: Instance,
	scope: Scope.Scope,
	alive: boolean,
	destroy: (Handle) -> (),
	find: (Handle, string) -> Instance?,
}

const Mount = {}

Mount.mounts = 0 :: number
Mount.instances = 0 :: number
Mount.writes = 0 :: number
Mount.bindings = 0 :: number
Mount.events = 0 :: number
Mount.cachedHome = nil :: Instance?

const handlers: { [string]: (any, Instance, Scope.Scope, any, number?) -> any } = {}

function Mount.register(kind: string, fn: (any, Instance, Scope.Scope, any, number?) -> any)
	handlers[kind] = fn
end

--> ["elements"]

function Mount.create(className: string): ({ [any]: any }) -> any
	if type(className) ~= "string" then
		error(
			`[Kite] kite.create needs a class name string, you gave it {Util.show(className)}.\n`
				.. `  try: kite.create "Frame" \{ Size = UDim2.fromOffset(100, 100) \}`,
			2
		)
	end

	return function(props: { [any]: any }?): any
		return {
			kind = "element",
			class = className,
			props = props or {},
		}
	end
end

function Mount.element(className: string, props: { [any]: any }?): any
	return Mount.create(className)(props or {})
end

function Mount.from(instance: Instance): any
	return {
		kind = "instance",
		node = instance,
	}
end

--> ["instantiate"]

local function applyDynamics(instance: Instance, dynamics: { { [number]: any } })
	const total = #dynamics
	const last = table.create(total, nil)

	Graph.effect(function()
		for index = 1, total do
			const entry = dynamics[index]
			const value = entry[2]()

			if not Util.equal(value, last[index]) then
				last[index] = value
				instance[entry[1]] = Types.fit(instance.ClassName, entry[1], value)
				Mount.writes += 1
			end
		end
	end)

	Mount.bindings += 1
end

local function applyEvents(instance: Instance, events: { { [number]: any } })
	for index = 1, #events do
		const entry = events[index]
		const signal = (instance :: any)[entry[1]]

		-- anything with a Connect method counts, which covers Roblox
		-- signals, Kite signals, and whatever your own code gives you
		const connectable = typeof(signal) == "RBXScriptSignal"
			or (type(signal) == "table" and type((signal :: any).Connect) == "function")

		if not connectable then
			warn(`[Kite] {instance.ClassName} has no event called "{entry[1]}", so the handler was skipped.`)
			continue
		end

		const connection = signal:Connect(entry[2])
		Scope.cleanup(function()
			connection:Disconnect()
		end)

		Mount.events += 1
	end
end

function Mount.instantiate(plan: any, parent: Instance, scope: Scope.Scope, index: number?): Instance?
	if plan == nil then
		return nil
	end

	const kind = plan.kind

	if kind == "element" then
		const instance: Instance = Instance.new(plan.class :: string)
		Mount.instances += 1

		Scope.cleanup(function()
			if instance.Parent ~= nil or true then
				instance:Destroy()
			end
		end)

		if plan.statics then
			const statics = plan.statics
			for entry = 1, #statics do
				const pair = statics[entry]
				instance[pair[1]] = pair[2]
				Mount.writes += 1
			end
		end

		if plan.attrs then
			for key, value in plan.attrs do
				instance:SetAttribute(key, value)
			end
		end

		if plan.tags then
			for _, tag in plan.tags do
				CollectionService:AddTag(instance, tag)
			end
		end

		if plan.children then
			for childIndex, childPlan in plan.children do
				Mount.instantiate(childPlan, instance, scope, childIndex)
			end
		end

		instance.Parent = parent

		if plan.dynamics then
			applyDynamics(instance, plan.dynamics)
		end

		if plan.events then
			applyEvents(instance, plan.events)
		end

		if plan.refs then
			for _, ref in plan.refs do
				if type(ref) == "function" then
					ref(instance)
				elseif type(ref) == "table" then
					if type((ref :: any).set) == "function" then
						(ref :: any).set(instance)
					else
						(ref :: any).current = instance
					end
				end
			end
		end

		if plan.effects then
			for _, effect in plan.effects do
				Graph.effect(function()
					return effect(instance)
				end)
			end
		end

		return instance
	end

	if kind == "instance" then
		const instance = plan.node :: Instance
		instance.Parent = parent
		return instance
	end

	const handler = handlers[kind]

	if handler then
		return handler(plan.node or plan, parent, scope, Mount.instantiate, index)
	end

	-- unknown node: maybe it is a plain instance that fell through
	if typeof(plan) == "Instance" then
		plan.Parent = parent
		return plan
	end

	error(`[Kite] cannot mount a node of kind "{tostring(kind)}". kite.help("nodes") lists them.`, 2)
end

--> ["mount"]

const Handle = {} :: { [string]: any }
Handle.__type = "Kite.Handle"
Handle.__index = Handle

function Handle.destroy(self: Handle)
	if not self.alive then
		return
	end
	self.alive = false
	Scope.destroy(self.scope)
end

function Handle.find(self: Handle, name: string): Instance?
	return self.instance:FindFirstChild(name, true)
end

function Handle.wait(self: Handle, name: string, timeout: number?): Instance?
	return self.instance:WaitForChild(name, timeout or 5)
end

function Handle:Destroy()
	Handle.destroy(self)
end

function Handle:__tostring(): string
	return `Kite.Handle({self.instance.ClassName})`
end

--> ["default parent"]
-- You almost always want PlayerGui. Say it once here and never again.

function Mount.home(): Instance
	if Mount.cachedHome and Mount.cachedHome.Parent ~= nil then
		return Mount.cachedHome
	end

	const players = (game :: any):GetService("Players")
	const player = players.LocalPlayer

	if player == nil then
		error("[Kite] kite.mount needs a parent, or a LocalPlayer to borrow PlayerGui from", 3)
	end

	const playerGui = player:WaitForChild("PlayerGui")
	Mount.cachedHome = playerGui

	return playerGui
end

function Mount.go(build: () -> any, options: { mode: string?, name: string?, batch: boolean?, parent: Instance? }?): Handle
	if type(build) ~= "function" then
		error(
			"[Kite] kite.go wants a function that returns a tree.\n"
				.. "  kite.go(function()\n"
				.. "    return kite.create `ScreenGui` { ... }\n"
				.. "  end)",
			2
		)
	end

	--> ["the builder runs inside the scope"]
	-- Sources, derives, and effects made in the builder belong to the tree,
	-- not to the script, so destroying the handle stops all of them.

	const scope = Scope.create((options and options.name) or "go")

	Scope.push(scope)
	const ok, element = pcall(build)
	Scope.pop()

	if not ok then
		Scope.destroy(scope)
		error(element, 0)
	end

	if element == nil then
		Scope.destroy(scope)
		error("[Kite] the function you gave kite.go returned nothing. return the tree you built.", 2)
	end

	return Mount.mount(element, (options and options.parent) or nil, options, scope)
end

function Mount.mount(
	element: any,
	parent: Instance?,
	options: { mode: string?, name: string?, batch: boolean? }?,
	preset: Scope.Scope?
): Handle
	if parent == nil then
		parent = Mount.home()
	end

	if typeof(parent) == "table" and parent ~= nil and (parent :: any).kind == "element" then
		error(
			"[Kite] you passed a Kite element where the parent instance goes.\n"
				.. "  kite.mount(element, parent)  -- parent is a real Instance, like PlayerGui",
			2
		)
	end

	const previous = Config.mode

	if options and options.mode then
		Config.apply(options.mode)
	end

	const scope = preset or Scope.create((options and options.name) or "mount")
	Scope.push(scope)

	const plan = Compiler.plan(element)
	const instance = Mount.instantiate(plan, parent :: Instance, scope, 1)

	Scope.pop()

	if options and options.mode then
		Config.apply(previous)
	end

	Mount.mounts += 1

	if instance == nil then
		error("[Kite] the tree mounted to nothing. kite.help(\"mount\") shows the shapes that work.", 2)
	end

	const handle = {
		kind = "handle",
		instance = instance,
		scope = scope,
		alive = true,
	}

	return setmetatable(handle, Handle) :: any
end

--> ["hydrate"]
-- Mounts onto an instance that already exists, so Kite can take over one
-- screen built in Studio without rebuilding it.

function Mount.hydrate(element: any, instance: Instance, options: { name: string? }?): Handle
	const scope = Scope.create((options and options.name) or "hydrate")
	Scope.push(scope)

	const plan = Compiler.plan(element)

	if plan.kind ~= "element" then
		error("[Kite] hydrate expects a single element as its first argument.", 2)
	end

	if plan.statics then
		for _, pair in plan.statics do
			instance[pair[1]] = pair[2]
		end
	end

	if plan.children then
		for index, childPlan in plan.children do
			Mount.instantiate(childPlan, instance, scope, index)
		end
	end

	if plan.dynamics then
		applyDynamics(instance, plan.dynamics)
	end

	if plan.events then
		applyEvents(instance, plan.events)
	end

	Scope.pop()

	Mount.mounts += 1

	return setmetatable({
		kind = "handle",
		instance = instance,
		scope = scope,
		alive = true,
	}, Handle) :: any
end

--> ["ref"]

function Mount.ref(): any
	const ref = {
		kind = "ref",
		current = nil :: Instance?,
	}

	function ref.set(instance: Instance)
		ref.current = instance
	end

	function ref.get(): Instance?
		return ref.current
	end

	function ref.wait(): Instance
		const started = os.clock()
		while ref.current == nil and os.clock() - started < 5 do
			task.wait()
		end
		return ref.current :: Instance
	end

	return setmetatable(ref, {
		__type = "Kite.Ref",
		__call = function(self: any)
			return self.current
		end,
		__index = ref,
	})
end

--> ["portal"]
-- Mounts a tree somewhere else entirely, while it stays owned by the scope
-- it was written in. Used for tooltips, drag layers, and world space UI.

function Mount.portal(element: any, target: Instance): any
	return {
		kind = "portal",
		element = element,
		target = target,
	}
end

Mount.register("portal", function(node, _parent, scope, instantiate)
	const handle = Mount.mount(node.element, node.target)
	Scope.cleanup(function()
		handle:destroy()
	end)
	return handle.instance
end)

--> ["stats"]

function Mount.stats()
	return {
		mounts = Mount.mounts,
		instances = Mount.instances,
		writes = Mount.writes,
		bindings = Mount.bindings,
		events = Mount.events,
	}
end

function Mount.reset()
	Mount.mounts = 0
	Mount.instances = 0
	Mount.writes = 0
	Mount.bindings = 0
	Mount.events = 0
end

return Mount
