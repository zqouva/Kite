--!strict
--[=[
	--> ["Kite : Tests : Reactivity"]

	The engine. If this file is green, the graph is honest: nothing runs
	twice, nothing runs stale, nothing runs before its inputs settled.
]=]


return function(H: any, Kite: any)
	--> ["sources"]

	H.group("source", function()
		H.test("reads and writes through one call", function()
			local count = Kite.source(0)
			H.eq(count(), 0, "starts at zero")
			count(4)
			H.eq(count(), 4, "writes through the call")
		end)

		H.test("methods match the call forms", function()
			local count = Kite.source(1)
			H.eq(count:get(), 1, "get")
			count:set(2)
			H.eq(count(), 2, "set")
			count:update(function(value)
				return value * 10
			end)
			H.eq(count(), 20, "update")
		end)

		H.test("a write of the same value costs nothing", function()
			local count = Kite.source(5)
			local runs = Kite.source(0)

			Kite.effect(function()
				count()
				runs(runs:peek() + 1)
			end)

			H.eq(runs(), 1, "the first run")
			count(5)
			H.eq(runs(), 1, "same value, no rerun")
			count(6)
			H.eq(runs(), 2, "new value, one rerun")
		end)

		H.test("peek reads without subscribing", function()
			local watched = Kite.source(1)
			local runs = Kite.source(0)

			Kite.effect(function()
				watched:peek()
				runs(runs:peek() + 1)
			end)

			H.eq(runs(), 1, "ran once")
			watched(99)
			H.eq(runs(), 1, "still once: peek does not subscribe")
		end)

		H.test("toggle flips a boolean", function()
			local open = Kite.source(false)
			H.eq(open:toggle(), true, "toggled on")
			H.eq(open:toggle(), false, "toggled off")
		end)
	end)

	--> ["derives"]

	H.group("derive", function()
		H.test("follows what it read", function()
			local hp = Kite.source(100)
			local status = Kite.derive(function()
				return if hp() > 0 then "alive" else "down"
			end)

			H.eq(status(), "alive", "starts alive")
			hp(0)
			H.eq(status(), "down", "falls when hp does")
		end)

		H.test("is lazy: a derive nobody reads never computes", function()
			local before = Kite.stats().graph.computes
			local hp = Kite.source(1)
			local dead = Kite.derive(function()
				return hp() * 1000
			end)

			hp(2)
			hp(3)

			H.eq(Kite.stats().graph.computes - before, 0, "never computed")
			H.eq(dead(), 3000, "and it is correct when finally read")
		end)

		H.test("does not recompute when its value lands on the same thing", function()
			local hp = Kite.source(10)
			local computes = Kite.source(0)

			local alive = Kite.derive(function()
				computes(computes:peek() + 1)
				return hp() > 0
			end)

			H.eq(alive(), true, "computed once")
			H.eq(computes(), 1, "one compute")

			hp(20)
			H.eq(alive(), true, "still true")
			H.eq(computes(), 2, "recomputed because hp moved")

			-- the value did not change, so its own watchers must not fire
			local listener = Kite.source(0)
			Kite.effect(function()
				alive()
				listener(listener:peek() + 1)
			end)
			H.eq(listener(), 1, "listener ran once")

			hp(30)
			H.eq(listener(), 1, "derive value unchanged, listener untouched")
		end)

		H.test("map and pick build derives off a source", function()
			local stats = Kite.source({ hp = 40, mana = 10 })
			local hp = stats:map(function(value)
				return value.hp
			end)
			local mana = stats:pick("mana")

			H.eq(hp(), 40, "map reads the field")
			H.eq(mana(), 10, "pick reads the key")

			stats({ hp = 1, mana = 2 })
			H.eq(hp(), 1, "map follows")
			H.eq(mana(), 2, "pick follows")
		end)

		H.test("a derive refuses writes and says why", function()
			local doubled = Kite.source(2):map(function(value)
				return value * 2
			end)

			H.throws(function()
				doubled(10)
			end, "Only sources accept writes", "guides instead of crashing")
		end)
	end)

	--> ["effects"]

	H.group("effect", function()
		H.test("runs now and on every change", function()
			local count = Kite.source(0)
			local seen = {}

			Kite.effect(function()
				table.insert(seen, count())
			end)

			count(1)
			count(2)

			H.eq(#seen, 3, "one run per change")
			H.eq(seen[1], 0, "first run is immediate")
			H.eq(seen[3], 2, "last run sees the newest value")
		end)

		H.test("watch returns a stop function", function()
			local count = Kite.source(0)
			local runs = Kite.source(0)

			local stop = count:watch(function()
				runs(runs:peek() + 1)
			end)

			H.eq(runs(), 1, "ran once")
			count(1)
			H.eq(runs(), 2, "ran again")
			stop()
			count(2)
			H.eq(runs(), 2, "stopped")
		end)

		H.test("returned cleanup runs before the next run", function()
			local count = Kite.source(0)
			local cleaned = Kite.source(0)

			Kite.effect(function()
				count()
				return function()
					cleaned(cleaned:peek() + 1)
				end
			end)

			count(1)
			count(2)

			H.eq(cleaned(), 2, "one cleanup per rerun, none for the first run")
		end)

		H.test("nested effects die with the effect that made them", function()
			local mode = Kite.source("a")
			local inner = Kite.source(0)
			local tick = Kite.source(0)
			local runs = Kite.source(0)

			Kite.effect(function()
				if mode() == "a" then
					Kite.effect(function()
						tick()
						runs(runs:peek() + 1)
					end)
				end
				inner()
			end)

			H.eq(runs(), 1, "inner effect exists")

			mode("b")
			H.eq(runs(), 1, "inner effect was destroyed with the run")

			tick(1)
			H.eq(runs(), 1, "and it is not listening any more")

			mode("a")
			H.eq(runs(), 2, "it comes back with the branch")
		end)
	end)

	--> ["batching and ordering"]

	H.group("batch", function()
		H.test("many writes settle once", function()
			local a = Kite.source(1)
			local b = Kite.source(2)
			local c = Kite.source(3)
			local runs = Kite.source(0)

			Kite.effect(function()
				a()
				b()
				c()
				runs(runs:peek() + 1)
			end)

			H.eq(runs(), 1, "ran once to start")

			Kite.batch(function()
				a(10)
				b(20)
				c(30)
			end)

			H.eq(runs(), 2, "one settle for three writes")
		end)

		H.test("a batch is glitch free: no effect sees half a change", function()
			local hp = Kite.source(100)
			local shield = Kite.source(100)
			local seen = {}

			Kite.effect(function()
				table.insert(seen, `{hp()}/{shield()}`)
			end)

			Kite.batch(function()
				hp(0)
				shield(0)
			end)

			H.eq(#seen, 2, "two runs, not three")
			H.eq(seen[2], "0/0", "the second run sees both writes")
		end)

		H.test("effects run shallowest first", function()
			local raw = Kite.source(1)
			local doubled = Kite.derive(function()
				return raw() * 2
			end)
			local order = {}

			Kite.effect(function()
				table.insert(order, `raw:{raw()}`)
			end)

			Kite.effect(function()
				table.insert(order, `doubled:{doubled()}`)
			end)

			order = {}
			raw(5)

			H.eq(#order, 2, "both ran")
			H.eq(order[1], "raw:5", "the shallow one went first")
			H.eq(order[2], "doubled:10", "and it saw the fresh value")
		end)

		H.test("untrack hides a read from the effect", function()
			local loud = Kite.source(1)
			local quiet = Kite.source(1)
			local runs = Kite.source(0)

			Kite.effect(function()
				loud()
				Kite.untrack(function()
					return quiet()
				end)
				runs(runs:peek() + 1)
			end)

			H.eq(runs(), 1, "ran once")
			quiet(5)
			H.eq(runs(), 1, "the quiet source moved nothing")
			loud(5)
			H.eq(runs(), 2, "the loud one still works")
		end)
	end)

	--> ["scopes and records"]

	H.group("scope", function()
		H.test("destroying a scope stops what it owned", function()
			local count = Kite.source(0)
			local runs = Kite.source(0)
			local cleaned = Kite.source(0)

			local scope = Kite.scope(function()
				Kite.effect(function()
					count()
					runs(runs:peek() + 1)
				end)

				Kite.cleanup(function()
					cleaned(cleaned:peek() + 1)
				end)
			end)

			count(1)
			H.eq(runs(), 2, "it was alive")

			scope:destroy()
			count(2)
			H.eq(runs(), 2, "it is not listening any more")
			H.eq(cleaned(), 1, "cleanups ran once")
		end)

		H.test("record turns a table into sources", function()
			local stats = Kite.record({ hp = 100, aura = { grace = 1 } })

			stats.hp(80)
			stats.aura.grace(4)

			H.eq(stats.hp(), 80, "flat field")
			H.eq(stats.aura.grace(), 4, "nested field")
		end)

		H.test("cleanup outside a scope warns instead of vanishing", function()
			-- the warning path must not throw
			Kite.cleanup(function()
				-- nothing to clean
			end)
		end)
	end)
end
