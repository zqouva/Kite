--!strict
--[=[
	--> ["Kite : Lint"]

	Three ways to read a tree before you run it.

		kite.strict(tree)       hard, explicit, nothing implicit
		kite.creative(tree)     shorthands allowed, structure still checked
		kite.performance(tree)  costs instead of correctness

	Each one gives you a report:

	```lua
	const report = kite.strict(tree)
	print(report:text())
	if not report:isOk() then report:print() end
	```

	--> ["what is checked"]
	```text
	                        strict   creative   performance
	unknown property        error    error      -
	type mismatch            error    hint       -
	value range              error    error      -
	sugar                    error    hint       hint
	unkeyed list             error    warn       warn
	missing identity key     error    warn       warn
	deep tree                hint     hint       warn
	large tree               -        hint       warn
	animated layout          -        hint       warn
	dynamics per instance    -        -          hint
	respawn behaviour        hint     hint       hint
	```

	--> ["why the messages read like this"]
	A linter that says `invalid property` teaches nothing. Every message
	here names the class, the key, what Kite expected, and the line you
	would write instead.
]=]

const Util = require(script.Parent.Util)
const Types = require(script.Parent.Types)
const Config = require(script.Parent.Config)
const Compiler = require(script.Parent.Compiler)

export type Diagnostic = {
	level: string,
	code: string,
	path: string,
	key: string?,
	message: string,
	hint: string?,
}

export type Report = {
	mode: string,
	diagnostics: { Diagnostic },
	instances: number,
	depth: number,
	dynamics: number,
	checked: number,

	errors: (Report) -> { Diagnostic },
	warnings: (Report) -> { Diagnostic },
	hints: (Report) -> { Diagnostic },
	isOk: (Report) -> boolean,
	count: (Report) -> number,
	text: (Report) -> string,
	print: (Report) -> (),
	json: (Report) -> string,
	html: (Report) -> string,
}

const Lint = {}

const Report = {} :: { [string]: any }
Report.__type = "Kite.Report"
Report.__index = Report

--> ["walk"]
-- Walks the authored tree. The compiler gives you property problems; this
-- walk gives you shape and cost problems.

local function walk(node: any, path: string, depth: number, visit: (any, string, number) -> ())
	if node == nil or type(node) ~= "table" then
		return
	end

	visit(node, path, depth)

	const kind = (node :: any).kind

	if kind == "element" then
		const props = (node :: any).props or {}

		for key, value in props do
			if type(key) == "number" then
				walk(value, `{path}[{key}]`, depth + 1, visit)
			elseif type(value) == "table" and (value :: any).kind == nil then
				if (value :: any)[1] ~= nil then
					for index, child in value do
						walk(child, `{path}.{key}[{index}]`, depth + 1, visit)
					end
				end
			end
		end

		return
	end

	if kind == "keys" or kind == "indexes" then
		walk(node.source, path, depth, visit)
		return
	end

	if kind == "when" then
		walk(node.element, `{path}.then`, depth + 1, visit)
		walk(node.fallback, `{path}.else`, depth + 1, visit)
		return
	end

	if kind == "switch" then
		for case, element in (node.cases or {}) do
			walk(element, `{path}.{tostring(case)}`, depth + 1, visit)
		end
		walk(node.fallback, `{path}.default`, depth + 1, visit)
		return
	end

	if kind == "dynamic" then
		return
	end

	if kind == "portal" then
		walk(node.element, path, depth + 1, visit)
		return
	end

	if kind == "component" then
		walk(node.props, path, depth, visit)
		return
	end
end

--> ["checks"]

local function checkTree(node: any, path: string, depth: number, report: Report, out: { Diagnostic }, counts: { [string]: number })
	const kind = (node :: any).kind

	if kind ~= "element" then
		if kind == "keys" and (node :: any).keyOf == nil and (node :: any).byIndex ~= true then
			table.insert(out, {
				level = if report.mode == "strict" then "error" else "warn",
				code = "unkeyed",
				path = path,
				key = nil,
				message = "kite.keys has no key function, so rows are matched by value",
				hint = "pass a third argument: function(item) return item.id end",
			})
		end

		if kind == "keys" and (node :: any).source == nil then
			table.insert(out, {
				level = "error",
				code = "keysource",
				path = path,
				key = nil,
				message = "kite.keys needs a source that returns a table",
				hint = "kite.keys(function() return rows() end, render)",
			})
		end

		return
	end

	counts.instances += 1
	if depth > counts.depth then
		counts.depth = depth
	end

	const class = (node :: any).class
	const props = (node :: any).props or {}

	if type(class) ~= "string" then
		table.insert(out, {
			level = "error",
			code = "class",
			path = path,
			key = nil,
			message = "an element needs a class name string",
			hint = `kite.create "Frame" \{ ... \}`,
		})
		return
	end

	if not Types.known(class) then
		table.insert(out, {
			level = "hint",
			code = "unknownclass",
			path = path,
			key = nil,
			message = `Kite has never heard of "{class}"`,
			hint = `teach it once: kite.know("{class}", "Frame", ` .. [[{ YourProp = "string" })]],
		})
	end

	-- nameless instances are harder to debug later
	if props.Name == nil and report.mode ~= "performance" then
		table.insert(out, {
			level = "hint",
			code = "noname",
			path = path,
			key = "Name",
			message = `{class} has no Name`,
			hint = `Name = "{string.lower(class)}" makes the inspector readable`,
		})
	end

	-- respawn behaviour bites people once and they never forget it
	if class == "ScreenGui" and props.ResetOnSpawn == nil then
		table.insert(out, {
			level = "hint",
			code = "resetonspawn",
			path = path,
			key = "ResetOnSpawn",
			message = "ScreenGui does not say what happens on respawn",
			hint = "ResetOnSpawn = false keeps the UI alive across respawns",
		})
	end

	-- automatic size and a fixed size fight each other
	if props.AutomaticSize ~= nil and props.Size ~= nil then
		table.insert(out, {
			level = "hint",
			code = "autosize",
			path = path,
			key = "AutomaticSize",
			message = "AutomaticSize is set while Size is also set",
			hint = "const one axis stay zero: Size = UDim2.new(1, 0, 0, 0) with AutomaticSize = Enum.AutomaticSize.Y",
		})
	end

	if class == "ScrollingFrame" and props.CanvasSize == nil and props.AutomaticCanvasSize == nil then
		table.insert(out, {
			level = "warn",
			code = "canvas",
			path = path,
			key = "CanvasSize",
			message = "ScrollingFrame has no CanvasSize, so it will not scroll",
			hint = "CanvasSize = UDim2.new(0, 0, 0, 0) with AutomaticCanvasSize = Enum.AutomaticSize.Y",
		})
	end

	const dynamicCount = 0
	const animated = false

	for key, value in props do
		if type(key) == "string" and Compiler.callable(value) then
			dynamicCount += 1

			if (key == "Size" or key == "Position" or key == "Rotation") and report.mode == "performance" then
				table.insert(out, {
					level = "hint",
					code = "animatedlayout",
					path = path,
					key = key,
					message = `{key} changes reactively, which relayouts the subtree`,
					hint = "wrap it in kite.spring(...) so it settles, or animate Transparency and Color instead",
				})
			end
		end

		if key == "kite.spring" or (type(value) == "table" and (value :: any).kind == "motion") then
			animated = true
		end
	end

	counts.dynamics += dynamicCount

	if report.mode == "performance" and dynamicCount > 8 then
		table.insert(out, {
			level = "hint",
			code = "manydynamics",
			path = path,
			key = nil,
			message = `{dynamicCount} reactive properties sit on one {class}`,
			hint = "Kite runs one effect per instance, so they share a pass. Split the instance if only some of them change together.",
		})
	end

	if animated and report.mode == "strict" then
		table.insert(out, {
			level = "hint",
			code = "strictmotion",
			path = path,
			key = nil,
			message = "this tree holds a motion",
			hint = "motions start a frame driver. strict mode is for the shape of the tree, not for motion.",
		})
	end
end

--> ["inspect"]

function Lint.inspect(tree: any, mode: string?, options: { maxDepth: number?, maxInstances: number? }?): Report
	const wanted = mode or Config.mode
	const opts = options or {}

	const previous = Config.mode
	const previousCache = Config.cache

	Config.apply(wanted)
	-- never const a lint pass poison the plan cache: a plan compiled under
	-- strict has no sugar in it, and mounting it later would be wrong
	Config.cache = false

	const collected: { Diagnostic } = {}
	const counts = { instances = 0, depth = 0, dynamics = 0 }

	-- property level problems come out of the compiler without a path, so
	-- they get one here before they are mixed with the shape problems
	const fromCompiler: { any } = {}
	Compiler.plan(tree, fromCompiler)

	for _, problem in fromCompiler do
		table.insert(collected, {
			level = problem.level or "error",
			code = problem.code or "property",
			path = problem.path or "tree",
			key = problem.key,
			message = problem.message,
			hint = problem.hint,
		})
	end

	-- shape and cost problems come from the walk
	walk(tree, "tree", 1, function(node, path, depth)
		checkTree(node, path, depth, { mode = wanted } :: any, collected, counts)
	end)

	if counts.depth > (opts.maxDepth or 8) then
		table.insert(collected, {
			level = if wanted == "performance" then "warn" else "hint",
			code = "depth",
			path = "tree",
			key = nil,
			message = `the tree is {counts.depth} levels deep`,
			hint = "every level is another layout pass. flatten where you can.",
		})
	end

	if counts.instances > (opts.maxInstances or 160) then
		table.insert(collected, {
			level = if wanted == "performance" then "warn" else "hint",
			code = "size",
			path = "tree",
			key = nil,
			message = `the tree builds {counts.instances} instances`,
			hint = "lists that long belong in kite.keys with recycling, or behind kite.when",
		})
	end

	if wanted == "performance" and previousCache == false then
		table.insert(collected, {
			level = "warn",
			code = "nocache",
			path = "tree",
			key = nil,
			message = "the compile cache is off",
			hint = "kite.cache(true) lets Kite reuse a plan instead of walking the tree again",
		})
	end

	Config.apply(previous)
	Config.cache = previousCache

	const report = {
		mode = wanted,
		diagnostics = collected,
		instances = counts.instances,
		depth = counts.depth,
		dynamics = counts.dynamics,
		checked = counts.instances,
	}

	return setmetatable(report, Report) :: any
end

function Lint.strict(tree: any, options: any?): Report
	return Lint.inspect(tree, "strict", options)
end

function Lint.creative(tree: any, options: any?): Report
	return Lint.inspect(tree, "creative", options)
end

function Lint.performance(tree: any, options: any?): Report
	return Lint.inspect(tree, "performance", options)
end

--> ["report"]

const LEVEL_ORDER = { error = 1, warn = 2, hint = 3 }

function Report.errors(self: Report): { Diagnostic }
	const out = {}
	for _, item in self.diagnostics do
		if item.level == "error" then
			table.insert(out, item)
		end
	end
	return out
end

function Report.warnings(self: Report): { Diagnostic }
	const out = {}
	for _, item in self.diagnostics do
		if item.level == "warn" then
			table.insert(out, item)
		end
	end
	return out
end

function Report.hints(self: Report): { Diagnostic }
	const out = {}
	for _, item in self.diagnostics do
		if item.level == "hint" then
			table.insert(out, item)
		end
	end
	return out
end

function Report.isOk(self: Report): boolean
	return #self:errors() == 0
end

function Report.count(self: Report): number
	return #self.diagnostics
end

function Report.text(self: Report): string
	const lines = {}

	const errors = self:errors()
	const warnings = self:warnings()
	const hints = self:hints()

	table.insert(lines, `Kite lint : {self.mode} : {#errors} error(s), {#warnings} warning(s), {#hints} hint(s)`)
	table.insert(lines, `  tree builds {self.instances} instance(s), {self.dynamics} reactive propert(y|ies), {self.depth} level(s) deep`)
	table.insert(lines, "")

	const sorted = table.clone(self.diagnostics)
	table.sort(sorted, function(left, right)
		const leftLevel = LEVEL_ORDER[left.level] or 4
		const rightLevel = LEVEL_ORDER[right.level] or 4
		if leftLevel == rightLevel then
			return left.path < right.path
		end
		return leftLevel < rightLevel
	end)

	for _, item in sorted do
		table.insert(lines, `  {Util.pad(item.level, 5)} {item.code}  {item.path}{if item.key then `.{item.key}` else ""}`)
		table.insert(lines, `        {item.message}`)
		if item.hint then
			table.insert(lines, `        -> {item.hint}`)
		end
	end

	if #sorted == 0 then
		table.insert(lines, "  clean.")
	end

	return table.concat(lines, "\n")
end

function Report.print(self: Report)
	print(self:text())
end

function Report.json(self: Report): string
	const parts = {}

	for _, item in self.diagnostics do
		const entry = string.format(
			'    { "level": "%s", "code": "%s", "path": "%s", "message": "%s"',
			item.level,
			item.code,
			item.path,
			item.message
		)

		if item.hint then
			entry ..= string.format(', "hint": "%s"', item.hint)
		end

		table.insert(parts, entry .. " }")
	end

	return table.concat({
		"{",
		string.format('  "mode": "%s",', self.mode),
		string.format('  "instances": %d,', self.instances),
		string.format('  "dynamics": %d,', self.dynamics),
		string.format('  "depth": %d,', self.depth),
		'  "diagnostics": [',
		table.concat(parts, ",\n"),
		"  ]",
		"}",
	}, "\n")
end

local function esc(text: string): string
	return text
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub('"', "&quot;")
end

function Report.html(self: Report): string
	const rows = {}

	const sorted = table.clone(self.diagnostics)
	table.sort(sorted, function(left, right)
		return (LEVEL_ORDER[left.level] or 4) < (LEVEL_ORDER[right.level] or 4)
	end)

	for _, item in sorted do
		table.insert(rows, string.format(
			[[      <tr class="%s">
        <td class="level">%s</td>
        <td class="code">%s</td>
        <td class="path">%s</td>
        <td class="message">%s%s</td>
      </tr>]],
			item.level,
			item.level,
			esc(item.code),
			esc(item.path .. (if item.key then `.{item.key}` else "")),
			esc(item.message),
			if item.hint then `<div class="hint">${esc(item.hint)}</div>` else ""
		))
	end

	return string.format(
		[[<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Kite lint : %s</title>
<style>
  body { background: #0d181b; color: #eeeeee; font: 13px/1.5 ui-monospace, monospace; margin: 24px; }
  h1 { font-size: 15px; color: #3ddad7; letter-spacing: .12em; text-transform: uppercase; }
  .meta { color: #7f9ba1; margin-bottom: 18px; }
  table { border-collapse: collapse; width: 100%%; }
  td { padding: 7px 10px; border-bottom: 1px solid #1d3339; vertical-align: top; }
  .level { width: 58px; text-transform: uppercase; font-size: 11px; letter-spacing: .1em; }
  .error .level { color: #f76b6e; }
  .warn .level { color: #e8b736; }
  .hint .level { color: #56a6e4; }
  .code { width: 130px; color: #7f9ba1; }
  .path { width: 260px; color: #4d6a6e; }
  .hint { color: #6fdca0; margin-top: 3px; }
  .clean { color: #6fdca0; }
</style>
</head>
<body>
  <h1>Kite lint &middot; %s</h1>
  <div class="meta">%d instance(s) &middot; %d reactive propert(y|ies) &middot; %d level(s) deep &middot; %d problem(s)</div>
  <table>
%s
  </table>
</body>
</html>]],
		self.mode,
		self.mode,
		self.instances,
		self.dynamics,
		self.depth,
		#self.diagnostics,
		if #rows > 0 then table.concat(rows, "\n") else `      <tr><td class="clean">clean</td><td></td><td></td><td></td></tr>`
	)
end

Report.__tostring = Report.text

return Lint
