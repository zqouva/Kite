--!strict
--[=[
	--> ["Kite : Tests : Harness"]

	A test runner small enough to read in one sitting.

		Harness.group("reactivity", function() ... end)
		Harness.test("a source holds a value", function() ... end)

		Harness.eq(actual, expected, "what it should be")
		Harness.truthy(value, "why it should be true")
		Harness.throws(fn, "part of the message", "why it should throw")
]=]

local Harness = {}

Harness.passed = 0 :: number
Harness.failed = 0 :: number
Harness.skipped = 0 :: number
Harness.failures = {} :: { { group: string, name: string, reason: string } }
Harness.timings = {} :: { { group: string, name: string, ms: number } }

local currentGroup = "ungrouped"
local currentName = "untitled"

local function fail(reason: string)
	Harness.failed += 1
	table.insert(Harness.failures, {
		group = currentGroup,
		name = currentName,
		reason = reason,
	})
end

function Harness.group(name: string, fn: () -> ())
	currentGroup = name
	local results = table.pack(pcall(fn))
	if not results[1] then
		fail(`the group itself threw: {results[2]}`)
	end
end

function Harness.test(name: string, fn: () -> ())
	currentName = name
	local started = os.clock()

	local results = table.pack(pcall(fn))
	local took = (os.clock() - started) * 1000

	table.insert(Harness.timings, { group = currentGroup, name = name, ms = took })

	if results[1] then
		if Harness.failed > 0 and Harness.failures[#Harness.failures].name == name then
			-- a failure was already recorded inside the test
		else
			Harness.passed += 1
		end
	else
		fail(`threw: {results[2]}`)
	end
end

function Harness.skip(name: string, why: string)
	Harness.skipped += 1
	currentName = name
	table.insert(Harness.failures, { group = currentGroup, name = name, reason = `skipped: {why}` })
end

--> ["assertions"]

local function show(value: any): string
	if typeof(value) == "Instance" then
		return `{value.ClassName}("{value.Name}")`
	end
	if type(value) == "table" then
		local count = 0
		for _ in value do
			count += 1
		end
		return `table({count})`
	end
	if type(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

function Harness.eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		fail(`{label or "value"}: expected {show(expected)}, got {show(actual)}`)
	end
end

function Harness.ne(actual: any, unexpected: any, label: string?)
	if actual == unexpected then
		fail(`{label or "value"}: expected anything but {show(unexpected)}`)
	end
end

function Harness.near(actual: number, expected: number, tolerance: number?, label: string?)
	local allowed = tolerance or 1e-6
	if math.abs(actual - expected) > allowed then
		fail(`{label or "number"}: expected {expected} within {allowed}, got {actual}`)
	end
end

function Harness.truthy(value: any, label: string?)
	if not value then
		fail(`{label or "value"}: expected something true, got {show(value)}`)
	end
end

function Harness.falsy(value: any, label: string?)
	if value then
		fail(`{label or "value"}: expected something false, got {show(value)}`)
	end
end

function Harness.contains(text: string, needle: string, label: string?)
	if not string.find(text, needle, 1, true) then
		local excerpt = string.sub(text, 1, 160)
		fail(`{label or "text"}: expected to find "{needle}" in: {excerpt}`)
	end
end

function Harness.missing(text: string, needle: string, label: string?)
	if string.find(text, needle, 1, true) then
		fail(`{label or "text"}: expected NOT to find "{needle}"`)
	end
end

function Harness.throws(fn: () -> any, needle: string?, label: string?)
	local ok, reason = pcall(fn)

	if ok then
		fail(`{label or "call"}: expected it to throw, it did not`)
		return
	end

	if needle and not string.find(tostring(reason), needle, 1, true) then
		fail(`{label or "call"}: expected the error to mention "{needle}", got: {tostring(reason)}`)
	end
end

function Harness.count(actual: number, expected: number, label: string?)
	Harness.eq(actual, expected, label)
end

--> ["report"]

function Harness.text(slow: number?): string
	local lines = {}

	table.insert(lines, "")
	table.insert(lines, `  {Harness.passed} passed, {Harness.failed} failed, {Harness.skipped} skipped`)
	table.insert(lines, "")

	if Harness.failed > 0 then
		table.insert(lines, "  failures")
		for _, entry in Harness.failures do
			table.insert(lines, `    [{entry.group}] {entry.name}`)
			table.insert(lines, `      {entry.reason}`)
		end
		table.insert(lines, "")
	end

	local limit = slow or 5
	local slowest = table.clone(Harness.timings)
	table.sort(slowest, function(left, right)
		return left.ms > right.ms
	end)

	table.insert(lines, `  slowest {limit}`)
	for index = 1, math.min(limit, #slowest) do
		local entry = slowest[index]
		table.insert(lines, `    {string.format("%8.3f", entry.ms)}ms  {entry.group} :: {entry.name}`)
	end
	table.insert(lines, "")

	return table.concat(lines, "\n")
end

function Harness.done(): number
	print(Harness.text())
	return if Harness.failed > 0 then 1 else 0
end

return Harness
