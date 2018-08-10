
" include tcl syntax
set syntax=tcl

" match key commands 
syn keyword ICGcommand M P S R

" match signal connection
syn match ICGcon "-->"
syn match ICGcon "<--"
syn match ICGcon "<->"

" match special flags
syn match ICGflags "\s-pin\>"
syn match ICGflags "\s-unit\>"
syn match ICGflags "\s-tree\>"
syn match ICGtype "\<ilm\>"
syn match ICGtype "\<beh\>"
syn match ICGtype "\<rtl\>"
syn match ICGtype "\<inc\>"
syn match ICGtype "\<tb\>"
syn match ICGtype "\<res\>"
syn match ICGtype "\<rf\>"

" match param width
syn match ICGsigwidth "\s-w\s*\S\+"

" match module extname (modname<extname>)
syn match ICGmodext "<[^-<>]\+>"

" match verilog number
syn match tclNumber "\<\d\+'[bhd]\d\+\>"

" default highlighting
hi def link ICGcommand  tclCommand
hi def link ICGmodext   PreProc
hi def link ICGcon      Special
hi def link ICGtype     Type
hi def link ICGsigwidth Constant
hi def link ICGflags    Special

