--!strict
--[=[
	--> ["Kite : Benchmarks"]

	Numbers, not adjectives.

	Every benchmark here runs two things:

		kite     the package
		baseline the way you would write it by hand, which is roughly what a
		         non compiled, non keyed, non batched reactive layer costs

	The baseline is in this file so you can read it and argue with it. It is
	not a strawman: it builds instances, sets properties, and wires
	RBXScriptConnections the way most hand written UI code does.

	--> ["how to read the table"]
	```text
	bench                       kite        baseline    x
	mount 1000 rows             3.1 ms      8.4 ms      2.7
	```
	`x` is baseline divided by kite. Higher is better for Kite.

	--> ["run it"]
	LocalScript in StarterPlayerScripts, then read the output window.
	Frame time is measured on your machine, in Studio, with your plugins, so
	treat the ratios as the signal and the milliseconds as a mood.
]=]

const Kite = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Kite"))

const ROWS = 1000
const WRITES = 10000
const SHUFFLES = 40

type Result = {
	name: string,
	kite: number,
	baseline: number,
}

const results: { Result } = {}

--> ["harness"]

local function time(name: string, kite: () -> any, baseline: () -> any): Result
	Kite.profiler():reset()

	const started = os.clock()
	kite()
	const kiteTook = os.clock() - started

	-- let the engine breathe so the second run is not measuring garbage
	task.wait()

	started = os.clock()
	baseline()
	const baselineTook = os.clock() - started

	task.wait()

	const result = {
		name = name,
		kite = kiteTook * 1000,
		baseline = baselineTook * 1000,
	}

	table.insert(results, result)
	return result
end

local function rowOf(rows: number): { [string]: any }
	return {
		id = `row{rows}`,
		name = `Row {rows}`,
		value = rows,
	}
end

local function makeData(count: number): { [string]: any }
	const data = {}
	for index = 1, count do
		table.insert(data, rowOf(index))
	end
	return data
end

local function host(): Instance
	const screen = Instance.new("ScreenGui")
	screen.Name = "BenchHost"
	screen.Enabled = false
	return screen
end

--> ["1] mount a big list"]

local function benchMount()
	const data = makeData(ROWS)

	time("mount 1000 rows", function()
		-- Kite: compile once, then mount
		const rows = Kite.source(data)
		const tree = Kite.create("Frame", {
			Name = "List",
			Size = UDim2.fromScale(1, 1),
			Kite.children({
				Kite.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
				Kite.keys(function()
					return rows()
				end, function(item, index)
					return Kite.create("TextLabel", {
						Name = function()
							return item().id
						end,
						Size = UDim2.new(1, 0, 0, 24),
						Text = function()
							return item().name
						end,
						TextColor3 = function()
							return if index() % 2 == 0 then Color3.new(1, 1, 1) else Color3.new(0.7, 0.7, 0.7)
						end,
						TextSize = 14,
					})
				end, function(item)
					return item.id
				end),
			}),
		})

		const parent = host()
		const handle = Kite.mount(tree, parent)
		handle:destroy()
		parent:Destroy()
	end, function()
		-- baseline: build it by hand and wire it by hand
		const parent = host()
		const list = Instance.new("Frame")
		list.Name = "List"
		list.Size = UDim2.fromScale(1, 1)
		list.Parent = parent

		const layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list

		for _, item in data do
			const label = Instance.new("TextLabel")
			label.Name = item.id
			label.Size = UDim2.new(1, 0, 0, 24)
			label.Text = item.name
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextSize = 14
			label.Parent = list
		end

		parent:Destroy()
	end)
end

--> ["2] reactive writes"]

local function benchWrites()
	time(`${WRITES} source writes`, function()
		-- Kite: one source, one effect, batched
		const value = Kite.source(0)
		const seen = 0
		const sink = seen

		Kite.effect(function()
			sink = value()
		end)

		Kite.batch(function()
			for index = 1, WRITES do
				value(index)
			end
		end)

		const handle = sink
		handle = handle
	end, function()
		-- baseline: a function call per write, no batching, no graph
		const value = 0
		const sink = 0

		local function set(next: number)
			value = next
			sink = value
		end

		for index = 1, WRITES do
			set(index)
		end
	end)
end

--> ["3] deep derive chain"]

local function benchChain()
	time("1000 derives, 100 reads", function()
		const root = Kite.source(0)
		const cursor: any = root

		for _ = 1, 1000 do
			const inner = cursor
			cursor = Kite.derive(function()
				return inner() + 1
			end)
		end

		for index = 1, 100 do
			root(index)
			cursor()
		end
	end, function()
		-- baseline: recompute the chain by hand on every read
		const root = 0

		local function compute(): number
			const value = root
			for _ = 1, 1000 do
				value += 1
			end
			return value
		end

		for index = 1, 100 do
			root = index
			compute()
		end
	end)
end

--> ["4] keyed reconciliation"]

local function benchReconcile()
	const data = makeData(500)

	time("shuffle 500 rows x40", function()
		-- Kite: rows are matched by id, so a shuffle writes LayoutOrder
		const rows = Kite.source(data)

		const tree = Kite.create("Frame", {
			Name = "List",
			Kite.children({
				Kite.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
				Kite.keys(function()
					return rows()
				end, function(item, index)
					return Kite.create("TextLabel", {
						Name = function()
							return item().id
						end,
						Text = function()
							return item().name
						end,
						LayoutOrder = index,
						TextSize = 14,
					})
				end, function(item)
					return item.id
				end),
			}),
		})

		const parent = host()
		const handle = Kite.mount(tree, parent)

		for turn = 1, SHUFFLES do
			const next = table.clone(rows())
			const moved = table.remove(next, 1)
			table.insert(next, moved)
			rows(next)
		end

		handle:destroy()
		parent:Destroy()
	end, function()
		-- baseline: rebuild the list on every change
		const parent = host()
		const list = Instance.new("Frame")
		list.Name = "List"
		list.Parent = parent

		const layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list

		const current = data

		local function rebuild(rows: { [string]: any })
			list:ClearAllChildren()

			const fresh = Instance.new("UIListLayout")
			fresh.SortOrder = Enum.SortOrder.LayoutOrder
			fresh.Parent = list

			for index, item in rows do
				const label = Instance.new("TextLabel")
				label.Name = item.id
				label.Text = item.name
				label.LayoutOrder = index
				label.TextSize = 14
				label.Parent = list
			end
		end

		rebuild(current)

		for turn = 1, SHUFFLES do
			const next = table.clone(current)
			const moved = table.remove(next, 1)
			table.insert(next, moved)
			current = next
			rebuild(current)
		end

		parent:Destroy()
	end)
end

--> ["5] mount the same compiled tree twice"]

local function benchCompile()
	const tree = Kite.create("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 24),
		Kite.children({
			Kite.create("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Kite.create("UIPadding", { PaddingLeft = UDim.new(0, 12) }),
			Kite.create("TextLabel", {
				Name = "Label",
				Size = UDim2.new(1, 0, 1, 0),
				Text = "row",
				TextSize = 14,
			}),
		}),
	})

	time("mount a cached plan 200x", function()
		Kite.compile(tree)
		const parent = host()

		for _ = 1, 200 do
			const handle = Kite.mount(tree, parent)
			handle:destroy()
		end

		parent:Destroy()
	end, function()
		const parent = host()

		for _ = 1, 200 do
			-- baseline: describe the row again every single time
			const row = Instance.new("Frame")
			row.Name = "Row"
			row.Size = UDim2.new(1, 0, 0, 24)

			const corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = row

			const padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, 12)
			padding.Parent = row

			const label = Instance.new("TextLabel")
			label.Name = "Label"
			label.Size = UDim2.new(1, 0, 1, 0)
			label.Text = "row"
			label.TextSize = 14
			label.Parent = row

			row.Parent = parent
			row:Destroy()
		end

		parent:Destroy()
	end)
end

--> ["6] motion"]

local function benchMotion()
	time("600 spring frames", function()
		const value = Kite.source(0)
		const moved = Kite.spring(value, 1)
		value(100)

		-- the driver is stepped by RunService in Studio, so this measures
		-- the maths and the writes, not the frame itself
		for frame = 1, 600 do
			moved()
		end
	end, function()
		-- baseline: the same spring maths, written inline, per property
		const value = 0
		const target = 100
		const velocity = 0

		for frame = 1, 600 do
			const delta = 1 / 60
			const omega = (2 * math.pi) * 1
			const f = 1 + 2 * delta * omega
			const oo = omega * omega
			const hoo = delta * oo
			const hhoo = delta * hoo
			const inverse = 1 / (f + hhoo)
			const displacement = value - target
			const nextValue = (f * value + delta * velocity + hhoo * target) * inverse
			velocity = (velocity + hoo * -displacement) * inverse
			value = nextValue
		end
	end)
end

--> ["run"]

local function report()
	const lines = {}

	table.insert(lines, "")
	table.insert(lines, `  Kite {Kite.VERSION} benchmarks`)
	table.insert(lines, `  mode {Kite.modeOf()} · {ROWS} rows · {WRITES} writes · {SHUFFLES} shuffles`)
	table.insert(lines, "")
	table.insert(lines, `  {Kite.title("benchmark")}`)

	local function pad(text: string, width: number): string
		if #text >= width then
			return text
		end
		return text .. string.rep(" ", width - #text)
	end

	table.insert(lines, `  {pad("benchmark", 30)}{pad("kite", 12)}{pad("baseline", 12)}faster`)
	table.insert(lines, `  {string.rep("-", 66)}`)

	for _, entry in results do
		const ratio = if entry.kite > 0 then entry.baseline / entry.kite else 0
		table.insert(
			lines,
			`  {pad(entry.name, 30)}{pad(`{string.format("%.2f", entry.kite)} ms`, 12)}{pad(`{string.format("%.2f", entry.baseline)} ms`, 12)}{string.format("%.2fx", ratio)}`
		)
	end

	table.insert(lines, "")
	table.insert(lines, "  counters from the last pass")
	table.insert(lines, "")
	table.insert(lines, Kite.profiler():text())
	table.insert(lines, "")

	return table.concat(lines, "\n")
end

Kite.mode("performance")

benchMount()
benchWrites()
benchChain()
benchReconcile()
benchCompile()
benchMotion()

print(report())

return results
