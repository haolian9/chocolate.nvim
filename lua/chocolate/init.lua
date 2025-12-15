---@class Chocolate
---@field vsel fun()
---@field cword fun()
---@field clear fun()

---@param flavor 'dove'|'snicker'
---@return Chocolate
return function(flavor) return require(string.format("chocolate.%s", flavor)) end
