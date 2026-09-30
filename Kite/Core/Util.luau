--!strict
--[=[
	--> ["Kite : Util"]

	Small helpers shared across the package.
	Nothing here is reactive. Nothing here touches instances.

	--> ["why this exists"]
	Kite wants to *guide* you. That means error messages have to name the
	thing you actually wrote, not a raw Luau type code. This module is the
	vocabulary those messages are built from.
]=]

const Util = {}

export type Entry = { [any]: any }

--> ["naming"]
-- Roblox's typeof reads a table's `__type` field. Outside Studio it does
-- not, so Kite asks once, here, and everything else reads through this.

function Util.kindOf(value: any): string
	const kind = typeof(value)

	if kind == "table" then
		const meta = getmetatable(value)

		if type(meta) == "table" then
			const named = (meta :: any).__type

			if type(named) == "string" then
				return named :: string
			end
		end
	end

	return kind
end

function Util.typeName(value: any): string
	const kind = typeof(value)

	if kind == "Instance" then
		return value.ClassName
	end

	if kind == "table" then
		const meta = getmetatable(value)
		if type(meta) == "table" and type(meta.__type) == "string" then
			return meta.__type :: string
		end

		if type(meta) == "table" and type(meta.__index) == "table" then
			const index = meta.__index
			const own = (index :: any)._type
			if type(own) == "string" then
				return own :: string
			end
		end

		return "table"
	end

	return kind
end

--> ["show"]
-- Short, human rendering of a value for error text. Never throws.

function Util.show(value: any): string
	const kind = typeof(value)

	if kind == "string" then
		return `"{value}"`
	end

	if kind == "number" then
		if value % 1 == 0 then
			return tostring(value)
		end
		return string.format("%.3f", value)
	end

	if kind == "Instance" then
		return `{value.ClassName}("{value.Name}")`
	end

	if kind == "table" then
		const count = 0
		for _ in value do
			count += 1
			if count > 4 then
				break
			end
		end
		return `table({count}+)`
	end

	return tostring(value)
end

--> ["math"]

function Util.clamp(value: number, low: number, high: number): number
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

function Util.lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

function Util.map(value: number, inLow: number, inHigh: number, outLow: number, outHigh: number): number
	if inHigh == inLow then
		return outLow
	end
	const alpha = (value - inLow) / (inHigh - inLow)
	return Util.lerp(outLow, outHigh, alpha)
end

function Util.round(value: number, places: number?): number
	const factor = 10 ^ (places or 0)
	return math.round(value * factor) / factor
end

--> ["equality"]
-- Kite treats NaN == NaN as true because a spring settling on NaN should not
-- scream at you forever.

function Util.equal(left: any, right: any): boolean
	if left == right then
		return true
	end

	const kind = typeof(left)
	if kind ~= typeof(right) then
		return false
	end

	if kind == "number" then
		return left ~= left and right ~= right
	end

	if kind == "table" then
		const meta = getmetatable(left)
		if type(meta) == "table" and type((meta :: any).__eq) == "function" then
			return left == right
		end

		for key, value in left do
			if not Util.equal(value, (right :: any)[key]) then
				return false
			end
		end

		for key in right do
			if (left :: any)[key] == nil then
				return false
			end
		end

		return true
	end

	return false
end

--> ["color"]
-- `#3ddad7`, `3ddad7`, `#3dd`, Color3, or { r, g, b } in 0..1.

function Util.hex(source: any): Color3
	const kind = Util.kindOf(source)

	if kind == "Color3" then
		return source
	end

	if kind == "table" then
		const r = (source :: any)[1] or (source :: any).R or 0
		const g = (source :: any)[2] or (source :: any).G or 0
		const b = (source :: any)[3] or (source :: any).B or 0
		return Color3.new(r, g, b)
	end

	if kind ~= "string" then
		error(`[Kite] Util.hex cannot read {Util.show(source)}`, 2)
	end

	const text = source :: string
	if string.sub(text, 1, 1) == "#" then
		text = string.sub(text, 2)
	end

	if #text == 3 then
		const r = string.sub(text, 1, 1)
		const g = string.sub(text, 2, 2)
		const b = string.sub(text, 3, 3)
		text = r .. r .. g .. g .. b .. b
	end

	if #text ~= 6 then
		error(`[Kite] "{text}" is not a 6 digit hex color`, 2)
	end

	return Color3.fromHex(text)
end

--> ["layout"]
-- Creative mode shorthands land here.

function Util.udim2(scaleX, offsetX, scaleY, offsetY): UDim2
	return UDim2.new(scaleX, offsetX, scaleY, offsetY)
end

function Util.size(source: any): UDim2
	const kind = Util.kindOf(source)

	if kind == "UDim2" then
		return source
	end

	if kind == "string" then
		if source == "fill" then
			return UDim2.fromScale(1, 1)
		end
		if source == "full" then
			return UDim2.fromScale(1, 1)
		end
		if source == "auto" then
			return UDim2.fromOffset(0, 0)
		end
		error(`[Kite] unknown size shorthand "{source}"`, 3)
	end

	if kind == "number" then
		return UDim2.fromOffset(source, source)
	end

	if kind == "table" then
		const entry = source :: Util.Entry
		if entry.x ~= nil or entry.y ~= nil then
			return UDim2.new(
				if entry.x then 1 else 0,
				if typeof(entry.x) == "number" then entry.x else 0,
				if entry.y then 1 else 0,
				if typeof(entry.y) == "number" then entry.y else 0
			)
		end
		const total = #entry

		if total == 2 then
			-- { 220, 120 } reads as width and height in pixels
			return UDim2.new(0, entry[1] or 0, 0, entry[2] or 0)
		end

		if total == 3 then
			return UDim2.new(entry[1] or 0, entry[2] or 0, entry[3] or 0, 0)
		end

		return UDim2.new(entry[1] or 0, entry[2] or 0, entry[3] or 0, entry[4] or 0)
	end

	error(`[Kite] Util.size cannot read {Util.show(source)}`, 2)
end

function Util.padding(source: any): UDim
	const kind = Util.kindOf(source)

	if kind == "UDim" then
		return source
	end
	if kind == "number" then
		return UDim.new(0, source)
	end
	if kind == "table" then
		const entry = source :: Util.Entry
		if entry[1] ~= nil then
			return UDim.new(entry[1], entry[2] or 0)
		end
		return UDim.new(entry.scale or 0, entry.offset or 0)
	end
	error(`[Kite] Util.padding cannot read {Util.show(source)}`, 2)
end

--> ["tables"]

function Util.freeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value) then
		table.freeze(value)
	end
	return value
end

function Util.count(source: { [any]: any }): number
	const total = 0
	for _ in source do
		total += 1
	end
	return total
end

function Util.keys<T>(source: { [T]: any }): { T }
	const out = {}
	for key in source do
		table.insert(out, key)
	end
	return out
end

function Util.sorted<T>(source: { T }, by: ((T) -> any)?): { T }
	const copy = table.clone(source) :: { T }

	if by then
		table.sort(copy, function(left, right)
			return (by :: any)(left) < (by :: any)(right)
		end)
	else
		table.sort(copy)
	end

	return copy
end

--> ["strings"]

function Util.wrap(text: string, width: number): { string }
	const lines = {}
	const line = ""

	for word in string.gmatch(text, "%S+") do
		if #line == 0 then
			line = word
		elseif #line + 1 + #word <= width then
			line ..= " " .. word
		else
			table.insert(lines, line)
			line = word
		end
	end

	if #line > 0 then
		table.insert(lines, line)
	end

	return lines
end

function Util.pad(text: string, width: number): string
	if #text >= width then
		return text
	end
	return text .. string.rep(" ", width - #text)
end

function Util.title(text: string): string
	const head = string.sub(text, 1, 1)
	return string.upper(head) .. string.sub(text, 2)
end

--> ["suggestions"]
-- Levenshtein distance, capped. Powers `did you mean`.

function Util.distance(left: string, right: string): number
	if left == right then
		return 0
	end

	const leftLength = #left
	const rightLength = #right

	if leftLength == 0 then
		return rightLength
	end
	if rightLength == 0 then
		return leftLength
	end

	const previous = table.create(rightLength + 1, 0)
	const current = table.create(rightLength + 1, 0)

	for index = 0, rightLength do
		previous[index + 1] = index
	end

	for i = 1, leftLength do
		current[1] = i

		for j = 1, rightLength do
			const cost = if string.sub(left, i, i) == string.sub(right, j, j) then 0 else 1
			current[j + 1] = math.min(
				current[j] + 1,
				previous[j + 1] + 1,
				previous[j] + cost
			)
		end

		previous, current = current, previous
	end

	return previous[rightLength + 1]
end

function Util.nearest(needle: string, haystack: { string }): string?
	const best: string? = nil
	const bestScore = math.huge

	for _, candidate in haystack do
		const score = Util.distance(string.lower(needle), string.lower(candidate))
		if score < bestScore then
			bestScore = score
			best = candidate
		end
	end

	if bestScore > math.max(3, math.floor(#needle / 2)) then
		return nil
	end

	return best
end

--> ["instances"]

function Util.isInstance(value: any): boolean
	return typeof(value) == "Instance"
end

function Util.childrenOf(instance: Instance): { Instance }
	const out = {}
	for _, child in instance:GetChildren() do
		table.insert(out, child)
	end
	return out
end

return Util
