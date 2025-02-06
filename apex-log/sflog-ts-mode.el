 ;;; log-ts-mode.el --- Apex log syntax mode powered by tree-sitter -*- lexical-binding: t; -*-

;; Code
(require 'treesit)

(defvar sflog-ts-mode--keywords
  '("SELECT" "FROM" "LIMIT" "ORDER_BY"
    "GROUP_BY" "HAVING" "DESC" "ASC" "OR" "AND"
    "UPDATE" "EXCLUDES" "NULL" "WHERE" "WITH")
  "Keywords use for soql statement.")

(defvar sflog-ts-mode--operators
  '("=" "!=" "<>" ">" "<" "INCLUDES" "NOT_IN" "IN" "LIKE")
  "Operators use for soql statement.")

(defvar sflog-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   ;; SOQL rules
   :language 'sflog
   :feature 'comment
   `((line_comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face)
   
   :language 'sflog
   :override t
   :feature 'operator
   `([,@apex-ts-mode--soql-operators] @font-lock-operator-face)

   :language 'sflog
   :override t
   :feature 'keyword
   `([,@apex-ts-mode--soql-keywords] @font-lock-keyword-face)

   :language 'sflog
   :override t
   :feature 'definition
   '((field_identifier) @font-lock-property-use-face
     (storage_identifier) @font-lock-constant-face)

   :language 'sflog
   :override t
   :feature 'literal
   '((string_literal) @font-lock-string-face
     [(int) (decimal)] @font-number-face)

   :language 'sflog
   :override t
   :feature 'alias
   '((storage_alias (identifier) @font-lock-variable-name-face))

   :language 'sflog
   :override t
   :feature 'type
   '([(fields_type) (update_type)] @font-lock-type-face)
   
   :language 'sflog
   :override t
   :feature 'error
   '([(ERROR)] @font-lock-apex-error-face)

   :language 'sflog
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :language 'sflog
   :override t
   :feature 'literal
   '((string_literal) @font-lock-string-face
     [(int) (decimal)] @font-number-face)
   
   :language 'sflog
   :feature 'delimiter
   '((["," ":" ";"]) @font-lock-delimiter-face))
  "Tree-sitter font lock rules for `sflog-ts-mode'.")

(defvar sflog-ts-mode--indent-rules
  `((sflog
     ((parent-is "parser_output") column-0 0)))
  "Tree-sitter indent rules.")

(defun sflog-ts-mode--setup ()
  "Setup tree-sitter for `sflog-ts-mode'."

  ;; Electric
  (setq-local electric-indent-chars
              (append "{}():;," electric-indent-chars))

  (setq-local treesit-simple-indent-rules sflog-ts-mode--indent-rules)
  
  (setq-local treesit-font-lock-settings sflog-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comment)
                (keyword definition type alias)
                (literal error)
                (bracket delimiter operator)))

  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode sflog-ts-mode prog-mode "SOQL"
  "Major mode for editing SOQL, powered by tree-sitter."
  :group 'sflog
  (unless (treesit-ready-p 'sflog)
    (error "Tree-sitter for Apex isn't available"))

  (treesit-parser-create 'sflog)
  (sflog-ts-mode--setup))

(add-to-list 'auto-mode-alist '("\\.soql\\'" . sflog-ts-mode))

(provide 'sflog-ts-mode)
