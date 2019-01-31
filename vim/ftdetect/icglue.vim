
augroup filetypedetect
    au! BufNewFile,BufRead *.icglue,*.glue setf icglueconstructtcl
augroup END

augroup filetypedetect
    au! BufNewFile,BufRead */icglue/*/icglue_*.tcl,*/icglue,*/icsng2icglue setf icgluetcl
    " reorder existing tcl after icgluetcl group
    au! BufNewFile,BufRead *.tcl,*.tk,*.itcl,*.itk,*.jacl setf tcl
augroup END

" template types with (vim81) default as fallback
augroup filetypedetect
    " icglue templates
    au! BufNewFile,BufRead *.template*.c setf c_template
    au! BufNewFile,BufRead *.template*.c++,*.template*.cpp,*.template*.cc,*.template*.h++,*.template*.hpp,*.template*.h,*.template*.inl setf cpp_template
    " woof templates
    au! BufNewFile,BufRead *.wtf*.c setf c_wooftemplate
    au! BufNewFile,BufRead *.wtf*.c++,*.wtf*.cpp,*.wtf*.cc,*.wtf*.h++,*.wtf*.hpp,*.wtf*.h,*.wtf*.inl setf cpp_wooftemplate
    " redefine original filetypes
    au! BufNewFile,BufRead *.c++,*.cpp,*.cc,*.h++,*.hpp,*.inl setf cpp
    au! BufNewFile,BufRead *.c setf c
    au! BufNewFile,BufRead *.h call dist#ft#FTheader()
augroup END

augroup filetypedetect
    " icglue templates
    au! BufNewFile,BufRead *.template*.v,*.template.vh setf verilog_template
    au! BufNewFile,BufRead *.template*.sv,*.template.svh setf systemverilog_template
    " woof templates
    au! BufNewFile,BufRead *.wtf*.v,*.wtf.vh setf verilog_wooftemplate
    au! BufNewFile,BufRead *.wtf*.sv,*.wtf.svh setf systemverilog_wooftemplate
    " redefine original filetypes
    au! BufNewFile,BufRead *.v setf verilog
    au! BufNewFile,BufRead *.sv,*.svh setf systemverilog
augroup END

augroup filetypedetect
    au! BufNewFile,BufRead *.template*.tex setf tex_template
    au! BufNewFile,BufRead *.wtf*.tex setf tex_wooftemplate
    au! BufNewFile,BufRead *.tex call dist#ft#FTtex()
augroup END

augroup filetypedetect
    au! BufNewFile,BufRead *.template*.htm,*.template*.html setf html_template
    au! BufNewFile,BufRead *.wtf*.htm,*.wtf*.html setf html_wooftemplate
    au! BufNewFile,BufRead *.html,*.htm call dist#ft#FThtml()
augroup END

augroup filetypedetect
    au! BufNewFile,BufRead *.template*.csv,*.template*.txt setf icglue_template
    au! BufNewFile,BufRead *.wtf*.csv,*.wtf*.txt setf woof_template
    au! BufNewFile,BufRead *.txt
                \  if getline('$') !~ 'vim:.*ft=help'
                \|   setf text
                \| endif
augroup END
