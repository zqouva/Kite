--!strict
--[=[
	--> ["Kite : Validation : profiler and motion"]

	Run this in Studio. It asserts that the counters move, that motion shares
	one frame connection, and that the inspector can draw what was built.
]=]

const Kite = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Kite"))

const passed = 0
const failed = 0

local function ok(name: string, condition: boolean, note: string?)
	if condition then
		passed += 1
	else
		failed += 1
		warn(`[Kite] FAILED · {name}{if note then ` · {note}` else ""}`)
	end
end

local function has(text: string, needle: string): boolean
	return string.find(text, needle, 1, true) ~= nil
end

--> ["counters"]

Kite.profile(true)
Kite.profiler():reset()

const count = Kite.source(0)
Kite.effect(function()
	return count()
end)

count(1)
count(2)

const snapshot = Kite.profiler():snapshot()
ok("writes are counted", snapshot.graph.writes >= 2, tostring(snapshot.graph.writes))
ok("effects are counted", snapshot.graph.effects >= 1)
ok("nodes are counted", snapshot.graph.nodes >= 2)

ok("the text report renders", has(Kite.profiler():text(), "Kite profiler"))
ok("the json report renders", has(Kite.profiler():json(), "graph"))
ok("the html report renders", has(Kite.profiler():html(), "<!doctype html>"))

const measured = Kite.measure("nothing", function()
	return 1 + 1
end)
ok("measure keeps the value", measured.value == 2)
ok("measure keeps the timing", measured.milliseconds >= 0)

--> ["motion"]

const value = Kite.source(0)
const slide = Kite.spring(value, 1)
const eased = Kite.tween(value, { time = 0.4 })
const smooth = Kite.damp(value, 10)
const clock = Kite.clock()

value(100)

ok("four motions share one connection", Kite.stats().motion.connections == 1, tostring(Kite.stats().motion.connections))
ok("a spring starts where it started", slide() == 0)

task.wait(1.5)

ok("a spring settled", math.abs(slide() - 100) < 1, tostring(slide()))
ok("a tween arrived", math.abs(eased() - 100) < 1, tostring(eased()))
ok("a damp arrived", math.abs(smooth() - 100) < 2, tostring(smooth()))
ok("a clock ran", clock() > 0.5, tostring(clock()))
ok("the driver const go", Kite.stats().motion.connections == 1 or Kite.stats().motion.connections == 0)

--> ["UDim2 springs"]

const open = Kite.source(false)
const position = Kite.spring(function(): UDim2
	return if open() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 1)
end, 1)

open(true)
task.wait(1.5)
ok("a UDim2 spring settles", math.abs(position().Y.Scale - 0.5) < 0.05, tostring(position().Y.Scale))

--> ["inspector"]

const handle = Kite.mount(Kite.create("Frame", {
	Name = "Panel",
	Kite.children({ Kite.create("TextLabel", { Name = "Title", Text = "Kite" }) }),
}), Instance.new("Folder"))

const view = Kite.inspector(handle.instance)
ok("the tree prints", has(view:tree(), "Panel"))
ok("the tree names children", has(view:tree(), "Title"))
ok("the tree counts", has(view:tree(), "2 instance(s)"))
ok("html renders", has(view:html(), "<!doctype html>"))
ok("dump renders", has(view:dump(), "Panel"))
ok("the graph draws", has(view:graph(count), "source"))
ok("graphviz renders", has(view:dot(count), "digraph Kite"))

handle:destroy()

--> ["help"]

ok("help has topics", #Kite.topics() >= 15)
ok("help renders a topic", has(Kite.topic("spring"), "kite.help(\"spring\")"))
ok("help suggests", has(Kite.topic("sprign"), "did you mean"))

--> ["report"]

print(`[Kite] profiler validation · {passed} passed · {failed} failed`)

if failed > 0 then
	error("[Kite] profiler validation failed", 0)
end

return passed
