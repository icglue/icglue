
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the systemverilog syntax-file
runtime! syntax/systemverilog.vim
unlet b:current_syntax

" Read the woof template syntax-file
runtime! syntax/woof_template.vim
unlet b:current_syntax

let b:current_syntax = "systemverilog_wooftemplate"

