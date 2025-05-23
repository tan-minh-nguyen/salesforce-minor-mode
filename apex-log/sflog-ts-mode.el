 ;;; log-ts-mode.el --- Apex log syntax mode powered by tree-sitter -*- lexical-binding: t; -*-

;; Code
(require 'treesit)

(defvar sflog-ts-mode--keywords
  '("APEX_CODE" "DEBUG" "APEX_PROFILING" "CALLOUT"
    "DB" "NBA" "SYSTEM" "VALIDATION" "VISUALFORCE" "WAVE"
    "WORKFLOW" "EXTERNAL")
  "Keywords use for SF log statement.")

(defvar sflog-ts-mode--operators
  '()
  "Operators use for soql statement.")

(defvar sflog-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   ;; SF log rules
   ;; :language 'sflog
   ;; :feature 'comment
   ;; `((line_comment) @font-lock-comment-face
   ;;   (block_comment) @font-lock-comment-face)
   :language 'sflog
   :feature 'version
   `((log_header (version)) @font-lock-constant-face)
   
   :language 'sflog
   :feature 'event
   `((log_entry (timestamp (time) @font-lock-comment-face
                           (duration) @font-lock-number-face)
                (event_identifier) @font-lock-constant-face)
     ((location [(number) "EXTERNAL"] @font-lock-type-face))
     ((event_detail) @font-lock-variable-name-face)
     ((event_detail_value) @font-lock-string-face))

   :language 'sflog
   :feature 'limit
   `((limit (identifier) @font-lock-builtin-face
            (number) @font-lock-regexp-face
            (number) @font-lock-constant-face))

   :language 'sflog
   :override t
   :feature 'keyword
   `([,@apex-ts-mode--soql-keywords] @font-lock-keyword-face)

   :language 'sflog
   :override t
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :language 'sflog
   :override t
   :feature 'delimiter
   '((["|" ":"]) @font-lock-delimiter-face))
  "Tree-sitter font lock rules for `sflog-ts-mode'.")

(defvar sflog-ts-mode-header-format ""
  "Format for emacs header in `sflog-ts-mode'.")

(defvar sflog-ts-mode--indent-rules
  `((sflog
     ((parent-is "parser_output") column-0 0)))
  "Tree-sitter indent rules.")

(defun sflog-ts-mode--header-mode ()
  "Format log header."
  (let ((governor-limits (treesit-query-capture (treesit-buffer-root-node) '((limit (identifier) @limit-name
                                                                                    (number) @limit-value) @limit))))
    (setq sflog-ts-mode-header-format (cl-loop for limit in governor-limits
                                               concat (concat "%s: %s"
                                                              (treesit-node-text (assoc-default 'limit-name limit))
                                                              (treesit-node-text (assoc-default 'limit-value limit)))))))

(defun sflog-ts-mode--setup ()
  "Setup tree-sitter for `sflog-ts-mode'."

  ;; Electric
  (setq-local electric-indent-chars
              (append "{}():;," electric-indent-chars))

  (setq-local treesit-simple-indent-rules sflog-ts-mode--indent-rules)
  
  (setq-local treesit-font-lock-settings sflog-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((event keyword limit)
                (delimiter version)))

  ;; Imenu.
  ;; (setq-local treesit-simple-imenu-settings
  ;;             '(("Limit" "\\`limit\\'" nil sflog-ts-mode--limit-usage)))

  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode sflog-ts-mode prog-mode "SFLog"
  "Major mode for editing SF log, powered by tree-sitter."
  :group 'sflog
  (unless (treesit-ready-p 'sflog)
    (error "Tree-sitter for Apex isn't available"))

  (treesit-parser-create 'sflog)
  (sflog-ts-mode--setup)
  (sflog-ts-mode--header-mode)
  (when sflog-ts-mode
    (cond ((null header-line-format)
           (setq header-line-format sflog-ts-mode-header-format))
          (t (add-to-list header-line-format sflog-ts-mode-header-format)))))

(add-to-list 'auto-mode-alist '("\\.log\\'" . sflog-ts-mode))

(provide 'sflog-ts-mode)
