
augroup filetypedetect
    au! BufNewFile,BufRead *.icglue,*.glue
        \ setf icglueconstructtcl |
        \ set syntax=tcl
augroup END

