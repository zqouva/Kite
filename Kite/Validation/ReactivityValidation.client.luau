--!strict
--[=[
	--> ["Kite : Validation : reactivity"]

	Run this in Studio (LocalScript in StarterPlayerScripts). It asserts the
	reactive engine: reads, writes, derives, batches, ordering, scopes.

	Everything here also runs headlessly:
		python3 build.py --luau && luau Tests/run.luau
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

--> ["reads and writes"]

const count = Kite.source(1)
ok("a source reads", count() == 1)
count(2)
ok("a source writes through one call", count() == 2)
count:set(3)
ok("set writes", count() == 3)
count:update(function(v: number)
	return v + 1
end)
ok("update writes", count() == 4)

--> ["derives"]

const doubled = count:map(function(v: number): number
	return v * 2
end)
ok("a derive follows", doubled() == 8)
count(10)
ok("a derive updates", doubled() == 20)

--> ["effects run once per batch"]

const runs = 0
const a = Kite.source(1)
const b = Kite.source(2)

Kite.effect(function()
	a()
	b()
	runs += 1
end)

ok("an effect runs immediately", runs == 1)

Kite.batch(function()
	a(10)
	b(20)
	a(30)
end)

ok("a batch settles once", runs == 2, `ran {runs} times`)

--> ["nothing runs twice for the same value"]

const quiet = 0
const steady = Kite.source(5)
const always = steady:map(function(): boolean
	return true
end)

Kite.effect(function()
	always()
	quiet += 1
end)

steady(6)
steady(7)
ok("an unchanged derive does not wake its effect", quiet == 1, `ran {quiet} times`)

--> ["untracked reads stay out of it"]

const tracked = 0
const loud = Kite.source(1)
const hidden = Kite.source(1)

Kite.effect(function()
	loud()
	Kite.untrack(function()
		return hidden()
	end)
	tracked += 1
end)

hidden(2)
ok("untracked reads do not rerun", tracked == 1)
loud(2)
ok("tracked reads do rerun", tracked == 2)

--> ["scopes own what they make"]

const alive = 0
const ticker = Kite.source(0)

const scope = Kite.scope(function()
	Kite.effect(function()
		ticker()
		alive += 1
	end)
end)

ticker(1)
ok("the effect is alive inside its scope", alive == 2)

scope:destroy()
ticker(2)
ok("the effect died with its scope", alive == 2)

--> ["records"]

const stats = Kite.record({ hp = 100, aura = { grace = 1 } })
stats.hp(80)
stats.aura.grace(4)
ok("a record holds sources", stats.hp() == 80 and stats.aura.grace() == 4)

--> ["report"]

print(`[Kite] reactivity validation · {passed} passed · {failed} failed`)

if failed > 0 then
	error("[Kite] reactivity validation failed", 0)
end

return passed
