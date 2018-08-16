;;; icglue-mode.el --- minimal mode for ICGlue files


;;; Commentary:

;; add to load-path and use require

;; possible extensions: better highlighting, reuse font-lock from tcl-mode, auto-indent

;; available faces
;; font-lock-constant-face
;; font-lock-type-face
;; font-lock-builtin-face
;; font-lock-preprocessor-face
;; font-lock-string-face
;; font-lock-doc-face
;; font-lock-negation-char-face
;; font-lock-keyword-face
;; font-lock-variable-name-face
;; font-lock-function-name-face

;;; Code:


;;;;;;;;;; from tcl-mode.el ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar tcl-builtin-list
  '("after" "append" "array" "bgerror" "binary" "catch" "cd" "clock"
    "close" "concat" "console" "dde" "encoding" "eof" "exec" "expr"
    "fblocked" "fconfigure" "fcopy" "file" "fileevent" "flush"
    "format" "gets" "glob" "history" "incr" "info" "interp" "join"
    "lappend" "lindex" "linsert" "list" "llength" "load" "lrange"
    "lreplace" "lsort" "namespace" "open" "package" "pid" "puts" "pwd"
    "read" "regexp" "registry" "regsub" "rename" "scan" "seek" "set"
    "socket" "source" "split" "string" "subst" "tell" "time" "trace"
    "unknown" "unset" "vwait")
  "List of Tcl commands.  Used only for highlighting.
Call `tcl-set-font-lock-keywords' after changing this list.
This list excludes those commands already found in `tcl-proc-list' and
`tcl-keyword-list'.")

(defvar tcl-proc-list
  '("proc" "method" "itcl_class" "body" "configbody" "class")
  "List of commands whose first argument defines something.
This exists because some people (eg, me) use `defvar' et al.
Call `tcl-set-proc-regexp' and `tcl-set-font-lock-keywords'
after changing this list.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



(defconst icglue-keywords
      '(
        (".*\#.*\\|//.*$"              . font-lock-comment-face)
        ("^M \\|^P \\|^S \\|^C \\|^R " . font-lock-type-face)
        ("-+>\\|<-+>\\|<-+"            . font-lock-function-name-face)
        ("-w\\|-v\\|-unit\\|-tree"     . font-lock-keyword-face)
        ("list"  . 'font-lock-builtin-face)
        )
      ;; "Keywords for ICGlue"
       )

(defvar icglue-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Populate the syntax TABLE.
    (modify-syntax-entry ?\\ "\\" table)
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?% "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?| "." table)
    (modify-syntax-entry ?` "w" table)  ; ` is part of definition symbols in Verilog
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?\' "." table)
    ;; comment sytax
    ;; (modify-syntax-entry ?\# ". 12b" table)

    ;; (modify-syntax-entry ?\# ". 14c" table)

    (modify-syntax-entry ?# "< 14b" table)  ; # single-line start

    ;; Set up TABLE to handle block and line style comments.
    (modify-syntax-entry ?/  ". 14b" table)
    (modify-syntax-entry ?*  ". 23"   table)
    (modify-syntax-entry ?\n "> b"  table)
    (modify-syntax-entry ?\^M "> b"   table)
  table)
  "Syntax table used in ICGlue mode buffers.")

(require 'compile)

(defvar icglue-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-cc" 'compile)
    map)
  "Keymap used in ICGlue mode.")

(require 'prog-mode)

(define-derived-mode icglue-mode prog-mode
  (setq font-lock-defaults '(icglue-keywords))
  (setq mode-name "ICGlue Mode")

  (set (make-local-variable 'comment-multi-line) nil)

  (set (make-local-variable 'comment-start) "#")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'comment-start-skip)
       (concat (regexp-quote comment-start) "+\\s *"))
  (set (make-local-variable 'compile-command) (format "icglue %s " (file-name-nondirectory buffer-file-name)))
  (let ((map (make-sparse-keymap))) ; as described in info pages, make a map
    (set-keymap-parent map icglue-mode-map)
    )
  (set-syntax-table icglue-mode-syntax-table)
  )

(provide 'icglue-mode)

;;; icglue-mode.el ends here
