--!nonstrict
--[=[
	--> ["Kite : Tests : definitions"]

	Roblox globals, assigned as `any`, so `luau-analyze` can type check the
	package outside Studio without Roblox's own type environment.

	This file is never required at runtime. It exists so the analyzer knows
	that `Instance`, `UDim2`, and `game` are things Kite is allowed to use.
]=]

Instance = nil :: any
UDim = nil :: any
UDim2 = nil :: any
Vector2 = nil :: any
Vector3 = nil :: any
Color3 = nil :: any
CFrame = nil :: any
Rect = nil :: any
ColorSequence = nil :: any
ColorSequenceKeypoint = nil :: any
NumberSequence = nil :: any
NumberSequenceKeypoint = nil :: any
Font = nil :: any
Enum = nil :: any
BrickColor = nil :: any
TweenInfo = nil :: any
RaycastParams = nil :: any
Axes = nil :: any
Faces = nil :: any
Region3 = nil :: any
Random = nil :: any
DateTime = nil :: any
game = nil :: any
workspace = nil :: any
task = nil :: any
script = nil :: any
plugin = nil :: any
shared = nil :: any
_G = nil :: any

return nil
