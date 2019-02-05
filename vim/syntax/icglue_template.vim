
" quit when a syntax file was already loaded
if exists("b:current_syntax")
   finish
endif

" Read the template tcl syntax-file
runtime! syntax/template_tcl.vim
unlet b:current_syntax

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" template part
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syn region  templateCode start="<%" end="%>" contains=ICGTtclCommand,ICGTtclVars,ICGTtclBoolean,ICGTtclProcCommand,ICGTtclConditional,ICGTtclLabel,ICGTtclRepeat,ICGTtclVarRef,ICGTtclExpand,ICGTtcltkCommand,ICGTtclString,ICGTtclLineContinue,ICGTtclNotLineContinue,ICGTtclNumber,ICGTtclComment

syn region  templateCode start="<\[" end="\]>" contains=ICGTtclCommand,ICGTtclVars,ICGTtclBoolean,ICGTtclProcCommand,ICGTtclConditional,ICGTtclLabel,ICGTtclRepeat,ICGTtclVarRef,ICGTtclExpand,ICGTtcltkCommand,ICGTtclString,ICGTtclLineContinue,ICGTtclNotLineContinue,ICGTtclNumber,ICGTtclComment
hi def link templateCode Comment

"Modify the following as needed.  The trade-off is performance versus
"functionality.
syn sync minlines=50

let b:current_syntax = "icglug_template"
