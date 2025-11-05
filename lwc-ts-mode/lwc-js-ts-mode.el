;;; LWC js mode -- js tree-sitter support for LWC js file -*- lexical-binding: t; -*-

;;; Code
(require 'lwc-ts-common)

(defcustom lwc-js-ts-mode--indent-offset 4
  "LWC indention offset."
  :group 'lwc
  :type 'integer
  :safe 'integerp)

(defvar lwc-js-ts-mode--regex-capture-expression "{[^}]*}"
  "Regex use for capture LWC expression.")

(defvar lwc-js-ts-mode--js-operators
  '("!=" "&&" "||" "==" "+"
    "-" "*" "/" "===" "/=" "+="
    ">" "<" "<=" ">=" "|=" "&="
    "-=" "*=" "|" "^")
  "JS operators for LWC.")


(defvar lwc-js-ts-mode--js-keywords
  '("function" "if" "switch" "case"
    "for" "break" "continue" "return"
    "let" "const" "var" "of" "in" "else"
    "new" "export" "import" "default" "class" "do" 
    "while" "await" "throw" "try" "catch"
    "extends" "static" "from" "get" "set")
  "JS keywords for LWC.")

(defvar lwc-js-ts-mode--js-font-lock-settings
  (treesit-font-lock-rules
   ;; javascript font lock rules
   :language 'javascript
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'javascript
   :feature 'constant
   '((true) @font-lock-constant-face
     (false) @font-lock-constant-face)

   :language 'javascript
   :feature 'keyword
   `([,@lwc-js-ts-mode--js-keywords  
      (labeled_statement (statement_identifier))] @font-lock-keyword-face
     (member_expression object: (this) @font-lock-keyword-face))
   
   :language 'javascript
   :feature 'expression
   '((member_expression (identifier) @font-lock-function-call-face)
     (member_expression (property_identifier) @font-lock-property-name-face))

   :language 'javascript   
   :feature 'declaration
   '((class_declaration [(identifier) @font-lock-builtin-face
                         (class_heritage (identifier) @font-lock-builtin-face)]))

   :language 'javascript
   :override t
   :feature 'function
   '((function_declaration
      (identifier) @font-lock-function-name-face)
     (method_definition 
      (property_identifier) @font-lock-funcation-name-face)
     (call_expression function: [(identifier) @font-lock-function-call-face
                                 (member_expression 
                                  property: (property_identifier) @font-lock-function-call-face)]))
   
   :language 'javascript
   :feature 'identifier   
   '((identifier) @font-lock-type-face
     (new_expression constructor: (identifier) @font-lock-builtin-face)
     (decorator (identifier) @font-lock-keyword-face))


   :language 'javascript
   :feature 'regex
   `((regex
      "/" @font-lock-regexp-grouping-backslash
      (regex_pattern) @font-lock-regexp-face
      "/" @font-lock-regexp-grouping-backslash
      (regex_flags) @font-lock-regexp-grouping-construct))

   :language 'javascript
   :feature 'operator
   `([,@lwc-js-ts-mode--js-operators] @font-lock-operator-face)

   :language 'javascript
   :override t
   :feature 'operator
   '(["!"] @font-lock-negation-face)

   :language 'javascript
   :feature 'literal
   '((string) @font-lock-string-face
     (number) @font-lock-number-face
     (property_identifier) @font-lock-property-name-face)

   :language 'javascript
   :feature 'delimiter
   '([":" ";" "."] @font-lock-delimiter-face)

   :language 'javascript
   :feature 'bracket
   '(["{" "}" "(" ")" "[" "]"] @font-lock-bracket-face))
  "Tree-sitter Javascipt font-lock settings for `lwc-js-ts-mode'.")


(defvar lwc-js-ts-mode--js-indent-rules
  `(javascript ((parent-is "program") parent-bol 0) ((node-is "}") parent-bol 0)
               ((node-is ")") parent-bol 0) ((node-is "]") parent-bol 0)
               ((node-is ">") parent-bol 0)
               ((and (parent-is "comment") c-ts-common-looking-at-star)
                c-ts-common-comment-start-after-first-star -1)
               ((parent-is "comment") prev-adaptive-prefix 0)
               ((parent-is "ternary_expression") parent-bol js-indent-level)
               ((parent-is "member_expression") parent-bol js-indent-level)
               ((node-is "switch_\\(?:case\\|default\\)") parent-bol 0)
               ((node-is "statement_block") parent-bol js-indent-level)
               ((parent-is "named_imports") parent-bol js-indent-level)
               ((parent-is "statement_block") parent-bol js-indent-level)
               ((parent-is "variable_declarator") parent-bol js-indent-level)
               ((parent-is "arguments") parent-bol js-indent-level)
               ((parent-is "array") parent-bol js-indent-level)
               ((parent-is "formal_parameters") parent-bol js-indent-level)
               ((parent-is "template_string") no-indent)
               ((parent-is "template_substitution") parent-bol js-indent-level)
               ((parent-is "object_pattern") parent-bol js-indent-level)
               ((parent-is "object") parent-bol js-indent-level)
               ((parent-is "pair") parent-bol js-indent-level)
               ((parent-is "arrow_function") parent-bol js-indent-level)
               ((parent-is "parenthesized_expression") parent-bol js-indent-level)
               ((parent-is "binary_expression") parent-bol js-indent-level)
               ((parent-is "class_body") parent-bol js-indent-level)
               ((parent-is "switch_\\(?:case\\|default\\)") parent-bol
                js-indent-level)
               ((parent-is "statement_block") parent-bol js-indent-level)
               ((match "while" "do_statement") parent-bol 0)
               ((match "else" "if_statement") parent-bol 0)
               ((parent-is
                 "\\(?:do\\|for\\(?:_in\\)?\\|if\\|while\\)_statement\\|else_clause")
                parent-bol js-indent-level)
               ((match "<" "jsx_text") parent 0)
               ((parent-is "jsx_text") parent js-indent-level)
               ((node-is "jsx_closing_element") parent 0)
               ((match "jsx_element" "statement") parent js-indent-level)
               ((parent-is "jsx_element") parent js-indent-level)
               ((parent-is "jsx_text") parent-bol js-indent-level)
               ((parent-is "jsx_opening_element") parent js-indent-level)
               ((parent-is "jsx_expression") parent-bol js-indent-level)
               ((match "/" "jsx_self_closing_element") parent 0)
               ((parent-is "jsx_self_closing_element") parent js-indent-level)
               (no-node parent-bol 0))
  "Indent rules for javascript on lwc component.")

;; Config indent rules is apply for Visualforce page,
;; TODO HTML - indent rules offset is 2
;; TODO Javascript
;; TODO Css
;; (defvar lwc-js-ts-mode--indent-rules
;;   `((,@lwc-js-ts-mode--html-indent-rules)
;;     (,@lwc-js-ts-mode--css-indent-rules)
;;     (,@lwc-js-ts-mode--js-indent-rules))
;;   "Tree-sitter indent rules for `lwc-js-ts-mode'.")

;; Imenu
;; Add language parameter to configuration dynamic parser language
;; (defalias #'treesit-simple-imenu #'lwc-js-ts-mode--treesit-simple-imenu
;;   "Simple imenu for `visualforce-ts-mode'")

(defun lwc-js-ts-mode--treesit-simple-imenu ()
  "Imenu index for `visualforce-ts-mode'"
  (let ((root (treesit-buffer-root-node)))
    (mapcan (lambda (setting)
              (pcase-let ((`(,category ,regexp ,pred ,name-fn ,language)
                           setting))
                (when-let* ((tree (treesit-induce-sparse-tree
                                   (if language
                                       (treesit-parser-root-node (treesit-parser-create language))
                                     root)
                                   regexp))
                            (index (treesit--simple-imenu-1
                                    tree pred name-fn)))
                  (if category
                      (list (cons category index))
                    index))))
            treesit-simple-imenu-settings)))

(defun lwc-js-mode-auto ()
  "Auto enable majore-mode for file in Salesforce project."
  (when (lwc-ts-mode--lwc-file-p)
    (lwc-js-ts-mode)))

(defun lwc-ts-mode--js ()
  "JS settings of tree-sitter for `lwc-js-ts-mode'."

  (treesit-parser-create 'javascript)

  ;; Electric-indent.
  (setq-local electric-indent-chars
              (append "{}():;,<>/" electric-indent-chars)) ;FIXME: js2-mode adds "[]*".

  (setq-local electric-layout-rules
	          '((?\; . after) (?\{ . after) (?\} . before)))
  ;; Font-lock.
  (setq-local treesit-font-lock-settings
              `(,@lwc-js-ts-mode--js-font-lock-settings))
  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (keyword literal regex identifier)
                (declaration operator constant function)
                (bracket delimiter)))

  ;; Indent.
  (setq-local treesit-simple-indent-rules `((,@lwc-js-ts-mode--js-indent-rules)))

  (setq-local treesit-defun-name-function #'js--treesit-defun-name)

  ;; Navigation.
  (setq-local treesit-defun-type-regexp
              (rx (or "class_declaration"
                     "method_definition"
                     "function_declaration"
                     "lexical_declaration")))

  ;; Imenu
  (setq-local treesit-simple-imenu-settings
              `(("Element" lwc-js-ts-mode--element-p nil lwc-ts-mode--format-element html)
                ;; ("Component" "\\`element\\'" nil visualforce-ts-mode--find-component)))
                ("Expression" lwc-js-ts-mode--expression-p nil lwc-ts-mode--format-expression html)
                ;; JS
                ("Variable" "\\`lwc_declaration\\'" nil (lambda (node)
                                                          (treesit-node-text (treesit-node-child-by-field-name node "name"))))
                ("Function" "\\`function_declaration\\'" nil (lambda (node)
                                                               (treesit-node-text (treesit-node-child-by-field-name node "name"))))))

  ;; (setq treesit--indent-verbose t)
  )

;;;###autoload
(define-derived-mode lwc-js-ts-mode fundamental-mode "lwc js"
  "Major mode use tree-sitter for Visualforce page, powered by tree-sitter."
  :group 'lwc
  (unless (treesit-ready-p 'javascript t)
    (error "Tree-sitter for html isn't available."))
  (lwc-ts-mode--js)

  (treesit-major-mode-setup)

  (setq-local eglot-workspace-configuration
              '(:lwc-ts-mode (:documentSelector [(:language "html" :scheme "file")
                                                 (:language "javascript" :scheme "file")
                                                 (:language "typescript" :scheme "file")]))))

(add-to-list 'auto-mode-alist '("\\.js\\'" . lwc-js-mode-auto))

(provide 'lwc-js-ts-mode)
