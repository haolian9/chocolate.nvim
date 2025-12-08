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
* highlights should be updated/deleted while buffer changes

## todo
* [] using nvim_buf_attach() to keep highlights correctness
* [] using nvim_set_decoration_provider to add highlights to visible range of buffer only

## status
* works, imperfectly

## prerequisites
* nvim 0.11.*
* haolian9/infra.nvim
* haolian9/puff.nvim

## usage
here is my setting:
```
do --chocolate
  m.x("gh", [[<esc><cmd>lua require'chocolate'.vsel()<cr>]])
  m.n("gh", function() require("chocolate").cword() end)
  m.n("gH", function() require("chocolate").clear() end)
end
```
