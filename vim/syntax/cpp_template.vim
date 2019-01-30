
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

syn region cPreProc start=/^\s*\zs\(%:\|#\)\s*\(if\|ifdef\|ifndef\|elif\)\>/ skip=/\\$/ end=/$/  keepend contains=cComment,cCommentL,cCppString,cCharacter,cCppParen,cParenError,cNumbers,cCommentError,cSpaceError,templateCode

let b:current_syntax = "cpp_template"

