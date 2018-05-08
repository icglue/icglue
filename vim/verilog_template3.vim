" copied from verilog/tcl syntax files

" quit when a syntax file was already loaded
if exists("b:current_syntax")
   finish
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" verilog part
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set the local value of the 'iskeyword' option.
" NOTE: '?' was added so that verilogNumber would be processed correctly when
"       '?' is the last character of the number.
setlocal iskeyword=@,48-57,63,_,192-255

" A bunch of useful Verilog keywords

syn keyword verilogStatement   always and assign automatic buf
syn keyword verilogStatement   bufif0 bufif1 cell cmos
syn keyword verilogStatement   config deassign defparam design
syn keyword verilogStatement   disable edge endconfig
syn keyword verilogStatement   endfunction endgenerate endmodule
syn keyword verilogStatement   endprimitive endspecify endtable endtask
syn keyword verilogStatement   event force function
syn keyword verilogStatement   generate genvar highz0 highz1 ifnone
syn keyword verilogStatement   incdir include initial inout input
syn keyword verilogStatement   instance integer large liblist
syn keyword verilogStatement   library localparam macromodule medium
syn keyword verilogStatement   module nand negedge nmos nor
syn keyword verilogStatement   noshowcancelled not notif0 notif1 or
syn keyword verilogStatement   output parameter pmos posedge primitive
syn keyword verilogStatement   pull0 pull1 pulldown pullup
syn keyword verilogStatement   pulsestyle_onevent pulsestyle_ondetect
syn keyword verilogStatement   rcmos real realtime reg release
syn keyword verilogStatement   rnmos rpmos rtran rtranif0 rtranif1
syn keyword verilogStatement   scalared showcancelled signed small
syn keyword verilogStatement   specify specparam strong0 strong1
syn keyword verilogStatement   supply0 supply1 table task time tran
syn keyword verilogStatement   tranif0 tranif1 tri tri0 tri1 triand
syn keyword verilogStatement   trior trireg unsigned use vectored wait
syn keyword verilogStatement   wand weak0 weak1 wire wor xnor xor
syn keyword verilogLabel       begin end fork join
syn keyword verilogConditional if else case casex casez default endcase
syn keyword verilogRepeat      forever repeat while for

syn keyword verilogTodo contained TODO FIXME

syn match   verilogOperator "[&|~><!)(*#%@+/=?:;}{,.\^\-\[\]]"

syn region  verilogComment start="/\*" end="\*/" contains=verilogTodo,@Spell
syn match   verilogComment "//.*" contains=verilogTodo,@Spell

"syn match   verilogGlobal "`[a-zA-Z0-9_]\+\>"
syn match verilogGlobal "`celldefine"
syn match verilogGlobal "`default_nettype"
syn match verilogGlobal "`define"
syn match verilogGlobal "`else"
syn match verilogGlobal "`elsif"
syn match verilogGlobal "`endcelldefine"
syn match verilogGlobal "`endif"
syn match verilogGlobal "`ifdef"
syn match verilogGlobal "`ifndef"
syn match verilogGlobal "`include"
syn match verilogGlobal "`line"
syn match verilogGlobal "`nounconnected_drive"
syn match verilogGlobal "`resetall"
syn match verilogGlobal "`timescale"
syn match verilogGlobal "`unconnected_drive"
syn match verilogGlobal "`undef"
syn match   verilogGlobal "$[a-zA-Z0-9_]\+\>"

syn match   verilogConstant "\<[A-Z][A-Z0-9_]\+\>"

syn match   verilogNumber "\(\<\d\+\|\)'[sS]\?[bB]\s*[0-1_xXzZ?]\+\>"
syn match   verilogNumber "\(\<\d\+\|\)'[sS]\?[oO]\s*[0-7_xXzZ?]\+\>"
syn match   verilogNumber "\(\<\d\+\|\)'[sS]\?[dD]\s*[0-9_xXzZ?]\+\>"
syn match   verilogNumber "\(\<\d\+\|\)'[sS]\?[hH]\s*[0-9a-fA-F_xXzZ?]\+\>"
syn match   verilogNumber "\<[+-]\=[0-9_]\+\(\.[0-9_]*\|\)\(e[0-9_]*\|\)\>"

syn region  verilogString start=+"+ skip=+\\"+ end=+"+ contains=verilogEscape,@Spell
syn match   verilogEscape +\\[nt"\\]+ contained
syn match   verilogEscape "\\\o\o\=\o\=" contained

" Directives
syn match   verilogDirective   "//\s*synopsys\>.*$"
syn region  verilogDirective   start="/\*\s*synopsys\>" end="\*/"
syn region  verilogDirective   start="//\s*synopsys dc_script_begin\>" end="//\s*synopsys dc_script_end\>"

syn match   verilogDirective   "//\s*\$s\>.*$"
syn region  verilogDirective   start="/\*\s*\$s\>" end="\*/"
syn region  verilogDirective   start="//\s*\$s dc_script_begin\>" end="//\s*\$s dc_script_end\>"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default highlighting.
hi def link verilogCharacter       Character
hi def link verilogConditional     Conditional
hi def link verilogRepeat          Repeat
hi def link verilogString          String
hi def link verilogTodo            Todo
hi def link verilogComment         Comment
hi def link verilogConstant        Constant
hi def link verilogLabel           Label
hi def link verilogNumber          Number
hi def link verilogOperator        Special
hi def link verilogStatement       Statement
hi def link verilogGlobal          Define
hi def link verilogDirective       SpecialComment
hi def link verilogEscape		 Special

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" tcl part
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Basic Tcl commands: http://www.tcl.tk/man/tcl8.6/TclCmd/contents.htm
syn keyword tclCommand		after append array bgerror binary cd chan clock close concat contained
syn keyword tclCommand		dde dict encoding eof error eval exec exit expr fblocked contained
syn keyword tclCommand		fconfigure fcopy file fileevent flush format gets glob contained
syn keyword tclCommand		global history http incr info interp join lappend lassign contained
syn keyword tclCommand		lindex linsert list llength lmap load lrange lrepeat contained
syn keyword tclCommand		lreplace lreverse lsearch lset lsort memory my namespace contained
syn keyword tclCommand		next nextto open package pid puts pwd read refchan regexp contained
syn keyword tclCommand		registry regsub rename scan seek self set socket source contained
syn keyword tclCommand		split string subst tell time trace unknown unload unset contained
syn keyword tclCommand		update uplevel upvar variable vwait contained

" The 'Tcl Standard Library' commands: http://www.tcl.tk/man/tcl8.6/TclCmd/library.htm
syn keyword tclCommand		auto_execok auto_import auto_load auto_mkindex auto_reset contained
syn keyword tclCommand		auto_qualify tcl_findLibrary parray tcl_endOfWord contained
syn keyword tclCommand		tcl_startOfNextWord tcl_startOfPreviousWord contained
syn keyword tclCommand		tcl_wordBreakAfter tcl_wordBreakBefore contained

" Global variables used by Tcl: http://www.tcl.tk/man/tcl8.6/TclCmd/tclvars.htm
syn keyword tclVars		auto_path env errorCode errorInfo tcl_library tcl_patchLevel contained
syn keyword tclVars		tcl_pkgPath tcl_platform tcl_precision tcl_rcFileName contained
syn keyword tclVars		tcl_traceCompile tcl_traceExec tcl_wordchars contained
syn keyword tclVars		tcl_nonwordchars tcl_version argc argv argv0 tcl_interactive contained

" Strings which expr accepts as boolean values, aside from zero / non-zero.
syn keyword tclBoolean		true false on off yes no contained

syn keyword tclProcCommand	apply coroutine proc return tailcall yield yieldto contained
syn keyword tclConditional	if then else elseif switch contained
syn keyword tclConditional	catch try throw finally contained
syn keyword tclLabel		default contained
syn keyword tclRepeat		while for foreach break continue contained

" variable reference
	" ::optional::namespaces
syn match tclVarRef "$\(\(::\)\?\([[:alnum:]_]*::\)*\)\a[[:alnum:]_]*" contained
	" ${...} may contain any character except '}'
syn match tclVarRef "${[^}]*}" contained

" Used to facilitate hack to utilize string background for certain color
" schemes, e.g. inkpot and lettuce.
syn cluster tclVarRefC add=tclVarRef
syn cluster tclSpecialC add=tclSpecial

" The syntactic unquote-splicing replacement for [expand].
syn match tclExpand '\s{\*}' contained
syn match tclExpand '^{\*}' contained


" NAMESPACE
" commands associated with namespace
syn keyword tcltkNamespaceSwitch contained children code current delete eval
syn keyword tcltkNamespaceSwitch contained export forget import inscope origin
syn keyword tcltkNamespaceSwitch contained parent qualifiers tail which command variable
syn region tcltkCommand matchgroup=tcltkCommandColor start="\<namespace\>" matchgroup=NONE skip="^\s*$" end="{\|}\|]\|\"\|[^\\]*\s*$"me=e-1  contains=tclLineContinue,tcltkNamespaceSwitch contained

" EXPR
" commands associated with expr
syn keyword tcltkMaths contained	abs acos asin atan atan2 bool ceil cos cosh double entier
syn keyword tcltkMaths contained	exp floor fmod hypot int isqrt log log10 max min pow rand
syn keyword tcltkMaths contained	round sin sinh sqrt srand tan tanh wide

syn region tcltkCommand matchgroup=tcltkCommandColor start="\<expr\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"me=e-1  contains=tclLineContinue,tcltkMaths,tclNumber,tclVarRef,tclString,tcltlWidgetSwitch,tcltkCommand,tcltkPackConf contained

" format
syn region tcltkCommand matchgroup=tcltkCommandColor start="\<format\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"me=e-1  contains=tclLineContinue,tcltkMaths,tclNumber,tclVarRef,tclString,tcltlWidgetSwitch,tcltkCommand,tcltkPackConf contained

" STRING
" commands associated with string
syn keyword tcltkStringSwitch	contained	compare first index last length match range tolower toupper trim trimleft trimright wordstart wordend
syn region tcltkCommand matchgroup=tcltkCommandColor start="\<string\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"he=e-1  contains=tclLineContinue,tcltkStringSwitch,tclNumber,tclVarRef,tclString,tcltkCommand contained

" ARRAY
" commands associated with array
syn keyword tcltkArraySwitch	contained	anymore donesearch exists get names nextelement size startsearch set
" match from command name to ] or EOL
syn region tcltkCommand matchgroup=tcltkCommandColor start="\<array\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"he=e-1  contains=tclLineContinue,tcltkArraySwitch,tclNumber,tclVarRef,tclString,tcltkCommand contained

" LSORT
" switches for lsort
syn keyword tcltkLsortSwitch	contained	ascii dictionary integer real command increasing decreasing index
" match from command name to ] or EOL
syn region tcltkCommand matchgroup=tcltkCommandColor start="\<lsort\>" matchgroup=NONE skip="^\s*$" end="]\|[^\\]*\s*$"he=e-1  contains=tclLineContinue,tcltkLsortSwitch,tclNumber,tclVarRef,tclString,tcltkCommand contained

syn keyword tclTodo contained	TODO

" Sequences which are backslash-escaped: http://www.tcl.tk/man/tcl8.5/TclCmd/Tcl.htm#M16
" Octal, hexadecimal, unicode codepoints, and the classics.
" Tcl takes as many valid characters in a row as it can, so \xAZ in a string is newline followed by 'Z'.
syn match   tclSpecial contained '\\\([0-7]\{1,3}\|x\x\{1,2}\|u\x\{1,4}\|[abfnrtv]\)'
syn match   tclSpecial contained '\\[\[\]\{\}\"\$]'

" Command appearing inside another command or inside a string.
syn region tclEmbeddedStatement	start='\[' end='\]' contained contains=tclCommand,tclNumber,tclLineContinue,tclString,tclVarRef,tclEmbeddedStatement
" A string needs the skip argument as it may legitimately contain \".
" Match at start of line
syn region  tclString		  start=+^"+ end=+"+ contains=@tclSpecialC skip=+\\\\\|\\"+ contained
"Match all other legal strings.
syn region  tclString		  start=+[^\\]"+ms=s+1  end=+"+ contains=@tclSpecialC,@tclVarRefC,tclEmbeddedStatement skip=+\\\\\|\\"+ contained

" Line continuation is backslash immediately followed by newline.
syn match tclLineContinue '\\$' contained

if exists('g:tcl_warn_continuation')
    syn match tclNotLineContinue '\\\s\+$' contained
endif

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match  tclNumber		"\<\d\+\(u\=l\=\|lu\|f\)\>" contained
"floating point number, with dot, optional exponent
syn match  tclNumber		"\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>" contained
"floating point number, starting with a dot, optional exponent
syn match  tclNumber		"\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>" contained
"floating point number, without dot, with exponent
syn match  tclNumber		"\<\d\+e[-+]\=\d\+[fl]\=\>" contained
"hex number
syn match  tclNumber		"0x[0-9a-f]\+\(u\=l\=\|lu\)\>" contained
"syn match  tclIdentifier	"\<[a-z_][a-z0-9_]*\>"
syn case match

syn region  tclComment		start="^\s*\#" skip="\\$" end="$" contains=tclTodo contained
syn region  tclComment		start=/;\s*\#/hs=s+1 skip="\\$" end="$" contains=tclTodo contained

"syn match tclComment /^\s*\#.*$/
"syn match tclComment /;\s*\#.*$/hs=s+1

"syn sync ccomment tclComment

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link tcltkSwitch		Identifier
hi def link tclExpand		Identifier
hi def link tclLabel		Identifier
hi def link tclConditional	Identifier
hi def link tclRepeat		Identifier
hi def link tclNumber		Identifier
hi def link tclError		Identifier
hi def link tclCommand		Identifier
hi def link tclProcCommand	Identifier
hi def link tclString		Identifier
hi def link tclComment		Identifier
hi def link tclSpecial		Identifier
hi def link tclTodo		Identifier
" Below here are the commands and their options.
hi def link tcltkCommandColor	Identifier
hi def link tcltkWidgetColor	Identifier
hi def link tclLineContinue	WarningMsg
if exists('g:tcl_warn_continuation')
hi def link tclNotLineContinue	ErrorMsg
endif
hi def link tcltkStringSwitch	Identifier
hi def link tcltkArraySwitch	Identifier
hi def link tcltkLsortSwitch	Identifier
hi def link tcltkPackSwitch	Identifier
hi def link tcltkPackConfSwitch	Identifier
hi def link tcltkMaths		Identifier
hi def link tcltkNamespaceSwitch	Identifier
hi def link tcltkWidgetSwitch	Identifier
hi def link tcltkPackConfColor	Identifier
hi def link tclVarRef		Identifier


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" template part
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syn region  templateCode start="<%" end="%>" contains=tclCommand,tclVars,tclBoolean,tclProcCommand,tclConditional,tclLabel,tclRepeat,tclVarRef,tclExpand,tcltkCommand,tclString,tclLineContinue,tclNotLineContinue,tclNumber,tclComment
hi def link templateCode Comment

"Modify the following as needed.  The trade-off is performance versus
"functionality.
syn sync minlines=50

let b:current_syntax = "verilog_template"

" vim: ts=8
