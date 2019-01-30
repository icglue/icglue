
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the c++ syntax-file
runtime! syntax/cpp.vim
unlet b:current_syntax

" Read the icglue template syntax-file
runtime! syntax/icglue_template.vim
unlet b:current_syntax

let b:current_syntax = "cpp_template"

