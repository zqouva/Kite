--[=[
	--> ["Kite : Tests : analyze preamble"]

	Prepended to every file before `luau-analyze` reads it, so the analyzer
	knows what Roblox is.

	Two halves:

	- `type X = any` makes Roblox *types* resolvable
	- `X = nil :: any` makes Roblox *globals* known

	Files are analyzed one at a time on purpose. The analyzer would
	otherwise follow `require` across the package and drag one file's
	Roblox types into another file's scope, which is where the noise came
	from. One run per file keeps the signal.

	This file is never required. It exists only for the analyzer.
]=]

type Instance = any
type UDim = any
type UDim2 = any
type Vector2 = any
type Vector3 = any
type Color3 = any
type CFrame = any
type Rect = any
type ColorSequence = any
type ColorSequenceKeypoint = any
type NumberSequence = any
type NumberSequenceKeypoint = any
type Font = any
type BrickColor = any
type TweenInfo = any
type RaycastParams = any
type OverlapParams = any
type EnumItem = any
type RBXScriptSignal = any
type RBXScriptConnection = any
type Axes = any
type Faces = any
type Region3 = any
type Random = any
type DateTime = any
type NumberRange = any
type PhysicalProperties = any

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
BrickColor = nil :: any
TweenInfo = nil :: any
RaycastParams = nil :: any
Enum = nil :: any
EnumItem = nil :: any
game = nil :: any
workspace = nil :: any
task = nil :: any
script = nil :: any
plugin = nil :: any
warn = nil :: any
