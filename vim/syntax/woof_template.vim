
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
syn region  WtemplateCode start="^%(" end="^%)" contains=ICGTtclCommand,ICGTtclVars,ICGTtclBoolean,ICGTtclProcCommand,ICGTtclConditional,ICGTtclLabel,ICGTtclRepeat,ICGTtclVarRef,ICGTtclExpand,ICGTtcltkCommand,ICGTtclString,ICGTtclLineContinue,ICGTtclNotLineContinue,ICGTtclNumber,ICGTtclComment

syn region  WtemplateCode start="^%[^()]" end="$" contains=ICGTtclCommand,ICGTtclVars,ICGTtclBoolean,ICGTtclProcCommand,ICGTtclConditional,ICGTtclLabel,ICGTtclRepeat,ICGTtclVarRef,ICGTtclExpand,ICGTtcltkCommand,ICGTtclString,ICGTtclLineContinue,ICGTtclNotLineContinue,ICGTtclNumber,ICGTtclComment

syn region  WtemplateCode start="\[" end="\]" contains=ICGTtclCommand,ICGTtclVars,ICGTtclBoolean,ICGTtclProcCommand,ICGTtclConditional,ICGTtclLabel,ICGTtclRepeat,ICGTtclVarRef,ICGTtclExpand,ICGTtcltkCommand,ICGTtclString,ICGTtclLineContinue,ICGTtclNotLineContinue,ICGTtclNumber,ICGTtclComment

syn match WtemplateCode0 "^%$"

hi def link WtemplateCode  Comment
hi def link WtemplateCode0 Comment

"Modify the following as needed.  The trade-off is performance versus
"functionality.
syn sync minlines=50

let b:current_syntax = "woof_template"
