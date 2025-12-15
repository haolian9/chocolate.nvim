local ropes = require("string.buffer")

local VimRegex = require("infra.VimRegex")

local rope = ropes.new(64)

---@param keyword string
---@return infra.VimRegex
return function(keyword)
  rope:put([[\V]])
  if string.find(keyword, "^%a") then rope:put([[\<]]) end
  rope:put(VimRegex.escape_for_verynomagic(keyword))
  if string.find(keyword, "%a$") then rope:put([[\>]]) end
  return VimRegex(rope:get())
end
