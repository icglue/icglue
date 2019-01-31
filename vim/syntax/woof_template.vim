
" quit when a syntax file was already loaded
if exists("b:current_syntax")
   finish
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" tcl part
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Basic Tcl commands: http://www.tcl.tk/man/tcl8.6/TclCmd/contents.htm
syn keyword WTFtclCommand          after append array bgerror binary cd chan clock close concat contained
syn keyword WTFtclCommand          dde dict encoding eof error eval exec exit expr fblocked contained
syn keyword WTFtclCommand          fconfigure fcopy file fileevent flush format gets glob contained
syn keyword WTFtclCommand          global history http incr info interp join lappend lassign contained
syn keyword WTFtclCommand          lindex linsert list llength lmap load lrange lrepeat contained
syn keyword WTFtclCommand          lreplace lreverse lsearch lset lsort memory my namespace contained
syn keyword WTFtclCommand          next nextto open package pid puts pwd read refchan regexp contained
syn keyword WTFtclCommand          registry regsub rename scan seek self set socket source contained
syn keyword WTFtclCommand          split string subst tell time trace unknown unload unset contained
syn keyword WTFtclCommand          update uplevel upvar variable vwait contained

" The 'Tcl Standard Library' commands: http://www.tcl.tk/man/tcl8.6/TclCmd/library.htm
syn keyword WTFtclCommand          auto_execok auto_import auto_load auto_mkindex auto_reset contained
syn keyword WTFtclCommand          auto_qualify tcl_findLibrary parray tcl_endOfWord contained
syn keyword WTFtclCommand          tcl_startOfNextWord tcl_startOfPreviousWord contained
syn keyword WTFtclCommand          tcl_wordBreakAfter tcl_wordBreakBefore contained

" Global variables used by Tcl: http://www.tcl.tk/man/tcl8.6/TclCmd/WTFtclvars.htm
syn keyword WTFtclVars             auto_path env errorCode errorInfo tcl_library tcl_patchLevel contained
syn keyword WTFtclVars             tcl_pkgPath tcl_platform tcl_precision tcl_rcFileName contained
syn keyword WTFtclVars             tcl_traceCompile tcl_traceExec tcl_wordchars contained
syn keyword WTFtclVars             tcl_nonwordchars tcl_version argc argv argv0 tcl_interactive contained

" Strings which expr accepts as boolean values, aside from zero / non-zero.
syn keyword WTFtclBoolean          true false on off yes no contained

syn keyword WTFtclProcCommand      apply coroutine proc return tailcall yield yieldto contained
syn keyword WTFtclConditional      if then else elseif switch contained
syn keyword WTFtclConditional      catch try throw finally contained
syn keyword WTFtclLabel            default contained
syn keyword WTFtclRepeat           while for break continue contained
syn keyword WTFtclRepeat           foreach foreach_array foreach_array_with foreach_array_join contained
syn keyword WTFtclRepeat           foreach_preamble foreach_array_preamble foreach_array_preamble_with foreach_array_preamble_join contained
syn keyword WTFtclRepeat           foreach_preamble_epilog foreach_array_preamble_epilog foreach_array_preamble_epilog_with foreach_array_preamble_epilog_join contained

" variable reference
        " ::optional::namespaces
syn match WTFtclVarRef "$\(\(::\)\?\([[:alnum:]_]*::\)*\)\a[[:alnum:]_]*" contained
        " ${...} may contain any character except '}'
syn match WTFtclVarRef "${[^}]*}" contained

" Used to facilitate hack to utilize string background for certain color
" schemes, e.g. inkpot and lettuce.
syn cluster WTFtclVarRefC add=WTFtclVarRef
syn cluster WTFtclSpecialC add=WTFtclSpecial

" The syntactic unquote-splicing replacement for [expand].
syn match WTFtclExpand '\s{\*}' contained
syn match WTFtclExpand '^{\*}' contained


" NAMESPACE
" commands associated with namespace
syn keyword WTFtcltkNamespaceSwitch contained children code current delete eval
syn keyword WTFtcltkNamespaceSwitch contained export forget import inscope origin
syn keyword WTFtcltkNamespaceSwitch contained parent qualifiers tail which command variable
syn region WTFtcltkCommand matchgroup=WTFtcltkCommandColor start="\<namespace\>" matchgroup=NONE skip="^\s*$" end="{\|}\|]\|\"\|[^\\]*\s*$"me=e-1  contains=WTFtclLineContinue,WTFtcltkNamespaceSwitch contained

" EXPR
" commands associated with expr
syn keyword WTFtcltkMaths contained        abs acos asin atan atan2 bool ceil cos cosh double entier
syn keyword WTFtcltkMaths contained        exp floor fmod hypot int isqrt log log10 max min pow rand
syn keyword WTFtcltkMaths contained        round sin sinh sqrt srand tan tanh wide

syn region WTFtcltkCommand matchgroup=WTFtcltkCommandColor start="\<expr\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"me=e-1  contains=WTFtclLineContinue,WTFtcltkMaths,WTFtclNumber,WTFtclVarRef,WTFtclString,WTFtcltlWidgetSwitch,WTFtcltkCommand,WTFtcltkPackConf contained

" format
syn region WTFtcltkCommand matchgroup=WTFtcltkCommandColor start="\<format\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"me=e-1  contains=WTFtclLineContinue,WTFtcltkMaths,WTFtclNumber,WTFtclVarRef,WTFtclString,WTFtcltlWidgetSwitch,WTFtcltkCommand,WTFtcltkPackConf contained

" STRING
" commands associated with string
syn keyword WTFtcltkStringSwitch   contained       compare first index last length match range tolower toupper trim trimleft trimright wordstart wordend
syn region WTFtcltkCommand matchgroup=WTFtcltkCommandColor start="\<string\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"he=e-1  contains=WTFtclLineContinue,WTFtcltkStringSwitch,WTFtclNumber,WTFtclVarRef,WTFtclString,WTFtcltkCommand contained

" ARRAY
" commands associated with array
syn keyword WTFtcltkArraySwitch    contained       anymore donesearch exists get names nextelement size startsearch set
" match from command name to ] or EOL
syn region WTFtcltkCommand matchgroup=WTFtcltkCommandColor start="\<array\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"he=e-1  contains=WTFtclLineContinue,WTFtcltkArraySwitch,WTFtclNumber,WTFtclVarRef,WTFtclString,WTFtcltkCommand contained

" LSORT
" switches for lsort
syn keyword WTFtcltkLsortSwitch    contained       ascii dictionary integer real command increasing decreasing index
" match from command name to ] or EOL
syn region WTFtcltkCommand matchgroup=WTFtcltkCommandColor start="\<lsort\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"he=e-1  contains=WTFtclLineContinue,WTFtcltkLsortSwitch,WTFtclNumber,WTFtclVarRef,WTFtclString,WTFtcltkCommand contained

syn keyword WTFtclTodo contained   TODO

" Sequences which are backslash-escaped: http://www.tcl.tk/man/tcl8.5/TclCmd/Tcl.htm#M16
" Octal, hexadecimal, unicode codepoints, and the classics.
" Tcl takes as many valid characters in a row as it can, so \xAZ in a string is newline followed by 'Z'.
syn match   WTFtclSpecial contained '\\\([0-7]\{1,3}\|x\x\{1,2}\|u\x\{1,4}\|[abfnrtv]\)'
syn match   WTFtclSpecial contained '\\[\[\]\{\}\"\$]'

" Command appearing inside another command or inside a string.
syn region WTFtclEmbeddedStatement start='\[' end='\]' contained contains=WTFtclCommand,WTFtclNumber,WTFtclLineContinue,WTFtclString,WTFtclVarRef,WTFtclEmbeddedStatement
" A string needs the skip argument as it may legitimately contain \".
" Match at start of line
syn region  WTFtclString             start=+^"+ end=+"+ contains=@WTFtclSpecialC skip=+\\\\\|\\"+ contained
"Match all other legal strings.
syn region  WTFtclString             start=+[^\\]"+ms=s+1  end=+"+ contains=@WTFtclSpecialC,@WTFtclVarRefC,WTFtclEmbeddedStatement skip=+\\\\\|\\"+ contained

" Line continuation is backslash immediately followed by newline.
syn match WTFtclLineContinue '\\$' contained

if exists('g:tcl_warn_continuation')
    syn match WTFtclNotLineContinue '\\\s\+$' contained
endif

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match  WTFtclNumber            "\<\d\+\(u\=l\=\|lu\|f\)\>" contained
"floating point number, with dot, optional exponent
syn match  WTFtclNumber            "\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>" contained
"floating point number, starting with a dot, optional exponent
syn match  WTFtclNumber            "\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>" contained
"floating point number, without dot, with exponent
syn match  WTFtclNumber            "\<\d\+e[-+]\=\d\+[fl]\=\>" contained
"hex number
syn match  WTFtclNumber            "0x[0-9a-f]\+\(u\=l\=\|lu\)\>" contained
"syn match  WTFtclIdentifier       "\<[a-z_][a-z0-9_]*\>"
syn case match

syn region  WTFtclComment          start="^\s*\#" skip="\\$" end="$" contains=WTFtclTodo contained
syn region  WTFtclComment          start=/;\s*\#/hs=s+1 skip="\\$" end="$" contains=WTFtclTodo contained

"syn match WTFtclComment /^\s*\#.*$/
"syn match WTFtclComment /;\s*\#.*$/hs=s+1

"syn sync ccomment WTFtclComment

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link WTFtcltkSwitch          Identifier
hi def link WTFtclExpand            Identifier
hi def link WTFtclLabel             Identifier
hi def link WTFtclConditional       Identifier
hi def link WTFtclRepeat            Identifier
hi def link WTFtclNumber            Identifier
hi def link WTFtclError             Identifier
hi def link WTFtclCommand           Identifier
hi def link WTFtclProcCommand       Identifier
hi def link WTFtclString            Identifier
hi def link WTFtclComment           Identifier
hi def link WTFtclSpecial           Identifier
hi def link WTFtclTodo              Identifier
" Below here are the commands and their options.
hi def link WTFtcltkCommandColor    Identifier
hi def link WTFtcltkWidgetColor     Identifier
hi def link WTFtclLineContinue      WarningMsg
if exists('g:tcl_warn_continuation')
hi def link WTFtclNotLineContinue   ErrorMsg
endif
hi def link WTFtcltkStringSwitch    Identifier
hi def link WTFtcltkArraySwitch     Identifier
hi def link WTFtcltkLsortSwitch     Identifier
hi def link WTFtcltkPackSwitch      Identifier
hi def link WTFtcltkPackConfSwitch  Identifier
hi def link WTFtcltkMaths           Identifier
hi def link WTFtcltkNamespaceSwitch Identifier
hi def link WTFtcltkWidgetSwitch    Identifier
hi def link WTFtcltkPackConfColor   Identifier
hi def link WTFtclVarRef            Identifier


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" template part
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syn region  WtemplateCode start="^%(" end="^%)" contains=WTFtclCommand,WTFtclVars,WTFtclBoolean,WTFtclProcCommand,WTFtclConditional,WTFtclLabel,WTFtclRepeat,WTFtclVarRef,WTFtclExpand,WTFtcltkCommand,WTFtclString,WTFtclLineContinue,WTFtclNotLineContinue,WTFtclNumber,WTFtclComment

syn region  WtemplateCode start="^%[^()]" end="$" contains=WTFtclCommand,WTFtclVars,WTFtclBoolean,WTFtclProcCommand,WTFtclConditional,WTFtclLabel,WTFtclRepeat,WTFtclVarRef,WTFtclExpand,WTFtcltkCommand,WTFtclString,WTFtclLineContinue,WTFtclNotLineContinue,WTFtclNumber,WTFtclComment
syn match WtemplateCode0 "^%$"

hi def link WtemplateCode  Comment
hi def link WtemplateCode0 Comment

"Modify the following as needed.  The trade-off is performance versus
"functionality.
syn sync minlines=50

let b:current_syntax = "woof_template"
