--!strict
--[=[
	--> ["Kite : Example : Boot"]

	How Kite is meant to be worked with, start to finish:

		1. build in creative mode, where sugar is allowed
		2. lint the tree before it ships, in strict mode
		3. profile it in performance mode
		4. ask for help without leaving the editor

	Run this once and read the output. It is the whole workflow.
]=]

const Kite = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Kite"))

--> ["a small tree"]

const open = Kite.source(false)
const rows = Kite.source({ "alpha", "beta", "gamma" })

const Panel = Kite.create("ScreenGui", {
	Name = "Panel",
	ResetOnSpawn = false,

	Kite.children({
		Kite.create("Frame", {
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(360, 260),
			BackgroundColor3 = "#112126",
			corner = 14,
			padding = 16,
			list = "vertical",
			stroke = { "#2e5053", 1 },

			Kite.children({
				Kite.create("TextLabel", {
					Name = "Heading",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 28),
					Text = "kite",
					TextColor3 = "#3ddad7",
					TextSize = 22,
				}),

				Kite.indexes(function()
					return rows()
				end, function(row)
					return Kite.create("TextLabel", {
						Name = function()
							return row()
						end,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 24),
						Text = row,
						TextColor3 = "#eeeeee",
						TextSize = 15,
					})
				end),

				Kite.when(open, Kite.create("TextLabel", {
					Name = "Open",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 24),
					Text = "it is open",
					TextColor3 = "#6fdca0",
					TextSize = 15,
				})),
			}),
		}),
	}),
})

--> ["1] build in creative"]

Kite.mode("creative")
print("mode:", Kite.modeOf())

--> ["2] lint it in strict before it ships"]

const strict = Kite.strict(Panel)
print(strict:text())

if not strict:isOk() then
	warn("strict mode found something, see the report above")
end

--> ["3] read the cost of it in performance mode"]

const cost = Kite.performance(Panel)
print(cost:text())

--> ["4] profile it"]

Kite.profile(true)

const measured = Kite.measure("mount the panel", function()
	return Kite.go(function()
		return Panel
	end)
end)

print(`mount took {measured.milliseconds} ms`)

rows({ "alpha", "beta", "gamma", "delta" })
open(true)

print(Kite.profiler():text())

--> ["5] ask for help without leaving the editor"]

print(Kite.topic())
print(Kite.topic("keys"))

return measured.value
