
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the verilog syntax-file
runtime! syntax/verilog.vim
unlet b:current_syntax

" Read the icglue template syntax-file
runtime! syntax/icglue_template.vim
unlet b:current_syntax

let b:current_syntax = "verilog_template"

