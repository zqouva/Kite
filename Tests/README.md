# Kite : Tests

`--> ["what this is"]`

The suite that runs Kite outside Studio.

Roblox is not required. The Roblox half is a stub, and the Kite half is the
real package: the same files you drop into ReplicatedStorage, only with
`const` lowered to `local`.

```bash
python3 build.py --luau       # const -> local, into build/Luau
luau Tests/run.luau           # run the suite
./tools/analyze.sh            # type check it
```

Exit code 1 if anything failed, and it says exactly what.

---

`--> ["what is here"]`

```text
Tests/
  Stub.luau              a Roblox, small enough to read
  Globals.luau           hands the stub globals to a spec
  Harness.luau           assert, group, report
  run.luau               the runner
  analyze-preamble.luau  Roblox types for luau-analyze
  roblox.d.luau          Roblox globals for luau-analyze
  Reactivity.spec.luau   the engine
  Mount.spec.luau        trees, bindings, lists, sugar, components
  Lint.spec.luau         the three modes
  Extras.spec.luau       motion, theme, profiler, inspector, help
```

---

`--> ["how it works"]`

The Luau CLI gives every required module its own globals table, which Roblox
does not. So `build.py` also emits the package as **one chunk**,
`build/Luau/Kite/Bundle.luau`, and the runner hands it a table of Roblox
globals:

```lua
const Stub = require("./Stub")
const Bundle = require("../build/Luau/Kite/Bundle")
const Kite = Bundle(Stub.exports())
```

Inside Roblox you would just `require(path.to.Kite)`.

Specs pull Roblox globals from `Globals.luau` the same way, because a spec
cannot reach for `Instance` in an environment that has no `Instance`.

---

`--> ["the stub"]`

`Stub.luau` is not trying to be Roblox. It is trying to answer "does Kite
behave correctly".

- `Instance` with real property storage, real parent links, real ordering
- `Instance:IsA` against a real class hierarchy
- events that return `RBXScriptSignal` shaped things, fired by hand
- UDim, UDim2, Vector2, Vector3, Color3, CFrame, Rect, ColorSequence, Font
- `Enum` groups with `GetEnumItems`
- `RunService` with `Stub.frame(dt)` and `Stub.frames(count)`, so a spring
  settles without waiting on a clock
- `CollectionService` with tags

---

`--> ["writing a test"]`

```lua
H.group("keys", function()
	H.test("rows are reused", function()
		const rows = Kite.source({ { id = "a" } })

		const handle = Kite.mount(Kite.create("Frame", {
			Kite.keys(function() return rows() end, function(item)
				return Kite.create("TextLabel", { Text = function() return item().id end })
			end, function(item) return item.id end),
		}), Instance.new("Folder"))

		H.eq(handle.instance:FindFirstChild("a").Text, "a", "the row is there")
		handle:destroy()
	end)
end)
```

Assertions: `eq`, `ne`, `near`, `truthy`, `falsy`, `contains`, `missing`,
`throws`, `count`.

---

`--> ["current state"]`

95 assertions, 0 failures, on the package as it stands in source.
