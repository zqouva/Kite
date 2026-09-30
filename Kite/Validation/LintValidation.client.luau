--!strict
--[=[
	--> ["Kite : Validation : lint"]

	Run this in Studio. It asserts that the three modes see what they should,
	that messages teach, and that reports render as text, json, and html.
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

--> ["strict"]

const unknown = Kite.strict(Kite.create("Frame", { Text = "hi" }))
ok("strict catches unknown properties", not unknown:isOk())
ok("strict explains itself", has(unknown:text(), "no property called"))

const typo = Kite.strict(Kite.create("TextLabel", { TextColour3 = Color3.new(1, 1, 1) }))
ok("strict suggests the real name", has(typo:text(), "did you mean"))

const sweet = Kite.strict(Kite.create("Frame", { corner = 8 }))
ok("strict refuses sugar", not sweet:isOk())
ok("strict offers the long form", has(sweet:text(), "sugar"))

const typed = Kite.strict(Kite.create("TextLabel", { Text = 42 }))
ok("strict checks types", not typed:isOk())

const ranged = Kite.strict(Kite.create("Frame", { BackgroundTransparency = 4 }))
ok("strict checks ranges", not ranged:isOk())

const clean = Kite.strict(Kite.create("TextLabel", { Name = "Label", Text = "hi", TextSize = 16 }))
ok("strict passes a clean tree", clean:isOk())

--> ["creative"]

const sugar = Kite.creative(Kite.create("Frame", { Name = "Card", corner = 8, padding = 12 }))
ok("creative accepts sugar", sugar:isOk())

const coerced = Kite.creative(Kite.create("TextLabel", { Text = 42 }))
ok("creative coerces types", coerced:isOk())

const nonsense = Kite.creative(Kite.create("Frame", { DefinitelyNotAProperty = true }))
ok("creative still catches what would break", not nonsense:isOk())

const scroll = Kite.creative(Kite.create("ScrollingFrame", { Name = "Scroll" }))
ok("creative notices a frame that cannot scroll", has(scroll:text(), "CanvasSize"))

--> ["performance"]

const deep = Kite.performance(Kite.create("Frame", {
	Kite.create("Frame", { Kite.create("Frame", { Kite.create("Frame", {
		Kite.create("Frame", { Kite.create("Frame", { Kite.create("Frame", {
			Kite.create("Frame", { Kite.create("Frame", { Kite.create("TextLabel", {}) }) }),
		}) }) }),
	}) }) }),
}))

ok("performance counts depth", has(deep:text(), "levels deep"))

const loose = Kite.performance(Kite.create("Frame", { NotAProperty = true }))
ok("performance skips correctness", loose:isOk())

--> ["reports"]

const report = Kite.creative(Kite.create("ScreenGui", { Kite.create("ScrollingFrame", {}) }))
ok("text renders", has(report:text(), "Kite lint"))
ok("json renders", has(report:json(), "\"level\""))
ok("html renders", has(report:html(), "<!doctype html>"))
ok("errors are separated", #report:errors() == 0)
ok("warnings are separated", #report:warnings() >= 1)
ok("hints are separated", #report:hints() >= 1)
ok("the tree is measured", report.instances == 2)

--> ["teaching Kite a class"]

Kite.know("ShinyFrame", "Frame", { Glow = "number" }, { "Sparkled" })
ok("a taught class is checked", not Kite.strict(Kite.create("ShinyFrame", { Glow = "bright" })):isOk())
ok("a taught class accepts the right type", Kite.strict(Kite.create("ShinyFrame", { Glow = 2 })):isOk())

--> ["report"]

print(`[Kite] lint validation · {passed} passed · {failed} failed`)

if failed > 0 then
	error("[Kite] lint validation failed", 0)
end

return passed
