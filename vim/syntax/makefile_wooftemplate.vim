
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the make syntax-file
runtime! syntax/make.vim
unlet b:current_syntax

" Read the woof template syntax-file
runtime! syntax/woof_template.vim
unlet b:current_syntax

let b:current_syntax = "makefile_wooftemplate"

