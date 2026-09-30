--!strict
--[=[
	--> ["Kite : Example : Counter"]

	The whole model in twenty lines. If you read one example, read this one.

		A source holds a value
		A derive is a value that follows other values
		An effect is work that happens when what it read moves

	Everything else in Kite is those three with better manners.
]=]

const Kite = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Kite"))

Kite.mode("creative")

return Kite.go(function()
	const count = Kite.source(0)
	const doubled = count:map(function(value: number): number
		return value * 2
	end)

	const label = Kite.derive(function(): string
		return if count() == 0 then "nothing yet" else `{count()}`
	end)

	count:watch(function(value: number)
		if value == 10 then
			print("ten")
		end
	end)

	-- one spring, one property. it shares the frame driver with every
	-- other motion in the game, so a hundred counters cost one connection
	const pop = Kite.spring(count, 0.4)

	return Kite.create("ScreenGui", {
		Name = "Counter",
		ResetOnSpawn = false,

		Kite.create("Frame", {
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(320, 180),
			BackgroundColor3 = "#112126",

			corner = 14,
			padding = 20,
			list = "vertical",
			stroke = { "#2e5053", 1 },

			Kite.create("TextLabel", {
				Name = "Value",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 60),
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Text = label,
				TextColor3 = "#eeeeee",
				TextSize = 44,
				TextTransparency = pop:map(function(v: number): number
					return 1 - Kite.clamp(v, 0, 1) * 0.2
				end),
			}),

			Kite.create("TextLabel", {
				Name = "Doubled",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular),
				Text = doubled,
				TextColor3 = "#7f9ba1",
				TextSize = 16,
			}),

			Kite.create("TextButton", {
				Name = "Add",
				AutoButtonColor = false,
				BackgroundColor3 = "#3ddad7",
				Size = UDim2.new(1, 0, 0, 44),
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				Text = "add one",
				TextColor3 = "#0d181b",
				TextSize = 18,
				corner = 10,

				Activated = function()
					count(count() + 1)
				end,
			}),
		}),
	})
end)
