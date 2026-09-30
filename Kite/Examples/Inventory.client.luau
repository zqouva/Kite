--!strict
--[=[
	--> ["Kite : Example : Inventory"]

	Everything a real screen needs, and none of the ceremony:

	- `Kite.keys` with an identity function, so rows keep their own state
	- a component with a contract, so a typo names itself
	- a theme with two palettes, switched by a source
	- `Kite.when` for the empty state
	- one linter pass over the whole tree before it mounts

	--> ["the interesting part"]
	Drag the list around: every row keeps its own `held` counter, because
	Kite matches rows by id instead of by position. That is what `keys` buys
	you, and it costs one function.
]=]

const Kite = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Kite"))

type Item = {
	id: string,
	name: string,
	rarity: "common" | "rare" | "mythic",
	weight: number,
}

--> ["theme"]

const theme = Kite.theme({
	mode = "dark",
	dark = {
		ink = "#0d181b",
		panel = "#112126",
		panelLight = "#16303a",
		stroke = "#2e5053",
		text = "#eeeeee",
		muted = "#7f9ba1",
		faint = "#4d6a6e",
		accent = "#3ddad7",
		common = "#7f9ba1",
		rare = "#56a6e4",
		mythic = "#e8b736",
	},
	light = {
		ink = "#f4f7f7",
		panel = "#e4ecee",
		panelLight = "#d3e0e3",
		stroke = "#9fb6ba",
		text = "#101d1f",
		muted = "#5b7276",
		faint = "#8ba0a4",
		accent = "#0f8f8d",
		common = "#5b7276",
		rare = "#1f6ea8",
		mythic = "#9a7608",
	},
})

--> ["state"]

const items = Kite.source({
	{ id = "a", name = "Star Platinum", rarity = "mythic", weight = 12 },
	{ id = "b", name = "Crazy Diamond", rarity = "rare", weight = 8 },
	{ id = "c", name = "Hermit Purple", rarity = "common", weight = 3 },
	{ id = "d", name = "The World", rarity = "mythic", weight = 15 },
} :: { Item })

const filter = Kite.source("all")
const query = Kite.source("")
const selected = Kite.source(nil :: string?)

const shown = Kite.derive(function(): { Item }
	const wanted = string.lower(query())
	const kind = filter()

	const out = {}

	for _, item in items() do
		if kind ~= "all" and item.rarity ~= kind then
			continue
		end

		if wanted ~= "" and not string.find(string.lower(item.name), wanted, 1, true) then
			continue
		end

		table.insert(out, item)
	end

	return out
end)

const total = Kite.derive(function(): number
	const sum = 0
	for _, item in shown() do
		sum += item.weight
	end
	return sum
end)

--> ["component"]
-- A contract means a typo is an error that names itself:
--   Slot { lable = `x` }  ->  Slot does not take a prop called `lable`.

const Slot = Kite.component("Slot", function(props)
	return Kite.create("TextButton", {
		Name = "Slot",
		AutoButtonColor = false,
		BackgroundColor3 = theme.panel,
		Size = UDim2.new(1, 0, 0, 56),
		Text = "",
		corner = 10,
		padding = { 10, 14 },

		Kite.children({
			Kite.create("UIStroke", {
				Color = function()
					return if selected() == Kite.value(props, "id") then theme.accent() else theme.stroke()
				end,
				Thickness = function()
					return if selected() == Kite.value(props, "id") then 2 else 1
				end,
				Transparency = function()
					return if selected() == Kite.value(props, "id") then 0.1 else 0.6
				end,
			}),

			Kite.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Kite.create("Frame", {
				Name = "Swatch",
				LayoutOrder = 1,
				BackgroundColor3 = theme[Kite.value(props, "rarity", "common")],
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(6, 34),
				corner = 3,
			}),

			Kite.create("TextLabel", {
				Name = "Name",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Medium),
				Size = UDim2.new(1, -90, 0, 22),
				Text = Kite.use(props, "name", "unknown"),
				TextColor3 = theme.text,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Kite.create("TextLabel", {
				Name = "Weight",
				LayoutOrder = 3,
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular),
				Size = UDim2.fromOffset(48, 22),
				Text = Kite.use(props, "weight", 0),
				TextColor3 = theme.muted,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),

		Activated = function()
			const id = Kite.value(props, "id")
			selected(if selected() == id then nil else id)
		end,
	})
end, {
	id = { type = "string", required = true },
	name = { type = "string" },
	rarity = { type = "string", default = "common" },
	weight = { type = "number", default = 0 },
})

--> ["tree"]

const Inventory = Kite.create("ScreenGui", {
	Name = "Inventory",
	ResetOnSpawn = false,

	Kite.children({
		Kite.create("Frame", {
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = theme.ink,
			BackgroundTransparency = 0.15,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(520, 560),
			corner = 16,
			padding = 18,
			list = "vertical",
			stroke = { "#2e5053", 1, 0.45 },

			Kite.children({
				Kite.create("TextLabel", {
					Name = "Title",
					LayoutOrder = 1,
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
					Size = UDim2.new(1, 0, 0, 28),
					Text = function()
						return `inventory · {#shown()} · {total()} kg`
					end,
					TextColor3 = theme.text,
					TextSize = 20,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Kite.create("TextBox", {
					Name = "Search",
					LayoutOrder = 2,
					BackgroundColor3 = theme.panel,
					ClearTextOnFocus = false,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular),
					PlaceholderText = "search",
					PlaceholderColor3 = theme.muted,
					Size = UDim2.new(1, 0, 0, 38),
					Text = "",
					TextColor3 = theme.text,
					TextSize = 15,
					corner = 8,
					padding = { 0, 12 },

					Kite.live(function(instance: TextBox)
						const connection = instance:GetPropertyChangedSignal("Text"):Connect(function()
							query(instance.Text)
						end)

						return function()
							connection:Disconnect()
						end
					end),
				}),

				Kite.create("Frame", {
					Name = "Filters",
					LayoutOrder = 3,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 34),

					Kite.children({
						Kite.create("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 8),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						Kite.indexes(function()
							return { "all", "common", "rare", "mythic" }
						end, function(kind)
							return Kite.create("TextButton", {
								Name = function()
									return kind()
								end,
								AutoButtonColor = false,
								BackgroundColor3 = function()
									return if filter() == kind() then theme.accent() else theme.panel()
								end,
								BackgroundTransparency = function()
									return if filter() == kind() then 0.15 else 0.6
								end,
								Size = UDim2.new(0, 88, 0, 30),
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Medium),
								Text = function()
									return Kite.title(kind())
								end,
								TextColor3 = function()
									return if filter() == kind() then theme.ink() else theme.muted()
								end,
								TextSize = 14,
								corner = 8,

								Activated = function()
									filter(kind())
								end,
							})
						end),
					}),
				}),

				Kite.create("ScrollingFrame", {
					Name = "List",
					LayoutOrder = 4,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(0, 0, 0, 0),
					ScrollBarImageColor3 = theme.stroke,
					ScrollBarThickness = 6,
					Size = UDim2.new(1, 0, 1, -140),

					Kite.children({
						Kite.create("UIListLayout", {
							Padding = UDim.new(0, 8),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						Kite.keys(function()
							return shown()
						end, function(item)
							return Slot({
								id = function()
									return item().id
								end,
								name = function()
									return item().name
								end,
								rarity = function()
									return item().rarity
								end,
								weight = function()
									return `{item().weight} kg`
								end,
							})
						end, function(item: Item): string
							return item.id
						end),

						Kite.when(function()
							return #shown() == 0
						end, Kite.create("TextLabel", {
							Name = "Empty",
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular),
							Size = UDim2.new(1, 0, 0, 40),
							Text = "nothing matches that",
							TextColor3 = theme.faint,
							TextSize = 15,
						})),
					}),
				}),

				Kite.create("TextButton", {
					Name = "Shuffle",
					LayoutOrder = 5,
					AutoButtonColor = false,
					BackgroundColor3 = theme.panel,
					Size = UDim2.new(1, 0, 0, 44),
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
					Text = "shuffle (watch the rows keep their state)",
					TextColor3 = theme.text,
					TextSize = 15,
					corner = 10,

					Activated = function()
						const next = table.clone(items())
						const last = table.remove(next, 1)
						table.insert(next, last)
						items(next)
					end,
				}),

				Kite.create("TextButton", {
					Name = "Theme",
					LayoutOrder = 6,
					AutoButtonColor = false,
					BackgroundColor3 = theme.panelLight,
					Size = UDim2.new(1, 0, 0, 40),
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Medium),
					Text = "switch palette",
					TextColor3 = theme.muted,
					TextSize = 14,
					corner = 10,

					Activated = function()
						theme:toggle()
					end,
				}),
			}),
		}),
	}),
})

--> ["guidance"]
-- Read your own tree before it mounts. Three modes, three voices.

Kite.mode("creative")

const report = Kite.creative(Inventory)
print(report:text())

if not report:isOk() then
	warn("the inventory tree has problems, see above")
end

--> ["mount"]

return Kite.mount(Inventory)
