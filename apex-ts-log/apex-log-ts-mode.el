;;; apex-log-ts-mode.el --- Apex log syntax mode powered by tree-sitter -*- lexical-binding: t; -*-

;; Code
(require 'treesit)

(defcustom apex-log-governor-table '(("Number of SOQL queries" "SOQL")
                                     ("Number of query rows" "SOQL rows") 
                                     ("Number of SOSL queries" "SOQL count")
                                     ("Number of DML statements" "DML")
                                     ("Number of Publish Immediate DML" "Pub DML")
                                     ("Number of DML rows" "DML rows")
                                     ("Maximum CPU time" "CPU time")
                                     ("Maximum heap size" "Heap size")  
                                     ("Mumber of callouts" "Callouts") 
                                     ("Number of Email Invocations" "Email") 
                                     ("Number of future calls" "Future")
                                     ("Number of queueable jobs added to the queue" "Jobs")
                                     ("Number of Mobile Apex push calls" "Apex call"))
  "Table convert governor limits to shorten version."
  :type 'list
  :group 'apex-log)

(defvar apex-log-ts-mode-header-format ""
  "Format for emacs header in `apex-log-ts-mode'.")

(defvar apex-log-ts-mode--indent-rules
  `((apex-log
     ((parent-is "log_header") column-0 0)))
  "Tree-sitter indent rules.")

(defvar apex-log-ts-mode--keywords
  '("APEX_CODE" "DEBUG" "APEX_PROFILING" "CALLOUT"
    "DB" "NBA" "SYSTEM" "VALIDATION" "VISUALFORCE" "WAVE"
    "WORKFLOW" "EXTERNAL")
  "Keywords use for Apex log statement.")

(defvar apex-log-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   ;; Apex log rules
   ;; :language 'apex-log
   ;; :feature 'comment
   ;; `((line_comment) @font-lock-comment-face
   ;;   (block_comment) @font-lock-comment-face)
   :language 'apex-log
   :feature 'version
   `((log_header (version)) @font-lock-constant-face)
   
   :language 'apex-log
   :feature 'event
   `((log_entry (timestamp (time) @font-lock-comment-face
                           (duration) @font-lock-number-face)
                (event_identifier) @font-lock-constant-face)
     ((location [(number) "EXTERNAL"] @font-lock-type-face))
     ((event_detail) @font-lock-variable-name-face)
     ((event_detail_value) @font-lock-string-face))

   :language 'apex-log
   :feature 'limit
   `((limit (identifier) @font-lock-builtin-face
            (number) @font-lock-regexp-face
            (number) @font-lock-constant-face))

   :language 'apex-log
   :override t
   :feature 'keyword
   `([,@apex-log-ts-mode--keywords] @font-lock-keyword-face)

   ;; :language 'apex-log
   ;; :override t
   ;; :feature 'bracket
   ;; '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :language 'apex-log
   :override t
   :feature 'delimiter
   '(["|" ":"] @font-lock-delimiter-face))
  "Tree-sitter font lock rules for `apex-log-ts-mode'.")

(defmacro apex-log-ts-mode--governor-convert (governor)
  "Convert GOVERNOR name."
  `(pcase ,governor
     ,@apex-log-governor-table))

;;;###autoload
(defun apex-log-ts-mode--header-mode ()
  "Inform governor limits."
  (let ((governor-limits (treesit-query-capture (treesit-buffer-root-node) '((limit) @limit))))
    (setq header-line-format (cl-loop for (_ . node) in governor-limits
                                      concat (format "%s: %s/%s "
                                                     (apex-log-ts-mode--governor-convert (s-trim (treesit-node-text (treesit-node-child-by-field-name node "name") t)))
                                                     (treesit-node-text (treesit-node-child-by-field-name node "consumed") t)
                                                     (treesit-node-text (treesit-node-child-by-field-name node "available") t))))))

(defun apex-log-ts-mode--setup ()
  "Setup tree-sitter for `apex-log-ts-mode'."

  ;; Electric
  (setq-local electric-indent-chars
              (append "{}():;," electric-indent-chars))

  (setq-local treesit-simple-indent-rules apex-log-ts-mode--indent-rules)
  
  (setq-local treesit-font-lock-settings apex-log-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((event keyword limit)
                (delimiter version)))

  ;; Imenu.
  ;; (setq-local treesit-simple-imenu-settings
  ;;             '(("Limit" "\\`limit\\'" nil apex-log-ts-mode--limit-usage)))

  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode apex-log-ts-mode prog-mode "Apex Log"
  "Major mode for editing Apex log files, powered by tree-sitter."
  :after-hook '(apex-log-ts-mode--header-mode)
  :group 'apex-log
  (unless (treesit-ready-p 'apex-log)
    (error "Tree-sitter for Apex log isn't available"))

  (treesit-parser-create 'apex-log)
  (apex-log-ts-mode--setup))

(add-to-list 'auto-mode-alist '("\\.log\\'" . apex-log-ts-mode))

(provide 'apex-log-ts-mode)

;;; apex-log-ts-mode.el ends here
