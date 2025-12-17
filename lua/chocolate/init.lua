local M = {}

local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("chocolate", "info")
local vsel = require("infra.vsel")

local puff = require("puff")

---@class chocolate.Flavor
---@field bag fun(bufnr:integer):{ns:table<string,integer>}?
---@field highlight fun(winid:integer,keyword:string?)
---@field clear fun(bufnr:integer,keyword:string?)

---@param flavor chocolate.Flavor
local function API(flavor)
  local api = {}

  function api.vsel()
    local winid = ni.get_current_win()
    local bufnr = ni.win_get_buf(winid)
    local keyword = vsel.oneline_text(bufnr)
    if keyword == nil then return jelly.info("no selected text") end
    flavor.highlight(winid, keyword)
  end

  function api.cword()
    local winid = ni.get_current_win()
    local keyword = vim.fn.expand("<cword>")
    if keyword == "" then return jelly.info("no cursor word") end
    flavor.highlight(winid, keyword)
  end

  function api.clear()
    local bufnr = ni.get_current_buf()
    local bag = flavor.bag(bufnr)
    if bag == nil then return jelly.info("no highlights") end
    do --try cword first
      local keyword = vim.fn.expand("<cword>")
      if bag.ns[keyword] then return flavor.clear(bufnr, keyword) end
    end
    --
    --try vsel no more. it requires too much logic and beats the convinence it brings.
    --
    do --let user decide
      local keywords = dictlib.keys(bag.ns)
      if #keywords == 0 then return jelly.info("no highlights") end
      if #keywords == 1 then return flavor.clear(bufnr, keywords[1]) end
      table.insert(keywords, 1, "[all]")
      puff.select(keywords, { prompt = "🍫" }, function(entry, index) --
        if index == nil then return end
        local keyword = index > 1 and entry or nil
        flavor.clear(bufnr, keyword)
      end)
    end
  end

  return api
end

M.dove = API(require("chocolate.dove"))

M.snicker = API(require("chocolate.snicker"))

return M

