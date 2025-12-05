---那天她说想吃巧克力
---
---design choices, features, limits
---* keyword/fixedstr only, with boundary
---* finite number of colors
---* match scope: function or global
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
local jelly = require("infra.jellyfish")("chocolate", "debug")
local ni = require("infra.ni")
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
---@field xmarks integer[]

---{bufnr:{palette,{keyword:matches}}}
---@type table<integer, {palette:chocolate.Palette,matches:table<string,chocolate.Matches>}>
local states = {}

local function highlight(bufnr, keyword)
  local state = states[bufnr]
  if state == nil then
    state = { palette = Palette(), matches = {} }
    states[bufnr] = state
  end

  if state.matches[keyword] then return jelly.info("highlighted already") end

  local regex = create_regex(keyword)

  local color = state.palette:allocate()
  if color == nil then return jelly.info("ran out of color") end
  local higroup = assert(facts.higroups[color])

  local matches = {}
  --todo: within function
  for lnum = 0, buflines.high(bufnr) do
    for start_col, stop_col in regex:iter_line(bufnr, lnum) do
      table.insert(matches, { lnum = lnum, start_col = start_col, stop_col = stop_col })
    end
  end
  if #matches < 2 then return jelly.info("less than 2 matches") end

  local xmarks = {}
  for i, mat in ipairs(matches) do
    xmarks[i] = ni.buf_set_extmark(bufnr, facts.xmark_ns, mat.lnum, mat.start_col, {
      end_row = mat.lnum,
      end_col = mat.stop_col,
      hl_group = higroup,
      invalidate = true,
      undo_restore = true,
      --todo: update/delete on buffer changing
    })
  end

  state.matches[keyword] = { color = color, xmarks = xmarks }
end

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

function M.vsel()
  local bufnr = ni.get_current_buf()
  local keyword = vsel.oneline_text(bufnr)
  if keyword == nil then return jelly.info("no selected text") end
  highlight(bufnr, keyword)
end

function M.cword()
  local bufnr = ni.get_current_buf()
  local keyword = vim.fn.expand("<cword>")
  if keyword == "" then return jelly.info("no cursor word") end
  highlight(bufnr, keyword)
end

function M.clear()
  local bufnr = ni.get_current_buf()
  local state = states[bufnr]
  if state == nil then return jelly.info("no highlights") end
  local keywords = dictlib.keys(state.matches)
  if #keywords == 0 then return jelly.info("no highlights") end
  if #keywords == 1 then return clear_highlights(bufnr, keywords[1]) end
  puff.select(keywords, { prompt = "🍫" }, function(keyword) clear_highlights(bufnr, keyword) end)
end

return M
