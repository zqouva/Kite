--!strict
--[=[
	--> ["Kite : Example : CommandBar"]

	The command bar, rewritten in Kite.

	The Vide version of this screen was three hundred lines of nested
	create() calls with a spring per property and a hand rolled log. This one
	is the same screen, plus suggestions you can click, plus a history
	drawer, plus a theme you can switch, in about a third of the lines.

	What to notice:

	- `count()`, `count(4)`: one call, both directions
	- `Text = open` : a source binds straight to a property, no wrapper
	- `Kite.spring(function() ... end, 0.28)` : one motion, five properties
	- `Kite.keys(..., function(item) return item.id end)` : rows keep state
	- `Kite.when(loading(), ...)` : a branch that mounts and unmounts
	- `Kite.ref(box)` : the TextBox, whenever you need it
	- `kite.mode `strict`` at the bottom: the linter reads your own tree

	--> ["run it"]
	Drop Kite in ReplicatedStorage.Packages, drop this in
	StarterPlayer.StarterPlayerScripts as a LocalScript, press Quote.
]=]

const Kite = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Kite"))

type Status = "ok" | "error" | "info" | "warn"

type Line = {
	id: number,
	status: Status,
	message: string,
	at: number,
}

--> ["theme"]
-- Every token is a source. Switching the theme moves every property that
-- read one, with nothing else from you.

const theme = Kite.theme({
	mode = "midnight",
	midnight = {
		ink = "#0d181b",
		panel = "#112126",
		panelLight = "#16303a",
		stroke = "#2e5053",
		text = "#eeeeee",
		muted = "#7f9ba1",
		faint = "#4d6a6e",
		error = "#f76b6e",
		info = "#56a6e4",
		warn = "#e8b736",
		ok = "#6fdca0",
		accent = "#3ddad7",
	},
	daylight = {
		ink = "#f4f7f7",
		panel = "#e4ecee",
		panelLight = "#d3e0e3",
		stroke = "#9fb6ba",
		text = "#101d1f",
		muted = "#5b7276",
		faint = "#8ba0a4",
		error = "#c23b3e",
		info = "#1f6ea8",
		warn = "#9a7608",
		ok = "#2c8f63",
		accent = "#0f8f8d",
	},
})

const tint = {
	ok = theme.ok,
	error = theme.error,
	info = theme.info,
	warn = theme.warn,
}

const glyph = {
	ok = "+",
	error = "!",
	warn = "*",
	info = "-",
}

--> ["state"]
-- Six sources hold the whole screen.

const open = Kite.source(false)
const lines = Kite.source({} :: { Line })
const suggestions = Kite.source({} :: { string })
const active = Kite.source(1)
const expanded = Kite.source(false)
const palette = Kite.source("midnight")

const box = Kite.ref()
const serial = Kite.source(0)

--> ["motion"]
-- One spring reads a source, five properties read the spring. The frame
-- driver is one connection no matter how many things move.

const settle = Kite.spring(open, 0.28) -- 1 while open, 0 while closed

const rise = settle:map(function(v: number): number
	return 18 * (1 - v)
end)

const fade = settle:map(function(v: number): number
	return 1 - v
end)

const fill = settle:map(function(v: number): number
	return 1 - 0.94 * v
end)

const glow = settle:map(function(v: number): number
	return 1 - 0.75 * v
end)

const unfold = Kite.spring(function(): number
	return if expanded() then 1 else 0
end, 0.3)

const listed = Kite.spring(function(): number
	return if #suggestions() > 0 then 1 else 0
end, 0.3)

--> ["commands"]
-- A command table, so Tab can complete against something real.

const commands = table.freeze({
	{ name = "stand give", usage = "stand give @Player StarPlatinum" },
	{ name = "stand drop", usage = "stand drop" },
	{ name = "stand store", usage = "stand store @Player" },
	{ name = "spec set", usage = "spec set @Player Bravery" },
	{ name = "spec reset", usage = "spec reset @Player" },
	{ name = "tp", usage = "tp @Player" },
	{ name = "theme", usage = "theme midnight" },
	{ name = "clear", usage = "clear" },
})

--> ["actions"]

local function say(status: Status, message: string)
	serial(serial() + 1)

	const next = table.clone(lines())
	table.insert(next, {
		id = serial(),
		status = status,
		message = message,
		at = os.clock(),
	})

	-- keep the last forty, the log is a log
	while #next > 40 do
		table.remove(next, 1)
	end

	lines(next)
	active(#next)
end

local function submit(text: string)
	if text == "" then
		return
	end

	say("info", text)

	const head = string.split(text, " ")[1]

	if head == "clear" then
		lines({})
		return
	end

	if head == "theme" then
		const wanted = string.split(text, " ")[2]

		if wanted == "daylight" or wanted == "midnight" then
			palette(wanted)
			theme:set(wanted)
			say("ok", `theme is {wanted}`)
		else
			say("error", `unknown theme "{tostring(wanted)}"`)
		end

		return
	end

	const hit = false

	for _, command in commands do
		if string.sub(command.name, 1, #head) == head then
			hit = true
			break
		end
	end

	if hit then
		say("ok", `ran {text}`)
	else
		say("error", `no command called "{head}"`)
	end
end

local function complete()
	const list = suggestions()

	if #list == 0 then
		return
	end

	box():CaptureFocus()
	box().Text = list[active()] .. " "
	box().CursorPosition = #box().Text + 1
	suggestions({})
end

local function refresh(text: string)
	if text == "" then
		suggestions({})
		return
	end

	const out = {}

	for _, command in commands do
		if string.find(command.name, text, 1, true) == 1 then
			table.insert(out, command.name)
		end
	end

	suggestions(out)
	active(1)
end

local function move(step: number)
	const total = #suggestions()

	if total == 0 then
		return
	end

	active(((active() - 1 + step) % total) + 1)
end

--> ["pieces"]
-- Components keep the tree readable. Each one is a function and a contract.

const Row = Kite.component("Row", function(props)
	return Kite.create("Frame", {
		Name = "Line",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),

		Kite.create("TextLabel", {
			Name = "Glyph",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(14, 22),
			Text = Kite.use(props, "glyph", "-"),
			TextColor3 = Kite.use(props, "tint", theme.muted),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Kite.create("Frame", {
			Name = "Marker",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Kite.use(props, "tint", theme.muted),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(2, 16),
			Kite.children({ Kite.create("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		}),

		Kite.create("TextLabel", {
			Name = "Message",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular),
			Position = UDim2.new(0, 28, 0.5, 0),
			Size = UDim2.new(1, -28, 1, 0),
			Text = Kite.use(props, "message", ""),
			TextColor3 = Kite.use(props, "tint", theme.muted),
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end, {
	message = { type = "string" },
	glyph = { type = "string" },
	tint = { type = "Color3" },
})

const SuggestionRow = Kite.component("SuggestionRow", function(props)
	const picked = Kite.derive(function(): boolean
		return active() == Kite.value(props, "index", 0)
	end)

	return Kite.create("TextButton", {
		Name = "Suggestion",
		AutoButtonColor = false,
		BackgroundColor3 = theme.accent,
		BackgroundTransparency = Kite.spring(function(): number
			return if picked() then 0.82 else 1
		end, 0.12),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",

		Activated = function()
			complete()
		end,

		Kite.children({
			Kite.create("UICorner", { CornerRadius = UDim.new(0, 6) }),

			Kite.create("TextLabel", {
				Name = "Label",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Medium),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.new(1, -24, 1, 0),
				Text = Kite.use(props, "label", ""),
				TextColor3 = function()
					return if picked() then theme.accent() else theme.text()
				end,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
	})
end, {
	label = { type = "string" },
	index = { type = "number", required = true },
})

--> ["tree"]
-- One table. Statics are static, functions bind, array entries are children.

const CommandBar = Kite.create("ScreenGui", {
	Name = "CommandBar",
	DisplayOrder = 1000,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,

	Kite.create("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(640, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = open,

		Kite.children({
			Kite.create("UIPadding", {
				PaddingBottom = function()
					return UDim.new(0, rise())
				end,
			}),

			Kite.create("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			--> ["live toast log"]
			Kite.create("Frame", {
				Name = "Log",
				LayoutOrder = 1,
				BackgroundColor3 = theme.ink,
				BackgroundTransparency = function()
					return if #lines() > 0 then 0.15 * settle:get() else 1
				end,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,

				Kite.children({
					Kite.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Kite.create("UIStroke", {
						Color = theme.stroke,
						Thickness = 1,
						Transparency = 0.45,
					}),
					Kite.create("UIPadding", {
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
					}),
					Kite.create("UIListLayout", {
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Bottom,
						Padding = UDim.new(0, 2),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					Kite.indexes(function()
						return lines()
					end, function(entry)
						return Row({
							message = function()
								return entry().message
							end,
							glyph = function()
								return glyph[entry().status] or "-"
							end,
							tint = function()
								return tint[entry().status]() or theme.muted()
							end,
						})
					end),
				}),
			}),

			--> ["autocomplete"]
			Kite.create("Frame", {
				Name = "Suggestions",
				LayoutOrder = 2,
				BackgroundColor3 = theme.panel,
				BackgroundTransparency = function()
					return 1 - 0.95 * listed:get()
				end,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = function()
					return #suggestions() > 0
				end,
				ClipsDescendants = true,

				Kite.children({
					Kite.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Kite.create("UIStroke", {
						Color = theme.accent,
						Thickness = 1,
						Transparency = 0.6,
					}),
					Kite.create("UIPadding", {
						PaddingTop = UDim.new(0, 6),
						PaddingBottom = UDim.new(0, 6),
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
					}),
					Kite.create("UIListLayout", {
						Padding = UDim.new(0, 2),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					Kite.keys(function()
						return suggestions()
					end, function(item, index)
						return SuggestionRow({
							label = item,
							index = index,
						})
					end, function(item)
						return item
					end),
				}),
			}),

			--> ["field"]
			Kite.create("Frame", {
				Name = "Field",
				LayoutOrder = 3,
				BackgroundColor3 = theme.panel,
				BackgroundTransparency = fill,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(640, 46),

				Kite.children({
					Kite.create("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Kite.create("UIStroke", {
						Color = function()
							return if open() then theme.accent() else theme.stroke()
						end,
						Thickness = 1,
						Transparency = glow,
					}),
					Kite.create("UIGradient", {
						Color = function()
							return ColorSequence.new({
								ColorSequenceKeypoint.new(0, theme.panelLight()),
								ColorSequenceKeypoint.new(1, theme.panel()),
							})
						end,
						Rotation = 90,
					}),

					Kite.create("TextLabel", {
						Name = "Caret",
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
						Position = UDim2.new(0, 16, 0.5, 0),
						Size = UDim2.fromOffset(14, 46),
						Text = ">",
						TextColor3 = theme.accent,
						TextSize = 20,
						TextTransparency = fade,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					Kite.create("TextBox", {
						Name = "Input",
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						ClearTextOnFocus = false,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Medium),
						Position = UDim2.new(0, 34, 0.5, 0),
						Size = UDim2.new(1, -76, 1, 0),
						Text = "",
						PlaceholderText = "stand give @Player StarPlatinum",
						PlaceholderColor3 = theme.muted,
						TextColor3 = theme.text,
						TextSize = 17,
						TextTransparency = fade,
						TextXAlignment = Enum.TextXAlignment.Left,

						Kite.ref(box),

						FocusLost = function(enterPressed: boolean)
							if enterPressed then
								submit(box().Text)
								box().Text = ""
								suggestions({})
							end
						end,
					}),

					Kite.create("TextButton", {
						Name = "HistoryToggle",
						AnchorPoint = Vector2.new(1, 0.5),
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(28, 46),
						Text = "",

						Activated = function()
							expanded(not expanded())
						end,

						Kite.children({
							Kite.create("TextLabel", {
								Name = "Chevron",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
								Position = UDim2.new(0.5, 0, 0.5, 0),
								Size = UDim2.fromOffset(20, 20),
								Text = function()
									return if expanded() then "▲" else "▼"
								end,
								TextColor3 = function()
									return if #lines() > 0 then theme.accent() else theme.faint()
								end,
								TextSize = 13,
								TextTransparency = fade,
							}),
						}),
					}),
				}),
			}),

			--> ["history drawer"]
			Kite.create("Frame", {
				Name = "History",
				LayoutOrder = 4,
				BackgroundColor3 = theme.ink,
				BackgroundTransparency = function()
					return 1 - 0.9 * unfold:get()
				end,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = expanded,
				ClipsDescendants = true,

				Kite.children({
					Kite.create("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Kite.create("UIStroke", {
						Color = theme.stroke,
						Thickness = 1,
						Transparency = 0.4,
					}),
					Kite.create("UIPadding", {
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
					}),
					Kite.create("UIListLayout", {
						Padding = UDim.new(0, 2),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					Kite.keys(function()
						return lines()
					end, function(entry)
						return Row({
							message = function()
								return entry().message
							end,
							glyph = function()
								return glyph[entry().status] or "-"
							end,
							tint = function()
								return tint[entry().status]() or theme.muted()
							end,
						})
					end, function(entry)
						return entry().id
					end),

					Kite.when(function()
						return #lines() == 0
					end, Kite.create("TextLabel", {
						Name = "Empty",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular),
						Size = UDim2.new(1, 0, 0, 22),
						Text = "No output yet.",
						TextColor3 = theme.faint,
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Left,
					})),
				}),
			}),

			--> ["guide"]
			Kite.create("TextLabel", {
				Name = "Guide",
				LayoutOrder = 5,
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular),
				Size = UDim2.new(1, 0, 0, 18),
				Text = "Tab to autocomplete · ↑↓ to browse · Enter to run · Esc to close",
				TextColor3 = theme.faint,
				TextSize = 12,
				TextTransparency = fade,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
	}),
})

--> ["input"]
-- Keys are wired once, outside the tree.

const UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Quote then
		open(not open())

		if open() then
			box():CaptureFocus()
		else
			box():ReleaseFocus()
			suggestions({})
		end

		return
	end

	if not open() then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		open(false)
		box():ReleaseFocus()
		suggestions({})
		return
	end

	if input.KeyCode == Enum.KeyCode.Tab then
		complete()
		return
	end

	if input.KeyCode == Enum.KeyCode.Up then
		move(-1)
		return
	end

	if input.KeyCode == Enum.KeyCode.Down then
		move(1)
	end
end)

--> ["typing"]
-- Refs hand you the instance the moment it exists, so the connection is
-- made once and owned by nothing in particular.

task.spawn(function()
	const input = box:wait() :: TextBox

	input:GetPropertyChangedSignal("Text"):Connect(function()
		refresh(input.Text)
	end)
end)

--> ["build"]

Kite.mode("creative")

const handle = Kite.mount(CommandBar)

--> ["guidance"]
-- The linter reads your own tree, in your own mode, and answers like a
-- person. Uncomment it and read the output.

-- print(Kite.strict(CommandBar):text())
-- print(Kite.performance(CommandBar):text())
-- Kite.help(`keys`)

say("ok", "Kite command bar online")
say("info", "press Quote to open it")

return handle
