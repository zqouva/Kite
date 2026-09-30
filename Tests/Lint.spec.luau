--!strict
--[=[
	--> ["Kite : Tests : Lint"]

	The three modes. A linter is only useful if it is right, and it is only
	kind if it tells you what to write instead.
]=]

local G = require("./Globals")

local UDim2 = G.UDim2
local Color3 = G.Color3

return function(H: any, Kite: any)
	H.group("strict", function()
		H.test("an unknown property is an error with a suggestion", function()
			local report = Kite.strict(Kite.create("Frame", {
				Text = "hello",
			}))

			H.falsy(report:isOk(), "not ok")
			local text = report:text()
			H.contains(text, "no property called", "it names the problem")
			H.contains(text, "TextLabel", "it points at the right class")
		end)

		H.test("a near miss suggests the real name", function()
			local report = Kite.strict(Kite.create("TextLabel", {
				TextColour3 = Color3.new(1, 1, 1),
			}))

			H.contains(report:text(), "did you mean", "it guessed")
		end)

		H.test("a wrong type is an error that shows the right shape", function()
			local report = Kite.strict(Kite.create("TextLabel", {
				Text = 42,
			}))

			H.falsy(report:isOk(), "not ok")
			H.contains(report:text(), "expects string", "it says what it wanted")
		end)

		H.test("a value outside its range is an error", function()
			local report = Kite.strict(Kite.create("Frame", {
				BackgroundTransparency = 4,
			}))

			H.falsy(report:isOk(), "not ok")
			H.contains(report:text(), "between", "it names the range")
		end)

		H.test("sugar is refused, with the long form offered", function()
			local report = Kite.strict(Kite.create("Frame", {
				corner = 8,
			}))

			H.falsy(report:isOk(), "not ok")
			H.contains(report:text(), "strict mode refuses sugar", "it explains the mode")
		end)

		H.test("an unkeyed list is an error in strict", function()
			local report = Kite.strict(Kite.create("Frame", {
				Kite.keys(function()
					return {}
				end, function()
					return Kite.create("TextLabel", {})
				end),
			}))

			H.contains(report:text(), "no key function", "it wants identity")
		end)

		H.test("a clean tree is clean", function()
			local report = Kite.strict(Kite.create("TextLabel", {
				Name = "Label",
				Text = "hello",
				TextSize = 16,
				Size = UDim2.fromOffset(100, 20),
			}))

			H.truthy(report:isOk(), "ok")
			H.eq(#report:errors(), 0, "no errors")
		end)
	end)

	H.group("creative", function()
		H.test("sugar is allowed and reported as information", function()
			local report = Kite.creative(Kite.create("Frame", {
				Name = "Card",
				corner = 8,
			}))

			H.truthy(report:isOk(), "sugar does not fail the build")
		end)

		H.test("types are coerced instead of rejected", function()
			local report = Kite.creative(Kite.create("TextLabel", {
				Text = 42,
			}))

			H.truthy(report:isOk(), "42 became a string")
		end)

		H.test("an unknown property is still an error", function()
			local report = Kite.creative(Kite.create("Frame", {
				DefinitelyNotReal = true,
			}))

			H.falsy(report:isOk(), "would break at runtime, so lint it")
		end)

		H.test("it warns about a scrolling frame that cannot scroll", function()
			local report = Kite.creative(Kite.create("ScrollingFrame", {
				Name = "Scroll",
			}))

			H.contains(report:text(), "CanvasSize", "it knows what is missing")
		end)

		H.test("it nudges a ScreenGui to say what happens on respawn", function()
			local report = Kite.creative(Kite.create("ScreenGui", {
				Name = "Hud",
			}))

			H.contains(report:text(), "ResetOnSpawn", "it asks the question you forgot")
		end)
	end)

	H.group("performance", function()
		H.test("correctness is skipped, cost is reported", function()
			local report = Kite.performance(Kite.create("Frame", {
				NotAProperty = true,
			}))

			H.truthy(report:isOk(), "performance mode does not check names")
		end)

		H.test("a deep tree is a warning", function()
			local function nest(depth)
				if depth == 0 then
					return Kite.create("TextLabel", { Name = "Leaf" })
				end
				return Kite.create("Frame", {
					Name = `Level{depth}`,
					nest(depth - 1),
				})
			end

			local report = Kite.performance(nest(12))
			H.contains(report:text(), "levels deep", "it counted the depth")
		end)

		H.test("reactive layout properties get a hint", function()
			local open = Kite.source(false)

			local report = Kite.performance(Kite.create("Frame", {
				Name = "Panel",
				Size = function()
					return if open() then UDim2.fromOffset(100, 100) else UDim2.fromOffset(0, 0)
				end,
			}))

			H.contains(report:text(), "relayouts", "it knows what Size costs")
		end)

		H.test("unkeyed lists are still flagged in performance mode", function()
			local report = Kite.performance(Kite.create("Frame", {
				Kite.keys(function()
					return {}
				end, function()
					return Kite.create("TextLabel", {})
				end),
			}))

			H.contains(report:text(), "no key function", "cost is not correctness")
		end)
	end)

	H.group("report", function()
		H.test("text, json, and html all render", function()
			local report = Kite.strict(Kite.create("Frame", {
				Text = "hi",
			}))

			H.contains(report:text(), "Kite lint", "text header")
			H.contains(report:json(), "\"level\"", "json body")
			H.contains(report:html(), "<!doctype html>", "html document")
			H.contains(report:html(), "Kite lint", "html title")
		end)

		H.test("errors, warnings, and hints are separated", function()
			local report = Kite.creative(Kite.create("ScreenGui", {
				Kite.create("ScrollingFrame", {}),
			}))

			H.eq(#report:errors(), 0, "no errors")
			H.truthy(#report:warnings() >= 1, "at least one warning")
			H.truthy(#report:hints() >= 1, "at least one hint")
		end)

		H.test("the tree is measured while it is checked", function()
			local report = Kite.creative(Kite.create("Frame", {
				Kite.create("TextLabel", {}),
				Kite.create("TextLabel", {}),
			}))

			H.eq(report.instances, 3, "counted every instance")
			H.eq(report.depth, 2, "counted the levels")
		end)
	end)

	H.group("teach", function()
		H.test("kite.know adds a class the linter can use", function()
			Kite.know("ShinyFrame", "Frame", { Glow = "number" }, { "Sparkled" })

			local before = Kite.strict(Kite.create("ShinyFrame", { Glow = "bright" }))
			H.falsy(before:isOk(), "it checks the new class")

			local after = Kite.strict(Kite.create("ShinyFrame", { Glow = 2 }))
			H.truthy(after:isOk(), "and it accepts the right type")
		end)
	end)
end
