
" quit when a syntax file was already loaded
if exists("b:current_syntax")
   finish
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" tcl part
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Basic Tcl commands: http://www.tcl.tk/man/tcl8.6/TclCmd/contents.htm
syn keyword ICGTtclCommand          after append array bgerror binary cd chan clock close concat contained
syn keyword ICGTtclCommand          dde dict encoding eof error eval exec exit expr fblocked contained
syn keyword ICGTtclCommand          fconfigure fcopy file fileevent flush format gets glob contained
syn keyword ICGTtclCommand          global history http incr info interp join lappend lassign contained
syn keyword ICGTtclCommand          lindex linsert list llength lmap load lrange lrepeat contained
syn keyword ICGTtclCommand          lreplace lreverse lsearch lset lsort memory my namespace contained
syn keyword ICGTtclCommand          next nextto open package pid puts pwd read refchan regexp contained
syn keyword ICGTtclCommand          registry regsub rename scan seek self set socket source contained
syn keyword ICGTtclCommand          split string subst tell time trace unknown unload unset contained
syn keyword ICGTtclCommand          update uplevel upvar variable vwait contained

" The 'Tcl Standard Library' commands: http://www.tcl.tk/man/tcl8.6/TclCmd/library.htm
syn keyword ICGTtclCommand          auto_execok auto_import auto_load auto_mkindex auto_reset contained
syn keyword ICGTtclCommand          auto_qualify tcl_findLibrary parray tcl_endOfWord contained
syn keyword ICGTtclCommand          tcl_startOfNextWord tcl_startOfPreviousWord contained
syn keyword ICGTtclCommand          tcl_wordBreakAfter tcl_wordBreakBefore contained

" Global variables used by Tcl: http://www.tcl.tk/man/tcl8.6/TclCmd/ICGTtclvars.htm
syn keyword ICGTtclVars             auto_path env errorCode errorInfo tcl_library tcl_patchLevel contained
syn keyword ICGTtclVars             tcl_pkgPath tcl_platform tcl_precision tcl_rcFileName contained
syn keyword ICGTtclVars             tcl_traceCompile tcl_traceExec tcl_wordchars contained
syn keyword ICGTtclVars             tcl_nonwordchars tcl_version argc argv argv0 tcl_interactive contained

" Strings which expr accepts as boolean values, aside from zero / non-zero.
syn keyword ICGTtclBoolean          true false on off yes no contained

syn keyword ICGTtclProcCommand      apply coroutine proc return tailcall yield yieldto contained
syn keyword ICGTtclConditional      if then else elseif switch contained
syn keyword ICGTtclConditional      catch try throw finally contained
syn keyword ICGTtclLabel            default contained
syn keyword ICGTtclRepeat           while for break continue contained
syn keyword ICGTtclRepeat           foreach foreach_array foreach_array_with foreach_array_join contained
syn keyword ICGTtclRepeat           foreach_preamble foreach_array_preamble foreach_array_preamble_with foreach_array_preamble_join contained
syn keyword ICGTtclRepeat           foreach_preamble_epilog foreach_array_preamble_epilog foreach_array_preamble_epilog_with foreach_array_preamble_epilog_join contained

" variable reference
        " ::optional::namespaces
syn match ICGTtclVarRef "$\(\(::\)\?\([[:alnum:]_]*::\)*\)\a[[:alnum:]_]*" contained
        " ${...} may contain any character except '}'
syn match ICGTtclVarRef "${[^}]*}" contained

" Used to facilitate hack to utilize string background for certain color
" schemes, e.g. inkpot and lettuce.
syn cluster ICGTtclVarRefC add=ICGTtclVarRef
syn cluster ICGTtclSpecialC add=ICGTtclSpecial

" The syntactic unquote-splicing replacement for [expand].
syn match ICGTtclExpand '\s{\*}' contained
syn match ICGTtclExpand '^{\*}' contained


" NAMESPACE
" commands associated with namespace
syn keyword ICGTtcltkNamespaceSwitch contained children code current delete eval
syn keyword ICGTtcltkNamespaceSwitch contained export forget import inscope origin
syn keyword ICGTtcltkNamespaceSwitch contained parent qualifiers tail which command variable
syn region ICGTtcltkCommand matchgroup=ICGTtcltkCommandColor start="\<namespace\>" matchgroup=NONE skip="^\s*$" end="{\|}\|]\|\"\|[^\\]*\s*$"me=e-1  contains=ICGTtclLineContinue,ICGTtcltkNamespaceSwitch contained

" EXPR
" commands associated with expr
syn keyword ICGTtcltkMaths contained        abs acos asin atan atan2 bool ceil cos cosh double entier
syn keyword ICGTtcltkMaths contained        exp floor fmod hypot int isqrt log log10 max min pow rand
syn keyword ICGTtcltkMaths contained        round sin sinh sqrt srand tan tanh wide

syn region ICGTtcltkCommand matchgroup=ICGTtcltkCommandColor start="\<expr\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"me=e-1  contains=ICGTtclLineContinue,ICGTtcltkMaths,ICGTtclNumber,ICGTtclVarRef,ICGTtclString,ICGTtcltlWidgetSwitch,ICGTtcltkCommand,ICGTtcltkPackConf contained

" format
syn region ICGTtcltkCommand matchgroup=ICGTtcltkCommandColor start="\<format\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"me=e-1  contains=ICGTtclLineContinue,ICGTtcltkMaths,ICGTtclNumber,ICGTtclVarRef,ICGTtclString,ICGTtcltlWidgetSwitch,ICGTtcltkCommand,ICGTtcltkPackConf contained

" STRING
" commands associated with string
syn keyword ICGTtcltkStringSwitch   contained       compare first index last length match range tolower toupper trim trimleft trimright wordstart wordend
syn region ICGTtcltkCommand matchgroup=ICGTtcltkCommandColor start="\<string\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"he=e-1  contains=ICGTtclLineContinue,ICGTtcltkStringSwitch,ICGTtclNumber,ICGTtclVarRef,ICGTtclString,ICGTtcltkCommand contained

" ARRAY
" commands associated with array
syn keyword ICGTtcltkArraySwitch    contained       anymore donesearch exists get names nextelement size startsearch set
" match from command name to ] or EOL
syn region ICGTtcltkCommand matchgroup=ICGTtcltkCommandColor start="\<array\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"he=e-1  contains=ICGTtclLineContinue,ICGTtcltkArraySwitch,ICGTtclNumber,ICGTtclVarRef,ICGTtclString,ICGTtcltkCommand contained

" LSORT
" switches for lsort
syn keyword ICGTtcltkLsortSwitch    contained       ascii dictionary integer real command increasing decreasing index
" match from command name to ] or EOL
syn region ICGTtcltkCommand matchgroup=ICGTtcltkCommandColor start="\<lsort\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"he=e-1  contains=ICGTtclLineContinue,ICGTtcltkLsortSwitch,ICGTtclNumber,ICGTtclVarRef,ICGTtclString,ICGTtcltkCommand contained

syn keyword ICGTtclTodo contained   TODO

" Sequences which are backslash-escaped: http://www.tcl.tk/man/tcl8.5/TclCmd/Tcl.htm#M16
" Octal, hexadecimal, unicode codepoints, and the classics.
" Tcl takes as many valid characters in a row as it can, so \xAZ in a string is newline followed by 'Z'.
syn match   ICGTtclSpecial contained '\\\([0-7]\{1,3}\|x\x\{1,2}\|u\x\{1,4}\|[abfnrtv]\)'
syn match   ICGTtclSpecial contained '\\[\[\]\{\}\"\$]'

" Command appearing inside another command or inside a string.
syn region ICGTtclEmbeddedStatement start='\[' end='\]' contained contains=ICGTtclCommand,ICGTtclNumber,ICGTtclLineContinue,ICGTtclString,ICGTtclVarRef,ICGTtclEmbeddedStatement
" A string needs the skip argument as it may legitimately contain \".
" Match at start of line
syn region  ICGTtclString             start=+^"+ end=+"+ contains=@ICGTtclSpecialC skip=+\\\\\|\\"+ contained
"Match all other legal strings.
syn region  ICGTtclString             start=+[^\\]"+ms=s+1  end=+"+ contains=@ICGTtclSpecialC,@ICGTtclVarRefC,ICGTtclEmbeddedStatement skip=+\\\\\|\\"+ contained

" Line continuation is backslash immediately followed by newline.
syn match ICGTtclLineContinue '\\$' contained

if exists('g:tcl_warn_continuation')
    syn match ICGTtclNotLineContinue '\\\s\+$' contained
endif

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match  ICGTtclNumber            "\<\d\+\(u\=l\=\|lu\|f\)\>" contained
"floating point number, with dot, optional exponent
syn match  ICGTtclNumber            "\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>" contained
"floating point number, starting with a dot, optional exponent
syn match  ICGTtclNumber            "\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>" contained
"floating point number, without dot, with exponent
syn match  ICGTtclNumber            "\<\d\+e[-+]\=\d\+[fl]\=\>" contained
"hex number
syn match  ICGTtclNumber            "0x[0-9a-f]\+\(u\=l\=\|lu\)\>" contained
"syn match  ICGTtclIdentifier       "\<[a-z_][a-z0-9_]*\>"
syn case match

syn region  ICGTtclComment          start="^\s*\#" skip="\\$" end="$" contains=ICGTtclTodo contained
syn region  ICGTtclComment          start=/;\s*\#/hs=s+1 skip="\\$" end="$" contains=ICGTtclTodo contained

"syn match ICGTtclComment /^\s*\#.*$/
"syn match ICGTtclComment /;\s*\#.*$/hs=s+1

"syn sync ccomment ICGTtclComment

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link ICGTtcltkSwitch          Identifier
hi def link ICGTtclExpand            Identifier
hi def link ICGTtclLabel             Identifier
hi def link ICGTtclConditional       Identifier
hi def link ICGTtclRepeat            Identifier
hi def link ICGTtclNumber            Identifier
hi def link ICGTtclError             Identifier
hi def link ICGTtclCommand           Identifier
hi def link ICGTtclProcCommand       Identifier
hi def link ICGTtclString            Identifier
hi def link ICGTtclComment           Identifier
hi def link ICGTtclSpecial           Identifier
hi def link ICGTtclTodo              Identifier
" Below here are the commands and their options.
hi def link ICGTtcltkCommandColor    Identifier
hi def link ICGTtcltkWidgetColor     Identifier
hi def link ICGTtclLineContinue      WarningMsg
if exists('g:tcl_warn_continuation')
hi def link ICGTtclNotLineContinue   ErrorMsg
endif
hi def link ICGTtcltkStringSwitch    Identifier
hi def link ICGTtcltkArraySwitch     Identifier
hi def link ICGTtcltkLsortSwitch     Identifier
hi def link ICGTtcltkPackSwitch      Identifier
hi def link ICGTtcltkPackConfSwitch  Identifier
hi def link ICGTtcltkMaths           Identifier
hi def link ICGTtcltkNamespaceSwitch Identifier
hi def link ICGTtcltkWidgetSwitch    Identifier
hi def link ICGTtcltkPackConfColor   Identifier
hi def link ICGTtclVarRef            Identifier


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
