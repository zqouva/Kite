--!strict
--[=[
	--> ["Kite : Tests : Mount"]

	Trees become instances, bindings track, lists recycle, and destroying a
	handle leaves nothing behind.
]=]

local G = require("./Globals")

local Instance = G.Instance
local UDim2 = G.UDim2
local Enum = G.Enum

return function(H: any, Kite: any, Stub: any)
	local function root()
		return Instance.new("Folder")
	end

	--> ["elements"]

	H.group("create", function()
		H.test("builds an instance with its properties", function()
			local handle = Kite.mount(Kite.create("Frame", {
				Name = "Card",
				Size = UDim2.fromOffset(220, 120),
				BackgroundTransparency = 0.5,
			}), root())

			H.eq(handle.instance.ClassName, "Frame", "class")
			H.eq(handle.instance.Name, "Card", "name")
			H.eq(handle.instance.Size.X.Offset, 220, "size")
			H.eq(handle.instance.BackgroundTransparency, 0.5, "transparency")
			handle:destroy()
		end)

		H.test("children mount in order and parent last", function()
			local handle = Kite.mount(Kite.create("Frame", {
				Name = "Parent",
				Kite.create("UICorner", { Name = "First" }),
				Kite.create("UIStroke", { Name = "Second" }),
				Kite.children({
					Kite.create("UIPadding", { Name = "Third" }),
				}),
			}), root())

			local children = handle.instance:GetChildren()
			H.eq(#children, 3, "three children")
			H.eq(children[1].Name, "First", "first")
			H.eq(children[2].Name, "Second", "second")
			H.eq(children[3].Name, "Third", "third")
			handle:destroy()
		end)

		H.test("a handle destroys everything it made", function()
			local parent = root()
			local handle = Kite.mount(Kite.create("Frame", {
				Kite.create("Frame", {
					Kite.create("TextLabel", { Name = "Deep" }),
				}),
			}), parent)

			H.eq(#parent:GetChildren(), 1, "mounted")
			handle:destroy()
			H.eq(#parent:GetChildren(), 0, "gone")
			H.falsy(handle.alive, "handle knows it is dead")
		end)

		H.test("attributes and tags land on the instance", function()
			local handle = Kite.mount(Kite.create("Frame", {
				Kite.attr({ Rank = 3, Title = "witness" }),
				Kite.tags({ "Kite", "Hud" }),
			}), root())

			H.eq(handle.instance:GetAttribute("Rank"), 3, "attribute")
			H.eq(handle.instance:GetAttribute("Title"), "witness", "attribute two")
			H.truthy(Stub.CollectionService:HasTag(handle.instance, "Kite"), "tagged")
			handle:destroy()
		end)

		H.test("a ref gives you the instance", function()
			local box = Kite.ref()
			local handle = Kite.mount(Kite.create("TextBox", {
				Name = "Input",
				Kite.ref(box),
			}), root())

			H.eq(box().Name, "Input", "ref points at the instance")
			handle:destroy()
		end)

		H.test("kite.instance drops a real instance into the tree", function()
			local made = Instance.new("Frame")
			made.Name = "FromStudio"

			local handle = Kite.mount(Kite.create("Frame", {
				Kite.instance(made),
			}), root())

			H.eq(handle.instance:FindFirstChild("FromStudio") ~= nil, true, "it is a child now")
			handle:destroy()
		end)
	end)

	--> ["bindings"]

	H.group("bindings", function()
		H.test("a function binding follows its sources", function()
			local count = Kite.source(1)
			local handle = Kite.mount(Kite.create("TextLabel", {
				Text = function()
					return `count is {count()}`
				end,
			}), root())

			H.eq(handle.instance.Text, "count is 1", "first paint")
			count(2)
			H.eq(handle.instance.Text, "count is 2", "followed the source")
			handle:destroy()
		end)

		H.test("a source binds straight to a property", function()
			local label = Kite.source("idle")
			local handle = Kite.mount(Kite.create("TextLabel", {
				Text = label,
			}), root())

			H.eq(handle.instance.Text, "idle", "bound")
			label("busy")
			H.eq(handle.instance.Text, "busy", "updated")
			handle:destroy()
		end)

		H.test("a derive binds the same way", function()
			local hp = Kite.source(100)
			local handle = Kite.mount(Kite.create("TextLabel", {
				Text = hp:map(function(value)
					return tostring(value)
				end),
			}), root())

			H.eq(handle.instance.Text, "100", "bound")
			hp(1)
			H.eq(handle.instance.Text, "1", "updated")
			handle:destroy()
		end)

		H.test("bindings stop when the handle dies", function()
			local count = Kite.source(1)
			local handle = Kite.mount(Kite.create("TextLabel", {
				Text = count,
			}), root())

			handle:destroy()
			count(50)
			H.eq(tostring(handle.instance.Text), "1", "nothing moved after death")
		end)

		H.test("an event fires, and disconnects on destroy", function()
			local clicked = 0
			local handle = Kite.mount(Kite.create("TextButton", {
				Activated = function()
					clicked += 1
				end,
			}), root())

			handle.instance.Activated:Fire(handle.instance)
			H.eq(clicked, 1, "fired")

			handle:destroy()

			local before = Stub.connections
			handle.instance.Activated:Fire(handle.instance)
			H.eq(clicked, 1, "no longer connected")
			H.eq(Stub.connections, before, "nothing new connected")
		end)

		H.test("kite.on names events explicitly", function()
			local seen = {}
			local handle = Kite.mount(Kite.create("TextButton", {
				Kite.on({
					MouseButton1Down = function()
						table.insert(seen, "down")
					end,
					MouseButton1Up = function()
						table.insert(seen, "up")
					end,
				}),
			}), root())

			handle.instance.MouseButton1Down:Fire()
			handle.instance.MouseButton1Up:Fire()
			H.eq(table.concat(seen, ","), "down,up", "both connected")
			handle:destroy()
		end)
	end)

	--> ["lists"]

	H.group("keys", function()
		H.test("rows are created, reused, and destroyed by identity", function()
			local rows = Kite.source({ { id = "a", name = "first" }, { id = "b", name = "second" } })
			local before = Kite.stats().keys

			local handle = Kite.mount(Kite.create("Frame", {
				Name = "List",
				Kite.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
				Kite.keys(function()
					return rows()
				end, function(item)
					return Kite.create("TextLabel", {
						Name = function()
							return item().id
						end,
						Text = function()
							return item().name
						end,
					})
				end, function(item)
					return item.id
				end),
			}), root())

			local made = Kite.stats().keys.created - before.created
			H.eq(made, 2, "two rows built")

			-- reorder: no row should be rebuilt
			local reusedBefore = Kite.stats().keys.reused
			rows({ { id = "b", name = "second" }, { id = "a", name = "first" } })
			H.eq(Kite.stats().keys.created, before.created + 2, "nothing rebuilt on reorder")
			H.eq(Kite.stats().keys.reused - reusedBefore, 2, "both rows reused")

			local list = handle.instance
			local a = list:FindFirstChild("a")
			local b = list:FindFirstChild("b")
			H.truthy(a and b, "rows exist")
			H.eq(a.LayoutOrder, 2, "a moved to the second slot")
			H.eq(b.LayoutOrder, 1, "b moved to the first slot")

			-- remove one
			rows({ { id = "b", name = "second" } })
			H.eq(Kite.stats().keys.destroyed, before.destroyed + 1, "one row destroyed")
			H.falsy(list:FindFirstChild("a"), "a is gone")

			handle:destroy()
		end)

		H.test("a row keeps its own state when the list moves", function()
			local rows = Kite.source({ { id = "a" }, { id = "b" } })

			local handle = Kite.mount(Kite.create("Frame", {
				Kite.keys(function()
					return rows()
				end, function(item)
					-- each row owns a source that only it can see
					local localCount = Kite.source(0)
					return Kite.create("TextButton", {
						Name = function()
							return item().id
						end,
						Text = function()
							return tostring(localCount())
						end,
						Activated = function()
							localCount(localCount() + 1)
						end,
					})
				end, function(item)
					return item.id
				end),
			}), root())

			local a = handle.instance:FindFirstChild("a")
			a.Activated:Fire()
			a.Activated:Fire()
			H.eq(a.Text, "2", "row a counted twice")

			rows({ { id = "b" }, { id = "a" } })
			H.eq(handle.instance:FindFirstChild("a").Text, "2", "row a kept its count after moving")

			handle:destroy()
		end)

		H.test("indexes reuse by position instead of identity", function()
			local lines = Kite.source({ "one", "two" })

			local handle = Kite.mount(Kite.create("Frame", {
				Kite.indexes(function()
					return lines()
				end, function(line)
					return Kite.create("TextLabel", {
						Name = function()
							return tostring(line())
						end,
						Text = function()
							return line()
						end,
					})
				end),
			}), root())

			H.eq(handle.instance:FindFirstChild("one") ~= nil, true, "first row")
			lines({ "uno", "dos" })

			H.eq(handle.instance:FindFirstChild("uno") ~= nil, true, "name followed the value")
			H.falsy(handle.instance:FindFirstChild("one"), "old name is gone")

			handle:destroy()
		end)

		H.test("when mounts and unmounts one branch", function()
			local loading = Kite.source(true)

			local handle = Kite.mount(Kite.create("Frame", {
				Kite.when(function()
					return loading()
				end, Kite.create("TextLabel", { Name = "Loading" }), Kite.create("TextLabel", { Name = "Ready" })),
			}), root())

			H.truthy(handle.instance:FindFirstChild("Loading"), "loading branch up")
			H.falsy(handle.instance:FindFirstChild("Ready"), "other branch down")

			loading(false)
			H.falsy(handle.instance:FindFirstChild("Loading"), "loading branch gone")
			H.truthy(handle.instance:FindFirstChild("Ready"), "ready branch up")

			handle:destroy()
		end)

		H.test("switch picks a branch by value", function()
			local state = Kite.source("idle")

			local handle = Kite.mount(Kite.create("Frame", {
				Kite.switch(function()
					return state()
				end, {
					idle = Kite.create("TextLabel", { Name = "Idle" }),
					busy = Kite.create("TextLabel", { Name = "Busy" }),
				}, Kite.create("TextLabel", { Name = "Unknown" })),
			}), root())

			H.truthy(handle.instance:FindFirstChild("Idle"), "idle first")
			state("busy")
			H.truthy(handle.instance:FindFirstChild("Busy"), "busy after the switch")
			H.falsy(handle.instance:FindFirstChild("Idle"), "idle gone")

			state("?")
			H.truthy(handle.instance:FindFirstChild("Unknown"), "fallback")

			handle:destroy()
		end)

		H.test("a dynamic block re-renders when what it read changes", function()
			local mode = Kite.source("list")

			local handle = Kite.mount(Kite.create("Frame", {
				function()
					if mode() == "list" then
						return Kite.create("TextLabel", { Name = "List" })
					end
					return Kite.create("TextLabel", { Name = "Grid" })
				end,
			}), root())

			H.truthy(handle.instance:FindFirstChild("List"), "list block")
			mode("grid")
			H.truthy(handle.instance:FindFirstChild("Grid"), "grid block")
			H.falsy(handle.instance:FindFirstChild("List"), "list block gone")

			handle:destroy()
		end)
	end)

	--> ["sugar and modes"]

	H.group("sugar", function()
		H.test("creative mode expands shorthands into children", function()
			Kite.mode("creative")

			local handle = Kite.mount(Kite.create("Frame", {
				Name = "Card",
				padding = 12,
				corner = 10,
				list = "vertical",
				scale = 1.2,
				aspect = 1.6,
				color = "#112126",
			}), root())

			local frame = handle.instance
			H.truthy(frame:FindFirstChild("UIPadding"), "padding child")
			H.truthy(frame:FindFirstChild("UICorner"), "corner child")
			H.truthy(frame:FindFirstChild("UIListLayout"), "list child")
			H.truthy(frame:FindFirstChild("UIScale"), "scale child")
			H.truthy(frame:FindFirstChild("UIAspectRatioConstraint"), "aspect child")
			H.near(frame.BackgroundColor3.R, 17 / 255, 0.01, "hex colour coerced")
			H.eq(frame:FindFirstChild("UICorner").CornerRadius.Offset, 10, "corner radius")
			H.eq(frame:FindFirstChild("UIPadding").PaddingTop.Offset, 12, "padding top")

			handle:destroy()
		end)

		H.test("size, position, and anchor shorthands coerce", function()
			Kite.mode("creative")

			local handle = Kite.mount(Kite.create("Frame", {
				size = { 220, 120 },
				position = { 0.5, 0, 0.5, 0 },
				anchor = "center",
				rotate = 90,
				zindex = 4,
				clip = true,
			}), root())

			H.eq(handle.instance.Size.X.Offset, 220, "size x")
			H.eq(handle.instance.Size.Y.Offset, 120, "size y")
			H.eq(handle.instance.Position.X.Scale, 0.5, "position scale")
			H.eq(handle.instance.AnchorPoint.X, 0.5, "anchor x")
			H.eq(handle.instance.AnchorPoint.Y, 0.5, "anchor y")
			H.eq(handle.instance.Rotation, 90, "rotation")
			H.eq(handle.instance.ZIndex, 4, "z index")
			H.eq(handle.instance.ClipsDescendants, true, "clips")

			handle:destroy()
		end)

		H.test("strict mode refuses sugar and says so", function()
			Kite.mode("strict")

			local report = Kite.strict(Kite.create("Frame", {
				padding = 12,
			}))

			H.falsy(report:isOk(), "strict is not happy")
			H.contains(report:text(), "sugar", "it names the reason")

			Kite.mode("creative")
		end)

		H.test("strict mode prints the plan cache, so lint cannot poison a mount", function()
			Kite.mode("strict")
			local tree = Kite.create("Frame", { padding = 8 })
			Kite.strict(tree)

			Kite.mode("creative")
			local handle = Kite.mount(tree, root())
			H.truthy(handle.instance:FindFirstChild("UIPadding"), "the mount still expands sugar")

			handle:destroy()
		end)
	end)

	--> ["compile"]

	H.group("compile", function()
		H.test("the same table compiles once and mounts many times", function()
			Kite.mode("creative")
			Kite.forget()

			local tree = Kite.create("Frame", { Name = "Row", corner = 6 })
			local before = Kite.stats().compile

			Kite.compile(tree)
			local afterCompile = Kite.stats().compile.compiled

			local first = Kite.mount(tree, root())
			local second = Kite.mount(tree, root())

			H.eq(Kite.stats().compile.compiled, afterCompile, "no second compile")
			H.truthy(Kite.stats().compile.cacheHits - before.cacheHits >= 1, "the mounts were cache hits")
			H.truthy(first.instance:FindFirstChild("UICorner"), "first mount got the sugar")
			H.truthy(second.instance:FindFirstChild("UICorner"), "second mount too")

			first:destroy()
			second:destroy()
		end)
	end)

	--> ["components and portal"]

	H.group("component", function()
		H.test("a component builds with defaults", function()
			local Card = Kite.component("Card", function(props)
				return Kite.create("Frame", {
					Name = "Card",
					Size = Kite.use(props, "size", UDim2.fromOffset(220, 120)),
					Kite.create("TextLabel", { Text = Kite.use(props, "title", "untitled") }),
				})
			end, {
				size = { type = "UDim2", default = UDim2.fromOffset(220, 120) },
				title = { type = "string" },
			})

			local handle = Kite.mount(Card({ title = "hello" }), root())
			H.eq(handle.instance.Name, "Card", "built")
			H.eq(handle.instance:FindFirstChild("TextLabel").Text, "hello", "prop flowed through")
			handle:destroy()
		end)

		H.test("a component names the prop you got wrong", function()
			local Card = Kite.component("Card", function(_props)
				return Kite.create("Frame", {})
			end, {
				title = { type = "string", required = true },
			})

			H.throws(function()
				Card({ titel = "hello" })
			end, "does not take a prop", "guides on a typo")

			H.throws(function()
				Card({})
			end, "needs \"title\"", "guides on a missing prop")
		end)

		H.test("a portal mounts somewhere else and stays owned", function()
			local elsewhere = root()
			local handle = Kite.mount(Kite.create("Frame", {
				Kite.portal(Kite.create("TextLabel", { Name = "Floating" }), elsewhere),
			}), root())

			H.truthy(elsewhere:FindFirstChild("Floating"), "it lives in the other parent")
			handle:destroy()
			H.eq(#elsewhere:GetChildren(), 0, "and it left with the handle")
		end)
	end)

	--> ["hydrate"]

	H.group("hydrate", function()
		H.test("fills an instance that already exists", function()
			local existing = Instance.new("Frame")
			existing.Name = "Existing"

			local rows = Kite.source({ "one", "two" })

			local handle = Kite.hydrate(Kite.create("Frame", {
				BackgroundTransparency = 0.25,
				Kite.indexes(function()
					return rows()
				end, function(line)
					return Kite.create("TextLabel", { Text = line })
				end),
			}), existing)

			H.eq(existing.BackgroundTransparency, 0.25, "properties applied")
			H.eq(#existing:GetChildren(), 2, "children mounted")

			rows({ "one", "two", "three" })
			H.eq(#existing:GetChildren(), 3, "list tracks")

			handle:destroy()
			H.eq(#existing:GetChildren(), 0, "cleaned up, instance left alone")
		end)
	end)

	--> ["kite.go"]

	H.group("go", function()
		H.test("mounts to PlayerGui when no parent is given", function()
			Stub.login()

			local handle = Kite.mount(Kite.create("ScreenGui", { Name = "Auto" }))
			H.eq(handle.instance.Parent, Stub.playerGui, "parented to PlayerGui")

			handle:destroy()
			Stub.logout()
		end)

		H.test("kite.go builds, parents, and owns the tree", function()
			Stub.login()

			local count = Kite.source(0)

			local handle = Kite.go(function()
				return Kite.create("ScreenGui", {
					Name = "Go",
					Kite.create("TextLabel", { Name = "Label", Text = count }),
				})
			end)

			H.eq(handle.instance.Parent, Stub.playerGui, "on screen")
			H.eq(handle.instance.Name, "Go", "named")

			local label = handle.instance:FindFirstChild("Label")
			H.truthy(label, "child mounted")
			H.eq(label.Text, "0", "bound on mount")

			count(7)
			H.eq(label.Text, "7", "bound after a write")

			handle:destroy()
			H.eq(handle.alive, false, "destroyed")
			H.eq(#Stub.playerGui:GetChildren(), 0, "nothing left behind")

			Stub.logout()
		end)

		H.test("kite.go runs the builder inside a scope", function()
			Stub.login()

			local watched = 0
			local outer = Kite.source(1)
			local handle

			handle = Kite.go(function()
				outer:watch(function()
					watched += 1
				end)

				return Kite.create("Frame", { Name = "Scoped" })
			end)

			outer(2)
			H.eq(watched, 2, "the effect is alive")

			handle:destroy()
			outer(3)
			H.eq(watched, 2, "the effect died with the tree")

			Stub.logout()
		end)

		H.test("kite.go takes a parent when you have one", function()
			local host = Instance.new("Folder")
			local handle = Kite.go(function()
				return Kite.create("Frame", { Name = "Placed" })
			end, { parent = host })

			H.eq(handle.instance.Parent, host, "went where it was told")
			handle:destroy()
		end)

		H.test("kite.go explains itself when the builder returns nothing", function()
			Stub.login()

			local ok, message = pcall(function()
				Kite.go(function()
					return nil
				end)
			end)

			H.eq(ok, false, "it refuses")
			H.truthy(tostring(message):find("returned nothing"), "and says why")

			Stub.logout()
		end)
	end)
end
