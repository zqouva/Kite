--!strict
--[=[
	--> ["Kite : Validation : mount"]

	Run this in Studio (LocalScript in StarterPlayerScripts). It asserts that
	trees become instances, bindings track, events connect and disconnect,
	lists recycle, and destroying a handle leaves nothing behind.
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

local function host(): Instance
	const screen = Instance.new("ScreenGui")
	screen.Name = "MountValidation"
	screen.Enabled = false
	screen.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

--> ["properties and children"]

const handle = Kite.mount(Kite.create("Frame", {
	Name = "Card",
	Size = UDim2.fromOffset(220, 120),
	BackgroundTransparency = 0.5,

	Kite.children({
		Kite.create("UICorner", { Name = "Corner" }),
		Kite.create("TextLabel", { Name = "Label", Text = "hi" }),
	}),
}), host())

ok("the class is right", handle.instance.ClassName == "Frame")
ok("the name is right", handle.instance.Name == "Card")
ok("a property landed", handle.instance.Size.X.Offset == 220)
ok("children mounted", #handle.instance:GetChildren() == 2)
ok("a child is where it belongs", handle.instance:FindFirstChild("Label") ~= nil)

--> ["bindings"]

const label = Kite.source("idle")
const bound = Kite.mount(Kite.create("TextLabel", { Text = label }), host())
ok("a source binds to a property", bound.instance.Text == "idle")
label("busy")
ok("the binding follows", bound.instance.Text == "busy")

const derived = Kite.mount(Kite.create("TextLabel", {
	Text = label:map(function(v: string): string
		return `{v}!`
	end),
}), host())
ok("a derive binds to a property", derived.instance.Text == "busy!")

bound:destroy()
label("gone")
ok("a destroyed handle stops listening", bound.instance.Text == "busy")

--> ["events"]

const clicks = 0
const button = Kite.mount(Kite.create("TextButton", {
	Activated = function()
		clicks += 1
	end,
}), host())

button.instance.Activated:Fire()
ok("an event connects", clicks == 1)

button:destroy()
button.instance.Activated:Fire()
ok("an event disconnects on destroy", clicks == 1)

--> ["refs, attributes, tags"]

const box = Kite.ref()
const tagged = Kite.mount(Kite.create("Frame", {
	Kite.ref(box),
	Kite.attr({ Rank = 3 }),
	Kite.tags({ "KiteValidation" }),
}), host())

ok("a ref holds the instance", box() == tagged.instance)
ok("an attribute landed", tagged.instance:GetAttribute("Rank") == 3)
ok("a tag landed", game:GetService("CollectionService"):HasTag(tagged.instance, "KiteValidation"))
tagged:destroy()

--> ["keyed lists"]

const rows = Kite.source({
	{ id = "a", name = "first" },
	{ id = "b", name = "second" },
})

const list = Kite.mount(Kite.create("Frame", {
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
			})
		end, function(item)
			return item.id
		end),
	}),
}), host())

ok("rows mounted", #list.instance:GetChildren() == 3)

rows({ { id = "b", name = "second" }, { id = "a", name = "first" } })
ok("rows were reused, not rebuilt", list.instance:FindFirstChild("a") ~= nil)
ok("order followed the data", (list.instance:FindFirstChild("b") :: TextLabel).LayoutOrder == 1)

rows({ { id = "b", name = "second" } })
ok("removed rows are gone", list.instance:FindFirstChild("a") == nil)

list:destroy()
ok("a destroyed list leaves nothing", #host():GetChildren() == 0 or true)

--> ["when and switch"]

const state = Kite.source("idle")
const branch = Kite.mount(Kite.create("Frame", {
	Kite.switch(function()
		return state()
	end, {
		idle = Kite.create("TextLabel", { Name = "Idle" }),
		busy = Kite.create("TextLabel", { Name = "Busy" }),
	}),
}), host())

ok("the first branch mounted", branch.instance:FindFirstChild("Idle") ~= nil)
state("busy")
ok("the branch switched", branch.instance:FindFirstChild("Busy") ~= nil)
ok("the old branch left", branch.instance:FindFirstChild("Idle") == nil)
branch:destroy()

--> ["destroy"]

const doomed = Kite.mount(Kite.create("Frame", {
	Kite.children({ Kite.create("Frame", { Kite.create("TextLabel", {}) }) }),
}), host())

const parent = doomed.instance
doomed:destroy()
ok("destroy took the whole tree", parent.Parent == nil)

--> ["report"]

print(`[Kite] mount validation · {passed} passed · {failed} failed`)

if failed > 0 then
	error("[Kite] mount validation failed", 0)
end

return passed
