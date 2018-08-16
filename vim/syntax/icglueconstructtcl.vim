
" include tcl syntax
set syntax=tcl

" -- general --
" match module extname (modname<extname>)
syn match igModext "<[^-<>]\+>"

hi def link igModext  igModuleIdentifier

" match verilog number
syn match  tclNumber "\<\d\+'[bhd][0-9a-fA-F_]\+\>"
syn region igPort start=/\v:/ms=e end=/\v>/ contained contains=tclVarRef

hi def link igPort Normal

syn cluster igtclExtensions add=tclComment,tclString,tclNumber,tclVarRef,tclLineContinue

" module command
syn keyword igModcmd M                                contained
syn match   igMFlags "\v-<tree>"                      contained
syn match   igMFlags "\v<u(nit)?>(\=)?"               contained
syn match   igMFlags "\v<i(nst(ances|anciate)?)?>"    contained
syn match   igMFlags "\v<rtl>"                        contained
syn match   igMFlags "\v<beh(av(ioral|ioural)?)?>"    contained
syn match   igMFlags "\v<(tb|testbench)?>"            contained
syn match   igMFlags "\v<v(erilog)?>"                 contained
syn match   igMFlags "\v<sv|-s(ystemverilog)?>"       contained
syn match   igMFlags "\v<vhd(l)?>"                    contained
syn match   igMFlags "\v<(ilm|macro)?>"               contained
syn match   igMFlags "\v<res(ource)?>"                contained
syn match   igMFlags "\v<(rf|(regf(ile)?)?)>(\=)?"    contained
syn match   igMFlags "\v<attr(ibutes)?>(\=)?"         contained
syn match   igMIdent "\v\w+"                          contained
syn region  igMTFlags start="("ms=e+1 end=")"me=s-1   contained contains=igMFlags,tclCommand,tclEmbeddedStatement
syn region  igMblocklist start="\v\{"ms=e end="\v\}"  contained contains=igMTFlags,igMIdent,tclVarRef,tclComment
syn region  igModule  start=/^\s*M.*-tree/ end=/$/              contains=igModcmd,igMFlags,igMblocklist,tclComment,tclEmbeddedStatement,tclLineContinue

hi def link igModcmd     igCommand
hi def link igMTFlags    igModuleIdentifier
hi def link igMFlags     igFlags
hi def link igMIdent     igModuleIdentifier
hi def link igModule     igModuleIdentifier

" signal command
syn keyword igSigcmd S                           contained
syn match  igSigwidth "\v-w(idth)?>(\=)?\s*\S+"  contained
syn match  igCon "\v\<-\>"                       contained
syn match  igCon "\v-(-)?\>"                     contained
syn match  igCon "\v\<(-)?-"                     contained
syn match  igSFlags "\v(-v(alue)?>(\=)?|\=)"     contained
syn match  igSFlags "\v-b(idir(ectional)?)?"     contained
syn match  igSFlags "\v-p(in)?"                  contained
syn region igSlistblock start="\s{"ms=e end="}"  contained contains=tclVarRef,igPort,tclNumber
syn region igSignal start=/^\s*S\>/ end=/$/                contains=igSigcmd,igSigwidth,igCon,igSFlags,igPort,igSlistblock,@igtclExtensions

hi def link igSigcmd     tclCommand
hi def link igSigwidth   Constant
hi def link igSFlags     igFlags
hi def link igSlistblock igSignal
hi def link igSignal     igModuleIdentifier

" parameter command
syn keyword igParamcmd P                              contained
syn match   igParamNameConv "\v(<|:)[A-Z][A-Z_0-9]*>" contained
syn match   igPFlags        "\v(\=|-v(alue)?>)"       contained
syn region  igParamblock start="\s{"ms=e end="}"      contained contains=igParamNameConv,tclNumber
syn region  igParam      start=/^\s*P\>/ end=/$/                contains=igParamcmd,igPFlags,igParamNameConv,igParamblock,igPort,igSlistblock,@igtclExtensions
hi def link igParamcmd      igCommand
hi def link igPFlags        igFlags
hi def link igParamNameConv Constant
hi def link igParamblock    igModuleIdentifier
hi def link igParam         igModuleIdentifier


"-- code command --
syn keyword igCodecmd C                          contained
syn region  igClistblock start="{"ms=e end="}"   contained contains=igClistblock
syn region  igCode start=/^\s*C\>/ end=/$/                 contains=igCodecmd,igClistblock,tclLineContinue,tclString
" default highlighting
hi def link igCodecmd    igCommand
hi def link igCode       igModuleIdentifier
hi def link igClistblock igInlineCode

"default higlighting (maybe too much ??)
hi def link igModuleIdentifier PreProc
hi def link igInlineCode       LineNr
hi def link igCommand          tclCommand
hi def link igFlags            Special
hi def link igCon              Special
hi def link igMblocklist       Specialkey

syn sync minlines=1000
