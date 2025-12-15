local new_table = require("table.new")

local facts = require("chocolate.facts")

---@class chocolate.Palette
---@field colors table<integer, true>
local Palette = {}
Palette.__index = Palette

---@return integer? color
function Palette:allocate()
  local color, _ = next(self.colors)
  if color == nil then return end
  self.colors[color] = nil
  return color
end

---@param color integer
function Palette:free(color)
  assert(not self.colors[color])
  self.colors[color] = true
end

function Palette:reset()
  for i = 1, #facts.palette do
    self.colors[i] = true
  end
end

return function()
  --todo: remove the facts dependency
  local palette = setmetatable({ colors = new_table(0, #facts.palette) }, Palette)
  palette:reset()
  return palette
end
