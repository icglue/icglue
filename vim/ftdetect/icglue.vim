
augroup filetypedetect
    au! BufNewFile,BufRead *.icglue,*.glue setf icglueconstructtcl
augroup END

augroup filetypedetect
    au! BufNewFile,BufRead */icglue/*/icglue_*.tcl,*/icglue,*/icsng2icglue setf icgluetcl
    " reorder existing tcl after icgluetcl group
    au! BufNewFile,BufRead *.tcl,*.tk,*.itcl,*.itk,*.jacl	setf tcl
augroup END

