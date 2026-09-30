--!strict
--[=[
	--> ["Kite : Tests : Globals"]

	The Luau CLI gives every required module its own globals table, which
	Roblox does not, so a spec cannot just reach for `Instance.new`.

	Each spec pulls what it needs out of here instead:

	```lua
	local G = require("./Globals")
	local Instance, UDim2 = G.Instance, G.UDim2
	```
]=]

local Stub = require("./Stub")

return Stub.exports()
