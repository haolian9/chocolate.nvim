to highlight selected word or word under cursor

https://github.com/user-attachments/assets/345ccb97-39f8-499b-939f-14ff0213758b

## design choices, features, limits
* keyword/fixedstr only, with boundary
* finite number of colors
* incremental match scope. repeatable .{vsel,cword}()
* per-buffer state
* highlights seeing in all windows who bound to the same buffer
  * extmark vs matchadd*
* no jumping support. use a motion plugin instead

## status
* just works (tm)
* feature-frozen

## prerequisites
* nvim 0.11.*
* with treesitter enabled
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
