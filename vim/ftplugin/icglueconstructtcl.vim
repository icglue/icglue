
if exists("b:did_icglueconstructtcl_ftplugin")
    finish
endif
let b:did_icglueconstructtcl_ftplugin = 1

let g:syntastic_icglueconstructtcl_checkers = ['nagelfar']

" from tcl ftplugin:
" Vim filetype plugin file
" Language:         Tcl
" Maintainer:       Robert L Hicks <sigzero@gmail.com>
" Latest Revision:  2009-05-01
" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:cpo_save = &cpo
set cpo-=C

setlocal comments=:#
setlocal commentstring=#%s
setlocal formatoptions+=croql

" Change the browse dialog on Windows to show mainly Tcl-related files
if has("gui_win32")
    let b:browsefilter = "Tcl Source Files (.tcl)\t*.tcl\n" .
                \ "Tcl Test Files (.test)\t*.test\n" .
                \ "All Files (*.*)\t*.*\n"
endif

"-----------------------------------------------------------------------------

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal fo< com< cms< inc< inex< def< isf< kp<" .
            \         " | unlet! b:browsefilter"

" Restore the saved compatibility options.
let &cpo = s:cpo_save
unlet s:cpo_save

if !exists("b:ftplugin_icglue_noimap")
    if !exists("b:ftplugin_icglue_opt1")
        let b:ftplugin_icglue_opt1='-ogpc -l1'
    endif
    if !exists("b:ftplugin_icglue_opt2")
        let b:ftplugin_icglue_opt2='-ogc -l1'
    endif
    vmap <silent> <Leader>tA        :call Align_icglue_signals('=p2P2W')       <CR>
    vmap <silent> <Leader>ta        :call Align_icglue_signals_blocks('=p2P2W')<CR>

    vmap <silent> <Leader>tr        :call Ascii2UTF8_Tree()<CR>
    vmap <silent> <Leader>tR        :call UTF82Ascii_Tree()<CR>

    vmap <silent> <Leader>ts        :call Quote_icglue_signals()               <CR>
    vmap <silent> <Leader>tw        :call Move_icglue_width_signal()           <CR>
    vmap <silent> <Leader>tb        :call Align_icglue_signal_linebreak_block()<CR>
    imap <silent> <C-A>        <ESC>:call Vins_icglue(b:ftplugin_icglue_opt1)  <CR>
    imap <silent> <C-E>        <ESC>:call Vins_icglue(b:ftplugin_icglue_opt2)  <CR>

endif

fun! Vins_icglue(param)
    let inst = getline('.')
    let inst = substitute(inst, '\[', '\\[', '')
    let inst = substitute(inst, '\]', '\\]', '')
    let cmd = 'vins ' .  a:param . ' ' . shellescape(inst)
    let result = system(cmd)
    if (strlen(result) == 0)
        echo "No module found!"
    else
        let replace_lines = split(result, '\n')
        call setline(line('.'), replace_lines[0])
        call append(line('.'), replace_lines[1:])
        echo "Module completed!"
    endif
endfun

fun! Align_icglue_signals_blocks(actrl) range
    call Align_icglue_signals(a:actrl)
    call Align_icglue_signal_linebreak_block()
endfun

fun! Align_icglue_signals(actrl) range
    AlignPush
    AlignCtrl g ^\s*S\s
    call Align#AlignCtrl('p1P1W')
    silent '<,'>Align "
    silent '<,'>s/" \([^"]\{-}\)\(\s\+\)" /"\1"\2/ge
    silent '<,'>s/\S\+\s\+\(<\|-\)-\(-\|>\)/§&/e
    call Align#AlignCtrl('p1P0W')
    silent '<,'>Align §
    silent '<,'>s/§//e
    call Align#AlignCtrl(a:actrl)
    silent '<,'>Align := --> <-- <->
    silent '<,'>s/\s\+$//e
    AlignPop
endfun

fun! Move_icglue_width_signal() range
    '<,'>s/^\(\s*\)S\s*-w\s*\(\S\+\)\s*\(\S\+\)/\1S \3 -w \2/ge
endfun

fun! Align_icglue_signal_linebreak_block() range
    AlignPush
    AlignCtrl g §
    silent '<,'>s/\v^(.*(\<--|\<-\>|--\>)\s+|\s+)([^# ])/\1§\3/e
    call Align#AlignCtrl('p2P0I')
    silent '<,'>Align § 
    silent '<,'>s/§//e

    " Alignment of \
    "AlignCtrl g \v^(.*(\<--|\<-\>|--\>)\s+|\s+)
    "call Align#AlignCtrl('p1P0W')
    "silent '<,'>Align \\$

    silent '<,'>s/\s\+\\$/ \\/e
    silent '<,'>s/\s\+$//e
    AlignCtrl Pop
endfun

fun! Ascii2UTF8_Tree() range
    silent '<,'>s/|/│/ge
    silent '<,'>s/+/├/ge
    silent '<,'>s/-/─/ge
    silent '<,'>s/\\/└/ge
endfun

fun! UTF82Ascii_Tree() range
    silent '<,'>s/│/|/ge
    silent '<,'>s/├/+/ge
    silent '<,'>s/─/-/ge
    silent '<,'>s/└/\\/ge
endfun

fun! Quote_icglue_signals() range
    '<,'>s/^\(\s*\)S \([^" ]\+\)/\1S "\2"/e
endfun


