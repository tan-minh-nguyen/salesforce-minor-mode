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
  `(javascript
    ((parent-is ,(regexp-opt '("variable_declaration" "function_declaration"))) column-0 lwc-js-ts-mode--indent-offset)
    ((node-is "statement_block") prev-sibling 2)
    ((parent-is "statement_block") parent-bol lwc-js-ts-mode--indent-offset)
    ((parent-is "object") parent lwc-js-ts-mode--indent-offset)
    ((field-name "object") parent lwc-js-ts-mode--indent-offset)
    ((node-is ,(regexp-opt '("property_identifier" "return_statement")) parent-bol lwc-js-ts-mode--indent-offset))
    ((node-is "}") parent-bol 0)
    (no-node parent 0))
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

(defun lwc-js-ts-mode--css-setup ()
  "Setup font lock settings for css."
  (when-let ((_ (treesit-ready-p 'css t)))

    (treesit-range-rules
     :embed 'css
     :host 'html
     '((style_element (raw_text) @capture)))))

;; (defun lwc-js-ts-mode--js-setup ()
;;   "Setup font lock settings for javascript."
;;   (when-let (_ (treesit-ready-p 'javascript t))

;;     (treesit-range-rules
;;      :embed 'javascript
;;      :host 'html
;;      '((script_element (raw_text) @capture)))))

(defun lwc-js-ts-mode--js-file ()
  "JS settings of tree-sitter for `lwc-js-ts-mode'."

  (treesit-parser-create 'javascript)

  ;; Font-lock.
  (setq-local treesit-font-lock-settings
              `(,@lwc-js-ts-mode--js-font-lock-settings))
  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (keyword literal regex identifier)
                (declaration operator constant function)
                (bracket delimiter)))

  ;; Electric

  ;; Indent.
  (setq-local treesit-simple-indent-rules `((,@lwc-js-ts-mode--js-indent-rules)))

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
  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode lwc-js-ts-mode fundamental-mode "lwc"
  "Major mode use tree-sitter for Visualforce page, powered by tree-sitter."
  :group 'lwc-js-ts-mode

  (unless (treesit-ready-p 'javascript t)
    (error "Tree-sitter for js isn't available."))
  (lwc-js-ts-mode--js-file))

(provide 'lwc-js-ts-mode)
