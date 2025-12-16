---那天她说想吃巧克力
---
---design choices, features, limits
---* keyword/fixedstr only, with boundary
---* finite number of colors
---* match scope: incremental
---* per-buffer state
---* highlights showing in all windows
---  * extmark vs matchadd*
---* no jump support. use a motion plugin instead
---* no auto-update/delete. highlights may become inaccurate while buffer changes.
---  * nvim_buf_attach+nvim_set_decoration_provider make the impl complex

local M = {}

local bags = require("infra.bags")
local buflines = require("infra.buflines")
local dictlib = require("infra.dictlib")
local jelly = require("infra.jellyfish")("chocolate.dove", "info")
local ni = require("infra.ni")
local nuts = require("infra.nuts")
local vsel = require("infra.vsel")

local facts = require("chocolate.facts")
local find_stop_node = require("chocolate.find_stop_node")
local Palette = require("chocolate.Palette")
local Regex = require("chocolate.Regex")
local puff = require("puff")

---@param bufnr integer
---@param ns integer
---@param higroup string
---@param lnum integer
---@param start integer start_col
---@param stop integer stop_col
---@return integer xmid
local function hi_occurence(bufnr, ns, higroup, lnum, start, stop) --
  return ni.buf_set_extmark(bufnr, ns, lnum, start, { --
    end_row = lnum,
    end_col = stop,
    hl_group = higroup,
    invalidate = true,
    undo_restore = true,
    hl_mode = "replace",
  })
end

---@class chocolate.dove.Bag
---@field palette chocolate.Palette
---@field ns    table<string,integer> {keyword:namespace}
---@field color table<string,integer> {keyword:color}
---@field ng    table<string,integer> {keyword:generation}

local Bag = bags.wraps("chocolate.dove", function() end)

---@param bufnr integer
---@param keyword? string
local function clear(bufnr, keyword)
  ---@type chocolate.dove.Bag?
  local bag = Bag.get(bufnr)
  if bag == nil then return end
  if keyword == nil then
    for _, ns in pairs(bag.ns) do
      ni.buf_clear_namespace(bufnr, ns, 0, -1)
    end
    bag.palette:reset()
    bag.ns = {}
    bag.color = {}
    bag.ng = {}
  else
    if bag.ns[keyword] == nil then return end
    ni.buf_clear_namespace(bufnr, bag.ns[keyword], 0, -1)
    bag.palette:free(bag.color[keyword])
    bag.ns[keyword] = nil
    bag.color[keyword] = nil
    bag.ng[keyword] = nil
  end
end

local function highlight(winid, keyword)
  local bufnr = ni.win_get_buf(winid)
  ---@type chocolate.dove.Bag
  local bag = Bag.get(bufnr) or Bag.new(bufnr, { palette = Palette(), ns = {}, color = {}, ng = {} })

  if bag.ns[keyword] == nil then
    local color = bag.palette:allocate()
    if color == nil then return jelly.info("ran out of color") end

    bag.ns[keyword] = ni.create_namespace(string.format("chocolate.snicker.%s.%s", bufnr, keyword))
    bag.color[keyword] = color
    bag.ng[keyword] = 0
  end

  --clear prev set xmarks
  ni.buf_clear_namespace(bufnr, assert(bag.ns[keyword]), 0, -1)

  local bound_low, bound_high --both are 0-based and inclusive
  do
    local ng = assert(bag.ng[keyword]) + 1
    local node = find_stop_node(winid, ng)
    if node == nil then
      bound_low, bound_high = 0, buflines.high(bufnr)
    else
      local start, _, stop = nuts.node_range(node)
      bound_low, bound_high = start, stop
    end

    if node then bag.ng[keyword] = ng end
  end

  do --highlight all occurences at first time
    local poses = {}
    local regex = Regex(keyword)
    for lnum = bound_low, bound_high do
      for start, stop in regex:iter_line(bufnr, lnum) do
        table.insert(poses, { lnum, start, stop })
      end
    end
    if #poses < 2 then return jelly.info("aborted. too few matches") end

    local higroup = assert(facts.higroups[bag.color[keyword]])
    local ns = bag.ns[keyword]
    for _, pos in ipairs(poses) do
      hi_occurence(bufnr, ns, higroup, unpack(pos))
    end
  end
end

function M.vsel()
  local winid = ni.get_current_win()
  local bufnr = ni.win_get_buf(winid)
  local keyword = vsel.oneline_text(bufnr)
  if keyword == nil then return jelly.info("no selected text") end
  highlight(winid, keyword)
end

function M.cword()
  local winid = ni.get_current_win()
  local keyword = vim.fn.expand("<cword>")
  if keyword == "" then return jelly.info("no cursor word") end
  highlight(winid, keyword)
end

function M.clear()
  local bufnr = ni.get_current_buf()
  ---@type chocolate.dove.Bag?
  local bag = Bag.get(bufnr)
  if bag == nil then return jelly.info("no highlights") end
  do --try cword first
    local keyword = vim.fn.expand("<cword>")
    if bag.ns[keyword] then return clear(bufnr, keyword) end
  end
  --
  --try vsel no more. it requires too much logic and beats the convinence it brings.
  --
  do --let user decide
    local keywords = dictlib.keys(bag.ns)
    if #keywords == 0 then return jelly.info("no highlights") end
    if #keywords == 1 then return clear(bufnr, keywords[1]) end
    table.insert(keywords, 1, "[all]")
    puff.select(keywords, { prompt = "🍫" }, function(entry, index) --
      if index == nil then return end
      local keyword = index > 1 and entry or nil
      clear(bufnr, keyword)
    end)
  end
end

return M
