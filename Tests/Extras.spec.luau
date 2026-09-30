--!strict
--[=[
	--> ["Kite : Tests : Extras"]

	Motion, themes, profiling, inspection, and help. The parts that decide
	whether you can live with a package after the demo stops being fun.
]=]

local G = require("./Globals")

local Instance = G.Instance
local UDim2 = G.UDim2

return function(H: any, Kite: any, Stub: any)
	local function root()
		return Instance.new("Folder")
	end

	--> ["motion"]

	H.group("motion", function()
		H.test("a spring settles on its target", function()
			local open = Kite.source(0)
			local slide = Kite.spring(open, { speed = 1, damping = 1 })

			H.near(slide(), 0, 0.001, "starts where it started")

			open(1)
			H.near(slide(), 0, 0.001, "no teleport: it has to travel")

			Stub.frames(120)
			H.near(slide(), 1, 0.01, "settled")
		end)

		H.test("a spring works on UDim2 too", function()
			local open = Kite.source(false)
			local position = Kite.spring(function()
				return if open() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 1)
			end, { speed = 1 })

			open(true)
			Stub.frames(160)

			H.near(position().Y.Scale, 0.5, 0.02, "arrived")
		end)

		H.test("every motion shares one frame connection", function()
			local a = Kite.source(0)
			local b = Kite.source(0)

			Kite.spring(a, 1)
			Kite.spring(b, 1)
			Kite.tween(a, { time = 0.5 })
			Kite.damp(b, 8)

			a(1)
			b(1)

			H.eq(Kite.stats().motion.connections, 1, "one connection for four motions")

			Stub.frames(400)
			H.eq(Kite.stats().motion.connections, 0, "it lets go when nothing is moving")
		end)

		H.test("a tween takes its time and then stops", function()
			local alpha = Kite.source(0)
			local moved = Kite.tween(alpha, { time = 0.5, ease = Kite.ease.Linear })

			alpha(1)
			Stub.frames(15) -- a quarter second: halfway through a half second tween
			H.near(moved(), 0.5, 0.08, "halfway at half time")

			Stub.frames(15)
			H.near(moved(), 1, 0.001, "arrived")
		end)

		H.test("damping never overshoots", function()
			local target = Kite.source(0)
			local smooth = Kite.damp(target, 10)

			target(1)

			local highest = 0
			for _ = 1, 60 do
				Stub.frame(1 / 60)
				highest = math.max(highest, smooth())
			end

			H.truthy(highest <= 1.0001, "never went past the target")
			H.truthy(smooth() > 0.9, "and it got there")
		end)

		H.test("a clock ticks once per frame", function()
			local clock = Kite.clock()
			H.near(clock(), 0, 0.001, "starts at zero")

			Stub.frames(30)
			H.near(clock(), 0.5, 0.02, "half a second")

			Stub.frames(30)
			H.near(clock(), 1, 0.02, "one second")
		end)

		H.test("motions are owned by the scope that made them", function()
			local value = Kite.source(0)
			local moved

			local scope = Kite.scope(function()
				moved = Kite.spring(value, 1)
			end)

			value(1)
			Stub.frames(10)
			H.truthy(moved() > 0, "it was moving")

			scope:destroy()
			local frozen = moved()
			Stub.frames(10)
			H.eq(moved(), frozen, "it stopped when the scope died")
		end)
	end)

	--> ["theme"]

	H.group("theme", function()
		H.test("tokens are sources", function()
			local theme = Kite.theme({
				mode = "dark",
				dark = { ink = "#0d181b", accent = "#3ddad7" },
				light = { ink = "#f4f7f7", accent = "#0f8f8d" },
			})

			H.near(theme.accent().R, 61 / 255, 0.01, "accent reads as a colour")
			H.near(theme:get("ink")().B, 27 / 255, 0.01, "get reads too")
		end)

		H.test("switching the theme moves everything that read it", function()
			local theme = Kite.theme({
				mode = "dark",
				dark = { ink = "#0d181b" },
				light = { ink = "#f4f7f7" },
			})

			local handle = Kite.mount(Kite.create("Frame", {
				BackgroundColor3 = theme.ink,
			}), root())

			H.near(handle.instance.BackgroundColor3.R, 13 / 255, 0.01, "dark first")

			theme:set("light")
			H.near(handle.instance.BackgroundColor3.R, 244 / 255, 0.01, "light after the switch")

			theme:toggle()
			H.near(handle.instance.BackgroundColor3.R, 13 / 255, 0.01, "and back")

			handle:destroy()
		end)

		H.test("a wrong token name is an error with a suggestion", function()
			local theme = Kite.theme({ ink = "#0d181b", accent = "#3ddad7" })

			H.throws(function()
				return theme:get("accentt")
			end, "did you mean", "it guesses")
		end)

		H.test("one flat palette works", function()
			local theme = Kite.theme({ ink = "#0d181b" })
			H.near(theme.ink().R, 13 / 255, 0.01, "flat palette reads")
		end)
	end)

	--> ["profiler"]

	H.group("profiler", function()
		H.test("counters move when Kite works", function()
			Kite.profiler():reset()

			local count = Kite.source(0)
			Kite.effect(function()
				return count()
			end)
			count(1)
			count(2)

			local snapshot = Kite.profiler():snapshot()
			H.truthy(snapshot.graph.writes >= 2, "writes counted")
			H.truthy(snapshot.graph.effects >= 1, "effects counted")
			H.truthy(snapshot.graph.nodes >= 2, "nodes counted")
		end)

		H.test("text, json, and html all render", function()
			local view = Kite.profiler()

			H.contains(view:text(), "Kite profiler", "text header")
			H.contains(view:json(), "graph", "json keys")
			H.contains(view:html(), "<!doctype html>", "html document")
		end)

		H.test("measure times a call and keeps the result", function()
			local measured = Kite.measure("add", function()
				return 2 + 2
			end)

			H.eq(measured.value, 4, "the return value survives")
			H.truthy(measured.milliseconds >= 0, "and the timing is a number")
		end)
	end)

	--> ["inspector"]

	H.group("inspector", function()
		H.test("the tree prints what was built", function()
			local handle = Kite.mount(Kite.create("Frame", {
				Name = "Panel",
				Kite.create("TextLabel", { Name = "Title", Text = "Kite" }),
			}), root())

			local view = Kite.inspector(handle.instance)
			local text = view:tree()

			H.contains(text, "Panel", "root name")
			H.contains(text, "Title", "child name")
			H.contains(text, "Kite", "child text")
			H.contains(text, "2 instance(s)", "counted")

			handle:destroy()
		end)

		H.test("html and dump render", function()
			local handle = Kite.mount(Kite.create("TextLabel", { Name = "Title", Text = "Kite" }), root())
			local view = Kite.inspector(handle.instance)

			H.contains(view:html(), "<!doctype html>", "html")
			H.contains(view:dump(), "Text", "dump lists properties")

			handle:destroy()
		end)

		H.test("the reactive graph can be drawn", function()
			local raw = Kite.source(1)
			local doubled = raw:map(function(value)
				return value * 2
			end)

			doubled()

			local view = Kite.inspector(Instance.new("Folder"))
			local graph = view:graph(doubled)

			H.contains(graph, "derive", "it shows the derive")
			H.contains(graph, "source", "and what it depends on")
			H.contains(view:dot(doubled), "digraph Kite", "graphviz output")
		end)
	end)

	--> ["help and modes"]

	H.group("help", function()
		H.test("every topic renders", function()
			local names = Kite.topics()
			H.truthy(#names >= 15, "there is a real set of topics")

			for _, name in names do
				local ok, rendered = pcall(function()
					return Kite.topic(name)
				end)

				H.truthy(ok, `kite.help("{name}") renders`)
				H.contains(rendered or "", `kite.help("{name}")`, "it says what it is")
			end
		end)

		H.test("an unknown topic suggests a real one", function()
			local rendered = Kite.topic("sprign")
			H.contains(rendered, "did you mean", "it does not throw, it helps")
			H.contains(rendered, "spring", "and it names the real topic")
		end)

		H.test("topics can be added", function()
			Kite.teach({
				name = "kite-testing",
				summary = "A topic added by the test suite.",
				example = "kite.help \"kite-testing\"",
			})

			local found = false
			for _, name in Kite.topics() do
				if name == "kite-testing" then
					found = true
				end
			end

			H.truthy(found, "the new topic is listed")
		end)
	end)

	H.group("modes", function()
		H.test("the three modes switch", function()
			Kite.mode("strict")
			H.eq(Kite.modeOf(), "strict", "strict")
			Kite.mode("creative")
			H.eq(Kite.modeOf(), "creative", "creative")
			Kite.mode("performance")
			H.eq(Kite.modeOf(), "performance", "performance")
			Kite.mode("creative")
		end)

		H.test("a wrong mode is an error with a suggestion", function()
			H.throws(function()
				Kite.mode("stricct")
			end, "did you mean", "it guesses the mode")
		end)

		H.test("the cache can be turned off and on", function()
			Kite.cache(false)
			Kite.cache(true)
			H.truthy(true, "both ways work")
		end)
	end)

	--> ["guidance"]

	H.group("guidance", function()
		H.test("kite.create names the shape it wanted", function()
			H.throws(function()
				Kite.create(42)
			end, "class name string", "it asks for a string")
		end)

		H.test("kite.mount catches a tree where the parent goes", function()
			H.throws(function()
				Kite.mount(Kite.create("Frame", {}), Kite.create("Frame", {}))
			end, "parent instance", "it explains the argument order")
		end)

		H.test("kite.keys catches a render that is not a function", function()
			H.throws(function()
				Kite.keys(function()
					return {}
				end, Kite.create("TextLabel", {}))
			end, "render to be a function", "it names the argument")
		end)

		H.test("stats reports the whole package", function()
			local stats = Kite.stats()
			H.eq(stats.version, Kite.VERSION, "version")
			H.truthy(stats.graph and stats.mount and stats.compile, "groups present")
			H.truthy(stats.keys and stats.motion and stats.component, "more groups")
		end)
	end)
end
