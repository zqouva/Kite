--!strict
--[=[
	--> ["Kite : Inspector"]

	Looks at what Kite built, after it was built.

	```lua
	const view = kite.inspector(handle.instance)

	print(view:tree())
	print(view:html())
	print(view:graph(count))   -- the reactive graph behind a source
	```

	--> ["why"]
	Most UI debugging is guessing which instance ended up where. This
	prints the truth, and the html version stands alone in a browser with
	no dependencies.
]=]

const Util = require(script.Parent.Util)

const Inspector = {}

const INTERESTING = table.freeze({
	"Name",
	"ClassName",
	"Size",
	"Position",
	"AnchorPoint",
	"BackgroundColor3",
	"BackgroundTransparency",
	"Text",
	"TextColor3",
	"TextSize",
	"TextTransparency",
	"Image",
	"ImageTransparency",
	"Visible",
	"LayoutOrder",
	"ZIndex",
	"AutomaticSize",
	"CornerRadius",
	"Thickness",
	"Color",
	"PaddingTop",
	"PaddingLeft",
	"Scale",
})

local function color(value: any): string
	if typeof(value) == "Color3" then
		return string.format("#%02x%02x%02x", math.round(value.R * 255), math.round(value.G * 255), math.round(value.B * 255))
	end
	return tostring(value)
end

local function readable(instance: Instance, key: string): string?
	const ok, value = pcall(function()
		return (instance :: any)[key]
	end)

	if not ok or value == nil then
		return nil
	end

	const kind = Util.kindOf(value)

	if kind == "Color3" then
		return color(value)
	end

	if kind == "number" then
		return string.format("%.3f", value)
	end

	if kind == "UDim2" then
		return `{value.X.Scale} {value.X.Offset} {value.Y.Scale} {value.Y.Offset}`
	end

	if kind == "UDim" then
		return `{value.Scale} {value.Offset}`
	end

	if kind == "Vector2" then
		return `{value.X} {value.Y}`
	end

	if kind == "EnumItem" then
		return value.Name
	end

	if kind == "Instance" then
		return value.Name
	end

	if type(value) == "string" then
		return value
	end

	if type(value) == "boolean" then
		return tostring(value)
	end

	return kind
end

--> ["tree"]

local function walkTree(instance: Instance, depth: number, out: { string }, counts: { instances: number, depth: number })
	counts.instances += 1
	if depth > counts.depth then
		counts.depth = depth
	end

	const pad = string.rep("  ", depth)
	const extra = {}

	for _, key in INTERESTING do
		if key == "Name" or key == "ClassName" then
			continue
		end

		const value = readable(instance, key)

		if value and value ~= "" and value ~= "0.000" then
			table.insert(extra, `{key}={value}`)
			if #extra >= 3 then
				break
			end
		end
	end

	const label = instance.Name
	if label == instance.ClassName then
		label = instance.ClassName
	end

	table.insert(out, `{pad}{instance.ClassName} "{label}"{if #extra > 0 then `  {table.concat(extra, " ")}` else ""}`)

	const children = instance:GetChildren()
	for index = 1, #children do
		walkTree(children[index], depth + 1, out, counts)
	end
end

function Inspector.tree(instance: Instance): string
	const out = {}
	const counts = { instances = 0, depth = 0 }

	walkTree(instance, 0, out, counts)

	table.insert(out, "")
	table.insert(out, `{counts.instances} instance(s), {counts.depth} level(s) deep`)

	return table.concat(out, "\n")
end

function Inspector.html(instance: Instance): string
	const rows = {}
	const counts = { instances = 0, depth = 0 }

	local function walk(node: Instance, depth: number)
		counts.instances += 1
		if depth > counts.depth then
			counts.depth = depth
		end

		const props = {}

		for _, key in INTERESTING do
			if key == "Name" or key == "ClassName" then
				continue
			end

			const value = readable(node, key)
			if value and value ~= "" then
				table.insert(props, string.format(
					[[<span class="p"><b>%s</b>%s</span>]],
					key,
					`<i>${({ Color = 1, BackgroundColor3 = 1, TextColor3 = 1 }) [key] and string.format(
						[[<s style="background:%s"></s>]],
						color((node :: any)[key])
					) or ""}</i>`
				))
			end
		end

		table.insert(rows, string.format(
			[[      <div class="node" style="margin-left:%dpx">
        <span class="class">%s</span> <span class="name">%s</span>
        <div class="props">%s</div>
      </div>]],
			depth * 16,
			node.ClassName,
			node.Name,
			table.concat(props, "")
		))

		for _, child in node:GetChildren() do
			walk(child, depth + 1)
		end
	end

	walk(instance, 0)

	return string.format(
		[[<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Kite inspector</title>
<style>
  body { background: #0d181b; color: #eeeeee; font: 13px/1.5 ui-monospace, monospace; margin: 24px; }
  h1 { font-size: 15px; color: #3ddad7; letter-spacing: .12em; text-transform: uppercase; }
  .meta { color: #7f9ba1; margin-bottom: 18px; }
  .node { border-left: 1px solid #2e5053; padding: 4px 10px; }
  .class { color: #3ddad7; }
  .name { color: #7f9ba1; }
  .props { color: #4d6a6e; font-size: 11px; }
  .p { margin-right: 12px; }
  b { color: #4d6a6e; font-weight: 400; }
  i { font-style: normal; color: #eeeeee; }
  s { display: inline-block; width: 8px; height: 8px; border-radius: 2px; margin: 0 4px; text-decoration: none; }
</style>
</head>
<body>
  <h1>Kite inspector</h1>
  <div class="meta">%d instance(s) &middot; %d level(s) deep</div>
%s
</body>
</html>]],
		counts.instances,
		counts.depth,
		table.concat(rows, "\n")
	)
end

--> ["graph"]
-- Walks the reactive graph behind a node, in both directions.

function Inspector.graph(node: any, direction: string?): string
	const Graph = require(script.Parent.Graph) :: any

	if not Graph.isNode(node) then
		return "that is not a Kite node"
	end

	const dir = direction or "both"
	const lines = {}
	const seen = {}
	const depthLimit = 12

	local function labelOf(target: any): string
		const kind = target.kind
		const name = target.name
		return `{kind}{if name then ` "{name}"` else ""} {Util.show(target.value)}`
	end

	local function walk(target: any, depth: number, prefix: string)
		if depth > depthLimit then
			table.insert(lines, `{prefix}...`)
			return
		end

		if seen[target] then
			table.insert(lines, `{prefix}{labelOf(target)} (seen)`)
			return
		end

		seen[target] = true
		table.insert(lines, `{prefix}{labelOf(target)}`)

		if dir ~= "subs" then
			for dep in target.deps do
				walk(dep, depth + 1, `{prefix}  <- `)
			end
		end

		if dir ~= "deps" then
			for sub in target.subs do
				walk(sub, depth + 1, `{prefix}  -> `)
			end
		end
	end

	walk(node, 0, "")

	return table.concat(lines, "\n")
end

function Inspector.dot(node: any): string
	const lines = { "digraph Kite {", "  rankdir=LR;", "  node [shape=box, style=rounded, fontname=\"monospace\"];" }
	const seen = {}

	local function id(target: any): string
		if not seen[target] then
			seen[target] = `n{Util.count(seen) + 1}`
		end
		return seen[target]
	end

	local function name(target: any): string
		return `{target.kind}{if target.name then `\n{target.name}` else ""}`
	end

	const stack = { node }

	while #stack > 0 do
		const current = table.remove(stack)

		table.insert(lines, `  {id(current)} [label="{name(current)}"];`)

		for dep in current.deps do
			table.insert(lines, `  {id(dep)} -> {id(current)};`)
			if not seen[dep] then
				table.insert(stack, dep)
			end
		end
	end

	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

--> ["dump"]

function Inspector.dump(instance: Instance): string
	const lines = { `{instance.ClassName} "{instance.Name}"`, "" }

	for _, key in INTERESTING do
		if key == "ClassName" then
			continue
		end

		const value = readable(instance, key)
		if value then
			table.insert(lines, `  {Util.pad(key, 24)}{value}`)
		end
	end

	const attributes = instance:GetAttributes()
	if Util.count(attributes) > 0 then
		table.insert(lines, "")
		table.insert(lines, "  attributes")
		for key, value in Util.sorted(Util.keys(attributes)) do
			table.insert(lines, `    {Util.pad(tostring(key), 22)}{Util.show((attributes :: any)[value])}`)
		end
	end

	return table.concat(lines, "\n")
end

--> ["view"]

function Inspector.of(instance: Instance): any
	return setmetatable({
		instance = instance,
		tree = function(self: any)
			return Inspector.tree(self.instance)
		end,
		html = function(self: any)
			return Inspector.html(self.instance)
		end,
		dump = function(self: any)
			return Inspector.dump(self.instance)
		end,
		graph = function(_self: any, node: any, direction: string?)
			return Inspector.graph(node, direction)
		end,
		dot = function(_self: any, node: any)
			return Inspector.dot(node)
		end,
		print = function(self: any)
			print(self:tree())
		end,
	}, {
		__type = "Kite.Inspector",
		__tostring = function(self: any)
			return self:tree()
		end,
	})
end

return Inspector
