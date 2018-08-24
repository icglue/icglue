
" include tcl syntax
set syntax=tcl

" -- general --
" match module extname (modname<extname>)
syn match igModext "<[^-<>]\+>"

syn region  igCon start="\v\s(\<-\>|-(-)?\>|\<(-)?-)"ms=s+1 end="\v."me=e-1

syn keyword tclTodo FIXME

hi def link igModext  igModuleIdentifier

" match verilog number
syn match  tclNumber "\<\d\+'[bhd][0-9a-fA-F_]\+\>"
syn match  igPortadapt "!"                             contained
syn region igPort start=/\v:/ms=e end=/\v(\s|\n|\})/me=s-1 contained contains=igPortadapt,tclVarRef
hi def link igPortadapt Typedef
hi def link igPort      Normal

syn cluster igtclExtensions add=tclComment,tclString,tclNumber,tclVarRef,tclLineContinue

" module command
syn keyword igModcmd M                                contained
syn match   igMFlags "\v-<tree>"                      contained
syn match   igMFlags "\v-?<u(nit)?>(\=)?"             contained
syn match   igMFlags "\v-?<i(nst(ances|anciate)?)?>"  contained
syn match   igMFlags "\v-?<rtl>"                      contained
syn match   igMFlags "\v-?<beh(av(ioral|ioural)?)?>"  contained
syn match   igMFlags "\v-?<(tb|testbench)?>"          contained
syn match   igMFlags "\v-?<v(erilog)?>"               contained
syn match   igMFlags "\v-?<sv|-s(ystemverilog)?>"     contained
syn match   igMFlags "\v-?<vhd(l)?>"                  contained
syn match   igMFlags "\v-?<(ilm|macro)?>"             contained
syn match   igMFlags "\v-?<res(ource)?>"              contained
syn match   igMFlags "\v-?<(rf|(regf(ile)?)?)>(\=)?"  contained
syn match   igMFlags "\v-?attr(ibutes)?>(\=)?"        contained
syn match   igMFlags "\v-?rfattr(ibutes)?>(\=)?"      contained
syn match   igMFlags "\v<inc(lude)?>"                 contained
syn match   igMIdent "\v\w+"                          contained
syn region  igMTFlags start="("ms=e+1 end=")"me=s-1   contained contains=igMFlags,tclCommand,tclEmbeddedStatement
syn region  igMblocklist start="\v\{"ms=e end="\v\}"  contained contains=igMTFlags,igMIdent,tclVarRef,tclComment
syn region  igModule  start=/\v^\s*M>/ end=/$/                  contains=igModcmd,igMFlags,igMblocklist,tclComment,tclEmbeddedStatement,tclLineContinue,tclString

hi def link igModcmd     igCommand
hi def link igMTFlags    igModuleIdentifier
hi def link igMFlags     igFlags
hi def link igMIdent     igModuleIdentifier
hi def link igModule     igModuleIdentifier

" signal command
syn keyword igSigcmd S                           contained
"TODO: transform to region -- -w -> igFlags include { PARAM1 + PARAM2 + PARAM3 }  "PARAM1..."
syn match  igSigwidth "\v-w(idth)?>(\=)?\s*\S+"  contained
"syn match  igCon "\v(\<-\>|-(-)?\>|\<(-)?-)"     contained
syn match  igSFlags "\v(-v(alue)?>(\=)?|\=)"     contained
syn match  igSFlags "\v-b(idir(ectional)?)?"     contained
syn match  igSFlags "\v-p(in)?"                  contained
syn region igSlistblock start="\s{"ms=e end="}"  contained contains=tclVarRef,igPort,tclNumber,igSlistblock
syn region igSignal start=/^\s*S\>/ms=e end=/$/            contains=igSigcmd,igSigwidth,igCon,igSFlags,igPort,igSlistblock,@igtclExtensions

hi def link igSigcmd     igCommand
hi def link igSigwidth   Constant
hi def link igSFlags     igFlags
hi def link igSlistblock igSignal
hi def link igSignal     igModuleIdentifier

" signal+register command
syn keyword igSigRegcmd SR                               contained
syn match   igSRFlags "\v-addr\=?"                       contained
syn match   igSRFlags "@"                                contained
syn match   igSRFlags "\v-c(omment)?\=?"                 contained
syn match   igSRFlags "\v-handshake\=?"                  contained
syn match   igSRFlags "\v(-v(alue)?|\=|-r(eset(val)?)?)" contained
syn region  igSRlistblock start="\s{"ms=e end="}"        contained contains=tclVarRef,igPort,tclNumber,tclString,igSRlistblock
syn region  igSignalReg start=/^\s*SR\>/ms=e-1 end=/$/             contains=igSigRegcmd,igSigwidth,igCon,igSRFlags,igPort,igSRlistblock,@igtclExtensions

hi def link igSigRegcmd igCommand
hi def link igSRFlags   igFlags
hi def link igSignalReg igModuleIdentifier
hi def link igSRlistblock igSignal

" parameter command
syn keyword igParamcmd P                               contained
syn match   igParamNameConv "\v(<|:)[A-Z][A-Z_0-9]*>"  contained
syn match   igPFlags        "\v(\=|-v(alue)?>)"        contained
syn region  igParamblock start="\s{"ms=e end="}"       contained contains=igParamNameConv,tclNumber,igParamblock
syn region  igParam      start=/^\s*P\>/ end=/$/me=s-1           contains=igParamcmd,igPFlags,igParamNameConv,igParamblock,igPort,igSlistblock,@igtclExtensions
hi def link igParamcmd      igCommand
hi def link igPFlags        igFlags
hi def link igParamNameConv Constant
hi def link igParamblock    igModuleIdentifier
hi def link igParam         igModuleIdentifier


"code command
syn keyword igCodecmd C                            contained
syn keyword igCTODO TODO FIXME                     contained
syn region  igClistblock start="{"ms=e end="}"     contained contains=igClistblock,igCTODO
syn match   igCFlags "\v-a(dapt)?>"                contained
syn match   igCFlags "\v-noa(dapt)?>"              contained
syn match   igCFlags "\v-v(erbatim)?>"             contained
syn match   igCFlags "\v-s(ubst)?>"                contained
syn match   igCFlags "\v-nos(ubst)?>"              contained
syn match   igCFlags "\v-e(val(ulate)?)?>"         contained
syn region  igCode start=/^\s*C\>/ end=/$/me=s-1             contains=igCodecmd,igCFlags,igClistblock,tclLineContinue,tclString

hi def link igCTODO      Todo
hi def link igCodecmd    igCommand
hi def link igCFlags     igFlags
hi def link igCode       igModuleIdentifier
hi def link igClistblock igInlineCode


" regfile command
" signal+register command
syn keyword igRegcmd       R                        contained
syn match   igRFlags       "\v-addr\=?"             contained
syn match   igRFlags       "@"                      contained
syn match   igRFlags       "\v-(rf|regf(ile)?)\=?"  contained
syn match   igRFlags       "\v-s(ubst)?>"           contained
syn match   igRFlags       "\v-nos(ubst)?>"         contained
syn match   igRFlags       "\v-e(val(ulate)?)?>"    contained
syn match   igRFlags       "\v-handshake\=?"        contained
syn region  igReglistblock start="\s{"ms=e end="}"  contained contains=tclVarRef,tclNumber,tclString,tclEmbeddedStatement
syn region igReg start=/^\s*R\>/ms=e end=/$/                  contains=igRegcmd,igRFlags,igReglistblock,@igtclExtensions,tclEmbeddedStatement

hi def link igRegcmd       igCommand
hi def link igRFlags       igFlags
hi def link igReg          igModuleIdentifier
hi def link igReglistblock Normal

"default higlighting (maybe too much ??)
hi def link igModuleIdentifier PreProc
hi def link igInlineCode       LineNr
hi def link igCommand          tclCommand
hi def link igFlags            Special
hi def link igCon              Special
hi def link igMblocklist       Specialkey

syn sync minlines=1000
