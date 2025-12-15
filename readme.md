to highlight different words and their occurrences together

https://github.com/user-attachments/assets/345ccb97-39f8-499b-939f-14ff0213758b

## design choices, features, limits
* treat buffer as plain text, not treesitter AST.
  * treesitter.get_parse():register_cbs(on_changedtree) can be complex.
* keyword/fixedstr only, with boundary.
  * so there will not be overlaps between keywords, except unicode runes.
* finite number of colors
* incremental matching range.
  * by highlight the same keyword many times.
  * needs treesitter support
* per-buffer state
* highlights will be seen in all windows who bound to the same buffer
  * extmark vs matchadd*
* no jump support. use a motion plugin instead
* [opt-in] highlights should be updated/deleted while buffer changes

## status
* just works (tm)
* feature-fozen

## prerequisites
* nvim 0.11.*
* haolian9/infra.nvim
* haolian9/puff.nvim

## usage
* there are two flavors
  * dove: basic impl, no highlight auto-updating
  * snicker: offers highlight auto-adding/updating
* here is my setting:
```
do --chocolate
  m.x("gh", [[<esc><cmd>lua require'chocolate'('dove').vsel()<cr>]])
  m.n("gh", function() require("chocolate")("dove").cword() end)
  m.n("gH", function() require("chocolate")("dove").clear() end)
end
```
