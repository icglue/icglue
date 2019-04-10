" just use tcl indentation...
if exists("b:did_indent")
  finish
endif

runtime! indent/tcl.vim

let b:did_indent = 1
