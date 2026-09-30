--!strict
--[=[
	--> ["Kite : Spring"]

	Motion. One frame connection for the whole game, however many things
	are moving. Nothing spins up a heartbeat per property.

	Three flavors:

		kite.spring  physics        overshoots, settles, feels alive
		kite.tween   time based     exact duration, eased
		kite.damp    exponential    never overshoots, frame rate safe

	All three take the same thing you would hand a property: a source, or a
	function that reads sources. All three hand back a source you can put
	straight into a property.

	--> ["example"]
	```lua
	const open = kite.source(false)

	kite.create `Frame` {
		Position = kite.spring(function()
			return if open() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 1)
		end, { speed = 0.28 }),
	}
	```

	--> ["why it is fast"]
	A motion is a flat table with preallocated fields. The driver is one
	array walked in order, no closures per frame, no tables per frame, and
	it disconnects itself the moment the last motion settles.
]=]

const Util = require(script.Parent.Util)
const Scope = require(script.Parent.Scope)

export type Motion = {
	kind: string,
	valueKind: string,
	value: any,
	target: any,
	read: () -> any,
	outlet: (any) -> (),
	velocity: any,
	speed: number,
	damping: number,
	time: number,
	elapsed: number,
	from: any,
	ease: ((number) -> number)?,
	precision: number,
	alive: boolean,
	scope: Scope.Scope?,
}

const Spring = {}

const RunService = game:GetService("RunService")

const motions: { Motion } = {} :: { Motion }
const connection: RBXScriptConnection? = nil
const active = false

Spring.frames = 0 :: number
Spring.steps = 0 :: number
Spring.motions = 0 :: number

--> ["easing"]
-- Pure functions. `t` in 0..1, returns 0..1.

const ease = {} :: { [string]: (number) -> number }

local function inOut(kind: (number) -> number): (number) -> number
	return function(t: number): number
		if t < 0.5 then
			return kind(t * 2) / 2
		end
		return 1 - kind((1 - t) * 2) / 2
	end
end

ease.Linear = function(t: number): number
	return t
end

ease.Quad = function(t: number): number
	return t * t
end
ease.Cubic = function(t: number): number
	return t * t * t
end
ease.Quart = function(t: number): number
	return t * t * t * t
end
ease.Quint = function(t: number): number
	return t * t * t * t * t
end
ease.Sine = function(t: number): number
	return 1 - math.cos((t * math.pi) / 2)
end
ease.Expo = function(t: number): number
	if t <= 0 then
		return 0
	end
	return 2 ^ (10 * t - 10)
end
ease.Circ = function(t: number): number
	return 1 - math.sqrt(1 - t * t)
end
ease.Back = function(t: number): number
	const c = 1.70158
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end
ease.Elastic = function(t: number): number
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * ((2 * math.pi) / 3)) + 1
end
ease.Bounce = function(t: number): number
	if t < 1 / 2.75 then
		return 7.5625 * t * t
	elseif t < 2 / 2.75 then
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elseif t < 2.5 / 2.75 then
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	end
	t -= 2.625 / 2.75
	return 7.5625 * t * t + 0.984375
end

for name, fn in table.clone(ease) do
	ease[`{name}In`] = fn
	ease[`{name}Out`] = function(t: number): number
		return 1 - fn(1 - t)
	end
	ease[`{name}InOut`] = inOut(fn)
end

Spring.ease = table.freeze(ease)

--> ["generic lerp"]
-- Roblox already knows how to lerp its own value types, so ask it.

local function lerpValue(kind: string, from: any, to: any, alpha: number): any
	if kind == "number" then
		return Util.lerp(from, to, alpha)
	end

	if kind == "Color3" then
		return from:Lerp(to, alpha)
	end

	if kind == "Vector2" then
		return from:Lerp(to, alpha)
	end

	if kind == "Vector3" then
		return from:Lerp(to, alpha)
	end

	if kind == "UDim" then
		return from:Lerp(to, alpha)
	end

	if kind == "UDim2" then
		return from:Lerp(to, alpha)
	end

	if kind == "CFrame" then
		return from:Lerp(to, alpha)
	end

	if kind == "number" then
		return Util.lerp(from, to, alpha)
	end

	return if alpha < 0.5 then from else to
end

local function zeroOf(kind: string): any
	if kind == "number" then
		return 0
	end
	if kind == "Vector2" then
		return Vector2.zero
	end
	if kind == "Vector3" then
		return Vector3.zero
	end
	if kind == "UDim" then
		return UDim.new(0, 0)
	end
	if kind == "UDim2" then
		return UDim2.new(0, 0, 0, 0)
	end
	if kind == "Color3" then
		return Color3.new(0, 0, 0)
	end

	return 0
end

local function distanceOf(kind: string, left: any, right: any): number
	if kind == "number" then
		return math.abs(left - right)
	end
	if kind == "Vector2" or kind == "Vector3" then
		return (left - right).Magnitude
	end
	if kind == "UDim" then
		return math.abs(left.Scale - right.Scale) + math.abs(left.Offset - right.Offset) / 1000
	end
	if kind == "UDim2" then
		const dx = left.X.Scale - right.X.Scale
		const dy = left.Y.Scale - right.Y.Scale
		const ox = (left.X.Offset - right.X.Offset) / 1000
		const oy = (left.Y.Offset - right.Y.Offset) / 1000
		return math.sqrt(dx * dx + dy * dy + ox * ox + oy * oy)
	end
	if kind == "Color3" then
		const r = left.R - right.R
		const g = left.G - right.G
		const b = left.B - right.B
		return math.sqrt(r * r + g * g + b * b)
	end

	return if left == right then 0 else 1
end

local function addValue(kind: string, left: any, right: any): any
	if kind == "number" then
		return left + right
	end
	if kind == "Vector2" then
		return left + right
	end
	if kind == "Vector3" then
		return left + right
	end
	if kind == "UDim" then
		return UDim.new(left.Scale + right.Scale, left.Offset + right.Offset)
	end
	if kind == "UDim2" then
		return UDim2.new(
			left.X.Scale + right.X.Scale,
			left.X.Offset + right.X.Offset,
			left.Y.Scale + right.Y.Scale,
			left.Y.Offset + right.Y.Offset
		)
	end
	if kind == "Color3" then
		return Color3.new(left.R + right.R, left.G + right.G, left.B + right.B)
	end

	return left
end

local function subValue(kind: string, left: any, right: any): any
	if kind == "number" then
		return left - right
	end
	if kind == "Vector2" then
		return left - right
	end
	if kind == "Vector3" then
		return left - right
	end
	if kind == "UDim" then
		return UDim.new(left.Scale - right.Scale, left.Offset - right.Offset)
	end
	if kind == "UDim2" then
		return UDim2.new(
			left.X.Scale - right.X.Scale,
			left.X.Offset - right.X.Offset,
			left.Y.Scale - right.Y.Scale,
			left.Y.Offset - right.Y.Offset
		)
	end
	if kind == "Color3" then
		return Color3.new(left.R - right.R, left.G - right.G, left.B - right.B)
	end

	return left
end

local function scaleValue(kind: string, value: any, factor: number): any
	if kind == "number" then
		return value * factor
	end
	if kind == "Vector2" then
		return value * factor
	end
	if kind == "Vector3" then
		return value * factor
	end
	if kind == "UDim" then
		return UDim.new(value.Scale * factor, value.Offset * factor)
	end
	if kind == "UDim2" then
		return UDim2.new(
			value.X.Scale * factor,
			value.X.Offset * factor,
			value.Y.Scale * factor,
			value.Y.Offset * factor
		)
	end
	if kind == "Color3" then
		return Color3.new(value.R * factor, value.G * factor, value.B * factor)
	end

	return value
end

--> ["steps"]

local function stepSpring(motion: Motion, delta: number)
	const kind = motion.valueKind
	const target = motion.target
	const omega = (2 * math.pi) * motion.speed
	const damp = motion.damping

	const f = 1 + 2 * delta * damp * omega
	const oo = omega * omega
	const hoo = delta * oo
	const hhoo = delta * hoo
	const inverse = 1 / (f + hhoo)

	-- UDim2 and friends have no arithmetic operators, so this stays generic
	const displacement = subValue(kind, motion.value, target)
	const detX = addValue(
		kind,
		scaleValue(kind, motion.value, f),
		addValue(kind, scaleValue(kind, motion.velocity, delta), scaleValue(kind, target, hhoo))
	)
	const detV = addValue(kind, motion.velocity, scaleValue(kind, displacement, -hoo))

	motion.value = scaleValue(kind, detX, inverse)
	motion.velocity = scaleValue(kind, detV, inverse)

	if
		distanceOf(kind, motion.value, target) < motion.precision
		and distanceOf(kind, motion.velocity, zeroOf(kind)) < motion.precision * 10
	then
		motion.value = target
		motion.velocity = zeroOf(kind)
		return true
	end

	return false
end

local function stepTween(motion: Motion, delta: number): boolean
	motion.elapsed += delta

	const alpha = if motion.time <= 0 then 1 else Util.clamp(motion.elapsed / motion.time, 0, 1)
	const shaped = if motion.ease then motion.ease(alpha) else alpha

	motion.value = lerpValue(motion.valueKind, motion.from, motion.target, shaped)

	return alpha >= 1
end

local function stepDamp(motion: Motion, delta: number): boolean
	const alpha = 1 - math.exp(-motion.speed * delta)
	motion.value = lerpValue(motion.valueKind, motion.value, motion.target, alpha)

	return distanceOf(motion.valueKind, motion.value, motion.target) < motion.precision
end

--> ["driver"]

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	active = false
end

local function step(delta: number)
	Spring.frames += 1
	Spring.motions = #motions

	const write = 0

	for index = 1, #motions do
		const motion = motions[index]

		if not motion.alive then
			continue
		end

		const wanted = motion.read()

		if not Util.equal(wanted, motion.target) then
			if motion.kind == "tween" then
				motion.from = motion.value
				motion.elapsed = 0
			end
			motion.target = wanted
		end

		const done = false

		if motion.kind == "spring" then
			done = stepSpring(motion, delta)
		elseif motion.kind == "tween" then
			done = stepTween(motion, delta)
		elseif motion.kind == "clock" then
			motion.elapsed += delta
			motion.value = motion.elapsed
		else
			done = stepDamp(motion, delta)
		end

		Spring.steps += 1
		motion.outlet(motion.value)

		if done then
			motion.alive = false
			Spring.motions -= 1
		else
			write += 1
			motions[write] = motion
		end
	end

	for index = write + 1, #motions do
		motions[index] = nil
	end

	if write == 0 then
		stop()
	end
end

local function start()
	if active then
		return
	end

	active = true

	const event = if RunService:IsClient() then RunService.RenderStepped else RunService.Heartbeat

	connection = event:Connect(function(delta: number)
		step(math.min(delta, 1 / 20))
	end)
end

--> ["create"]

local function adopt(motion: Motion)
	const scope = Scope.current()

	if scope and not scope.dead then
		motion.scope = scope
		Scope.cleanup(function()
			motion.alive = false
		end)
	end

	table.insert(motions, motion)
	Spring.motions += 1
	start()
end

local function readerOf(target: any): () -> any
	const kind = type(target)

	if kind == "function" then
		return target :: any
	end

	if kind == "table" and (getmetatable(target) :: any) == nil then
		error(
			"[Kite] a motion needs a source or a function to read from.\n"
				.. "  you handed it a plain table. try: kite.spring(function() return ... end)",
			3
		)
	end

	return function()
		return target()
	end
end

export type Options = {
	speed: number?,
	damping: number?,
	time: number?,
	ease: ((number) -> number)?,
	precision: number?,
}

local function normalize(second: any, third: any): Options
	if type(second) == "table" then
		return second :: Options
	end

	if type(second) == "number" then
		if third == nil then
			return { speed = second }
		end
		return { speed = second, damping = third :: number }
	end

	return {}
end

--> ["public"]

function Spring.motion(kind: string, target: any, options: Options?): any
	const opts = options or {}
	const read = readerOf(target)
	const initial = read()

	const out = (require(script.Parent.Graph) :: any).source(initial, { name = kind })

	const motion: Motion = {
		kind = kind,
		valueKind = Util.kindOf(initial),
		value = initial,
		target = initial,
		read = read,
		outlet = function(value: any)
			out(value)
		end,
		velocity = zeroOf(Util.kindOf(initial)),
		speed = if kind == "damp" then (opts.speed or 12) else (opts.speed or 1),
		damping = opts.damping or 1,
		time = opts.time or 0.3,
		elapsed = 0,
		from = initial,
		ease = opts.ease,
		precision = opts.precision or 0.0015,
		alive = true,
		scope = nil,
	}

	adopt(motion)

	const handle = setmetatable({
		kind = "motion",
		motion = motion,
		get = function()
			return out()
		end,
		stop = function()
			motion.alive = false
		end,
		jump = function(value: any)
			motion.value = value
			motion.target = value
			motion.velocity = zeroOf(motion.valueKind)
			out(value)
		end,
	}, {
		__type = "Kite.Motion",
		__call = function(_self: any, value: any)
			if value == nil then
				return out()
			end

			out(value)
			return nil
		end,
		__index = function(_self: any, key: string)
			if key == "Value" then
				return out()
			end
			return nil
		end,
	}) :: any

	return handle
end

function Spring.spring(target: any, second: any, third: any): any
	return Spring.motion("spring", target, normalize(second, third))
end

function Spring.tween(target: any, second: any, third: any): any
	return Spring.motion("tween", target, normalize(second, third))
end

function Spring.damp(target: any, second: any, third: any): any
	return Spring.motion("damp", target, normalize(second, third))
end

--> ["clock"]
--- A source that ticks once per frame with the time since it was created.
---
--- Example:
--- ```lua
--- const clock = kite.clock()
--- kite.create `Frame` { Rotation = clock:map(function(t) return t * 90 end) }
--- ```

function Spring.clock(): any
	const Graph = require(script.Parent.Graph) :: any
	const out = Graph.source(0, { name = "clock" })

	const motion: Motion = {
		kind = "clock",
		valueKind = "number",
		value = 0,
		target = 0,
		read = function()
			return 0
		end,
		outlet = function(value: any)
			out(value)
		end,
		velocity = 0,
		speed = 0,
		damping = 0,
		time = 0,
		elapsed = 0,
		from = 0,
		ease = nil,
		precision = 0,
		alive = true,
		scope = nil,
	}

	adopt(motion)

	return out
end

--> ["install"]
-- Bolts `:spring`, `:tween`, and `:damp` onto every source, so you write
-- `open:spring(0.28)` instead of `kite.spring(open, 0.28)`.

function Spring.install(Graph: any)
	Graph.install("spring", function(self: any, second: any, third: any)
		return Spring.spring(self, second, third)
	end)

	Graph.install("tween", function(self: any, second: any, third: any)
		return Spring.tween(self, second, third)
	end)

	Graph.install("damp", function(self: any, second: any, third: any)
		return Spring.damp(self, second, third)
	end)
end

--> ["stats"]

function Spring.stats()
	return {
		frames = Spring.frames,
		steps = Spring.steps,
		motions = Spring.motions,
		active = active,
		connections = if connection then 1 else 0,
	}
end

function Spring.reset()
	Spring.frames = 0
	Spring.steps = 0
end

Spring._step = step
Spring._stop = stop

return Spring
