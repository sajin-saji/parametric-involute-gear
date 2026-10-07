-- Minimal stand-in for the IceSL API so the gear script can run headless in plain Lua (CI).
-- Geometry calls return simple tables; only the 2D/3D vector maths is real.

local V = {}
V.__index = V
function v(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V) end
local function lift(s) return type(s) == "number" and v(s, s, s) or s end
V.__add = function(a, b) a, b = lift(a), lift(b); return v(a.x + b.x, a.y + b.y, a.z + b.z) end
V.__sub = function(a, b) a, b = lift(a), lift(b); return v(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__mul = function(a, b)
  if type(a) == "number" then a, b = b, a end
  if type(b) == "number" then return v(a.x * b, a.y * b, a.z * b) end
  return v(a.x * b.x, a.y * b.y, a.z * b.z)
end
V.__div = function(a, b) return v(a.x / b, a.y / b, a.z / b) end

-- Tweak-box widgets return their default value
function ui_numberBox(_, default) return default end
function ui_scalarBox(_, default) return default end
function ui_scalar(_, default) return default end

-- Shapes and transforms: tag tables; "*" on a transform applies it to a shape
local Shape = {}
Shape.__index = Shape
Shape.__mul = function(t, s) return setmetatable({ kind = "transformed", t = t, child = s }, Shape) end
local function shape(kind, args) return setmetatable({ kind = kind, args = args }, Shape) end

function polyhedron(vertices, triangles) return shape("polyhedron", { vertices = vertices, triangles = triangles }) end
function cylinder(...) return shape("cylinder", { ... }) end
function ccylinder(...) return shape("ccylinder", { ... }) end
function cube(...) return shape("cube", { ... }) end
function difference(...) return shape("difference", { ... }) end
function union(...) return shape("union", { ... }) end
function translate(...) return shape("translate", { ... }) end
function rotate(...) return shape("rotate", { ... }) end

EMITTED = {}
function emit(s, brush) EMITTED[#EMITTED + 1] = { shape = s, brush = brush } end
