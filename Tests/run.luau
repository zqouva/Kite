--!strict
--[=[
	--> ["Kite : Tests : run"]

	Runs the whole suite outside Studio, in one process, against the
	lowered Luau build.

		python3 build.py --luau
		luau Tests/run.luau

	The Roblox side is a stub. The Kite side is the real package: the same
	files you drop into ReplicatedStorage, only with `const` lowered to
	`local`.

	Exit code 1 if anything failed, and it says exactly what.
]=]

local started = os.clock()

local Stub = require("./Stub")
local Harness = require("./Harness")

local Bundle = require("../build/Luau/Kite/Bundle")
local Kite = Bundle(Stub.exports())

print("")
print(`  Kite {Kite.VERSION} · tests`)
print(`  mode {Kite.modeOf()} · stub ready`)

local specs = {
	{ "reactivity", require("./Reactivity.spec") },
	{ "mount", require("./Mount.spec") },
	{ "lint", require("./Lint.spec") },
	{ "extras", require("./Extras.spec") },
}

for _, spec in specs do
	print(`--> [{spec[1]}]`)
	spec[2](Harness, Kite, Stub)
end

local code = Harness.done()

print(`  stub: {Stub.stats().instances} instance(s), {Stub.stats().frames} frame(s) stepped`)
print(`  took {string.format("%.2f", (os.clock() - started) * 1000)}ms`)
print("")

if code ~= 0 then
	error(`{Harness.failed} test(s) failed`, 0)
end

return nil
