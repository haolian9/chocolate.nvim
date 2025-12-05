to highlight selected word or word under cursor

## design choices, features, limits
* keyword/fixedstr only, with boundary
* finite number of colors
* match scope: function or global
* per-buffer state
* highlights showing in all windows
  * extmark vs matchadd*
* no jump support. use a motion plugin instead

## status
* wip

## prerequisites
* nvim 0.11.*
* haolian9/infra.nvim

## usage
here is my setting:
```
do --chocolate
  m.x("gh", [[<esc><cmd>lua require'chocolate'.vsel()<cr>]])
  m.n("gh", function() require("chocolate").cword() end)
  m.n("gH", function() require("chocolate").clear() end)
end
```
