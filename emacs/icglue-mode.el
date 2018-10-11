
;;; icglue-mode.el --- minimal mode for ICGlue files


;;; Commentary:

;; add to load-path and use require

;; possible extensions: better highlighting, auto-indent, menu, completion, verilog highlighting in code sections

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

(defconst icglue-keywords
      '(
        (".*\#.*\\|//.*$"                        . font-lock-comment-face)
        ("^ *M \\|^ *P \\|^ *S \\|^ *C \\|^ *R " . font-lock-type-face)
        ("-+>\\|<-+>\\|<-+"                      . font-lock-function-name-face)
        ("-w\\|-v\\|-d\\|-unit\\|-tree"          . font-lock-keyword-face)
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


(define-derived-mode icglue-mode tcl-mode
  (font-lock-add-keywords nil icglue-keywords)
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
