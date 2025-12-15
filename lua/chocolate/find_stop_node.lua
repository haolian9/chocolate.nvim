local ni = require("infra.ni")
local nuts = require("infra.nuts")
local prefer = require("infra.prefer")

local ftstops = {
  lua = { function_declaration = true, function_definition = true, do_statement = true, chunk = true },
  python = { function_definition = true },
  zig = { function_declaration = true, struct_declaration = true, test_declaration = true },
  c = { function_definition = true },
  go = { function_declaration = true, function_literal = true },
}

---@param winid integer
---@param ng integer
---@return TSNode?
return function(winid, ng)
  local bufnr = ni.win_get_buf(winid)
  local stops = ftstops[prefer.bo(bufnr, "filetype")]
  if stops == nil then return end
  ---@type TSNode?
  local node = nuts.node_at_cursor(winid)
  while node ~= nil do
    if stops[node:type()] then
      ng = ng - 1
      if ng <= 0 then return node end
    end
    node = node:parent()
  end
end

