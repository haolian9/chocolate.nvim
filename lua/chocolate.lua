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

local M = {}

local ropes = require("string.buffer")
local new_table = require("table.new")

local buflines = require("infra.buflines")
local dictlib = require("infra.dictlib")
local highlighter = require("infra.highlighter")
local jelly = require("infra.jellyfish")("chocolate", "info")
local ni = require("infra.ni")
local nuts = require("infra.nuts")
local prefer = require("infra.prefer")
local VimRegex = require("infra.VimRegex")
local vsel = require("infra.vsel")

local puff = require("puff")

local facts = {}
do
  facts.palette = {
    { 203, 88 }, -- 赤：珊瑚红 + 深酒红 - 现代红系
    { 214, 94 }, -- 橙：琥珀橙 + 深紫红 - 活力橙系
    { 226, 100 }, -- 黄：亮黄色 + 深紫灰 - 醒目黄系
    { 85, 28 }, -- 绿：青绿色 + 深橄榄绿 - 自然绿系
    { 81, 24 }, -- 青：亮青色 + 深海蓝绿 - 科技青系
    { 39, 19 }, -- 蓝：天蓝色 + 深海蓝 - 冷静蓝系
    { 141, 55 }, -- 紫：薰衣草紫 + 深褐紫 - 优雅紫系
  }

  facts.xmark_ns = ni.create_namespace("chocolate.xmarks")

  facts.higroups = {}
  local hi = highlighter(0)
  for i, pair in ipairs(facts.palette) do
    local hig = "Chocolate." .. i
    hi(hig, { fg = pair[2], bg = pair[1] })
    facts.higroups[i] = hig
  end

  facts.ftstops = {
    lua = { function_declaration = true, function_definition = true, do_statement = true, chunk = true },
    python = { function_definition = true },
    zig = { function_declaration = true, struct_declaration = true, test_declaration = true },
    c = { function_definition = true },
    go = { function_declaration = true, function_literal = true },
  }
end

local Palette
do
  ---@class chocolate.Palette
  ---@field colors table<integer, true>
  local Impl = {}
  Impl.__index = Impl

  ---@return integer? color
  function Impl:allocate()
    local color, _ = next(self.colors)
    if color == nil then return end
    self.colors[color] = nil
    return color
  end

  ---@param color integer
  function Impl:free(color)
    assert(not self.colors[color])
    self.colors[color] = true
  end

  function Impl:reset()
    for i = 1, #facts.palette do
      self.colors[i] = true
    end
  end

  function Palette()
    local palette = setmetatable({ colors = new_table(0, #facts.palette) }, Impl)
    palette:reset()
    return palette
  end
end

---@param winid integer
---@param ng integer
---@return TSNode?
local function find_stop_node(winid, ng)
  local bufnr = ni.win_get_buf(winid)
  local stops = facts.ftstops[prefer.bo(bufnr, "filetype")]
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

local create_regex
do
  local rope = ropes.new(64)

  ---@param keyword string
  ---@return infra.VimRegex
  function create_regex(keyword)
    rope:put([[\V]])
    if string.find(keyword, "^%a") then rope:put([[\<]]) end
    rope:put(VimRegex.escape_for_verynomagic(keyword))
    if string.find(keyword, "%a$") then rope:put([[\>]]) end
    return VimRegex(rope:get())
  end
end

---@class chocolate.Matches
---@field color  integer
---@field ng     integer @number of generations
---@field xmarks integer[]

---{bufnr:{palette,{keyword:matches}}}
---@type table<integer, {palette:chocolate.Palette,matches:table<string,chocolate.Matches>}>
local states = {}

---@param bufnr integer
---@param keyword? string
local function clear_highlights(bufnr, keyword)
  local state = states[bufnr]
  if state == nil then return end
  if keyword == nil then
    ni.buf_clear_namespace(bufnr, facts.xmark_ns, 0, -1)
    state.palette:reset()
    state.matches = {}
  else
    local matches = assert(state.matches[keyword])
    state.palette:free(matches.color)
    for _, xmid in ipairs(matches.xmarks) do
      ni.buf_del_extmark(bufnr, facts.xmark_ns, xmid)
    end
    state.matches[keyword] = nil
  end
end

local function highlight(winid, keyword)
  local bufnr = ni.win_get_buf(winid)
  local state = states[bufnr]
  if state == nil then
    state = { palette = Palette(), matches = {} }
    states[bufnr] = state
  end

  local ng = 0
  if state.matches[keyword] then
    --todo: reuse color
    ng = state.matches[keyword].ng
    clear_highlights(bufnr, keyword)
  end

  local color = state.palette:allocate()
  if color == nil then return jelly.info("ran out of color") end

  assert(color) --only if there is an available color
  ng = ng + 1

  local range_begin, range_end --both are 0-based and inclusive
  do
    local node = find_stop_node(winid, ng)
    if node == nil then
      range_begin, range_end = 0, buflines.high(bufnr)
    else
      local start, _, stop = nuts.node_range(node)
      jelly.info("%d ancesor generations, %s, (%s,%s)", ng, node:type(), start, stop)
      range_begin, range_end = start, stop
    end
  end

  local poses = {}
  local regex = create_regex(keyword)
  for lnum = range_begin, range_end do
    for start_col, stop_col in regex:iter_line(bufnr, lnum) do
      table.insert(poses, { lnum = lnum, start_col = start_col, stop_col = stop_col })
    end
  end
  if #poses < 2 then
    state.matches[keyword] = { color = color, ng = ng, xmarks = {} }
    return jelly.info("less than 2 matches")
  end

  local xmarks = {}
  local higroup = assert(facts.higroups[color])
  for i, mat in ipairs(poses) do
    xmarks[i] = ni.buf_set_extmark(bufnr, facts.xmark_ns, mat.lnum, mat.start_col, {
      end_row = mat.lnum,
      end_col = mat.stop_col,
      hl_group = higroup,
      invalidate = true,
      undo_restore = true,
      --todo: update/delete on buffer changing
    })
  end
  state.matches[keyword] = { color = color, ng = ng, xmarks = xmarks }
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
  local state = states[bufnr]
  if state == nil then return jelly.info("no highlights") end
  do --try cword first
    local keyword = vim.fn.expand("<cword>")
    if state.matches[keyword] then return clear_highlights(bufnr, keyword) end
  end
  do --try vsel then
    local keyword = vsel.oneline_text(bufnr)
    if state.matches[keyword] then return clear_highlights(bufnr, keyword) end
  end
  do --let use decide
    local keywords = dictlib.keys(state.matches)
    if #keywords == 0 then return jelly.info("no highlights") end
    if #keywords == 1 then return clear_highlights(bufnr, keywords[1]) end
    table.insert(keywords, 1, "[all]")
    puff.select(keywords, { prompt = "🍫" }, function(entry, index) --
      if index == nil then return end
      local keyword = index > 1 and entry or nil
      clear_highlights(bufnr, keyword)
    end)
  end
end

return M
