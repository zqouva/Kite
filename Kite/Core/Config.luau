--!strict
--[=[
	--> ["Kite : Config"]

	The three modes live here. One table, read by the compiler, the mounter,
	and the linter.

		kite.mode `strict`       nothing implicit, nothing sugar, it tells you
		kite.mode `creative`     shorthands, coercion, it stays out of the way
		kite.mode `performance`  no guarding, no validation, straight to work

	--> ["what each mode actually changes"]
	```text
	                      strict   creative   performance
	unknown property      error    error      allowed
	sugar (padding, ...)  error    expanded   expanded
	type coercion         error    coerced    skipped
	range checks          error    error      skipped
	compile cache         on       on         on
	profiling hooks       on       off        off
	```
]=]

const Config = {}

export type Modes = "strict" | "creative" | "performance"

const ORDER: { string } = { "strict", "creative", "performance" }

Config.mode = "creative" :: string
Config.sugar = true
Config.validate = true
Config.guard = false
Config.cache = true
Config.profile = false
Config.trace = false

const PROFILES: { [string]: { sugar: boolean, validate: boolean, guard: boolean, profile: boolean } } = {
	strict = { sugar = false, validate = true, guard = true, profile = false },
	creative = { sugar = true, validate = true, guard = false, profile = false },
	performance = { sugar = true, validate = false, guard = false, profile = false },
}

Config.modes = table.freeze(ORDER)

function Config.apply(mode: string)
	const hit = PROFILES[mode]

	if not hit then
		const nearest = require(script.Parent.Util).nearest(mode, ORDER)
		error(
			`[Kite] "{mode}" is not a mode. Kite has three: strict, creative, performance.\n`
				.. `  did you mean "{nearest}"?\n`
				.. "  kite.mode \"creative\"  <- shorthands on, guidance on\n"
				.. "  kite.mode \"strict\"    <- nothing implicit\n"
				.. "  kite.mode \"performance\" <- nothing checked",
			2
		)
	end

	Config.mode = mode
	Config.sugar = hit.sugar
	Config.validate = hit.validate
	Config.guard = hit.guard
	Config.profile = hit.profile
end

function Config.is(mode: string): boolean
	return Config.mode == mode
end

return Config
