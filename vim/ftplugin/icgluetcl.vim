
if exists("b:did_icgluetcl_ftplugin")
  finish
endif
let b:did_icgluetcl_ftplugin = 1

set syntax=tcl
let g:syntastic_icgluetcl_checkers = ['nagelfar']
