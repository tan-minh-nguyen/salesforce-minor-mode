 ;;; soql-ts-mode.el -*- lexical-binding: t; -*- SOQL auto completion

;; Code
(require 'cl)
(require 'treesit)
(require 'soql-lsp)

(defvar apex-ts-mode--soql-keywords
  '("SELECT" "FROM" "LIMIT" "ORDER_BY"
    "GROUP_BY" "HAVING" "DESC" "ASC" "OR" "AND"
    "UPDATE" "EXCLUDES" "NULL" "WHERE" "WITH")
  "Keywords use for soql statement.")

(defvar apex-ts-mode--soql-operators
  '("=" "!=" "<>" ">" "<" "INCLUDES" "NOT" "IN" "LIKE")
  "Operators use for soql statement.")

(defvar soql-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   ;; SOQL rules
   ;; :language 'soql
   ;; :feature 'comment
   ;; `((line_comment) @font-lock-comment-face
   ;;   (block_comment) @font-lock-comment-face)
   
   :language 'soql
   :override t
   :feature 'operator
   `([,@apex-ts-mode--soql-operators] @font-lock-operator-face)

   :language 'soql
   :override t
   :feature 'keyword
   `([,@apex-ts-mode--soql-keywords] @font-lock-keyword-face)

   :language 'soql
   :override t
   :feature 'definition
   '((field_identifier) @font-lock-property-use-face
     (storage_identifier) @font-lock-constant-face)

   :language 'soql
   :override t
   :feature 'literal
   '((string_literal) @font-lock-string-face
     [(int) (decimal)] @font-number-face)

   :language 'soql
   :override t
   :feature 'alias
   '((storage_alias (identifier) @font-lock-variable-name-face))

   :language 'soql
   :override t
   :feature 'type
   '([(fields_type) (update_type)] @font-lock-type-face)
   
   :language 'soql
   :override t
   :feature 'error
   '([(ERROR)] @font-lock-apex-error-face)

   :language 'soql
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :language 'soql
   :override t
   :feature 'literal
   '((string_literal) @font-lock-string-face
     [(int) (decimal)] @font-number-face)
   
   :language 'soql
   :feature 'delimiter
   '((["," ":" ";"]) @font-lock-delimiter-face))
  "Tree-sitter font lock rules for `soql-ts-mode'.")

(defvar soql-ts-mode--indent-rules
  `((soql
     ((parent-is "parser_output") column-0 0)))
  "Tree-sitter indent rules.")

(defun soql-ts-mode--setup ()
  "Setup tree-sitter for `soql-ts-mode'."

  ;; Electric
  (setq-local electric-indent-chars
              (append "{}():;," electric-indent-chars))

  (setq-local treesit-simple-indent-rules soql-ts-mode--indent-rules)
  
  (setq-local treesit-font-lock-settings soql-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comment)
                (keyword definition type alias)
                (literal error)
                (bracket delimiter operator)))

  (treesit-major-mode-setup))

(defun soql-ts-mode-p ()
  "Check current context is apex."
  (eq major-mode 'soql-ts-mode))

(defun soql-ts-mode-minibuffer ()
  "Enable SOQL major mode in minibuffer."
  (setq-local minibuffer-allow-text-properties t))

;;;###autoload
(define-derived-mode soql-ts-mode prog-mode "SOQL"
  "Major mode for editing SOQL, powered by tree-sitter."
  :group 'soql
  (unless (treesit-ready-p 'soql)
    (error "Tree-sitter for Apex isn't available"))

  (treesit-parser-create 'soql)

  (soql-ts-mode--setup))

(add-to-list 'org-src-lang-modes '("soql" . soql-ts))

(when (treesit-ready-p 'soql)
  (add-to-list 'auto-mode-alist '("\\.soql\\'" . soql-ts-mode)))

(provide 'soql-ts-mode)
