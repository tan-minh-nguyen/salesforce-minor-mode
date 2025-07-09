;;; apex-ts-mode.el --- tree-sitter support for Apex -*- lexical-binding: t -*-

;; Copyright (C) 2022-2023 Free Software Foundation, Inc.

;; Author     : Tan Nguyen
;; Maintainer : Tan Nguyen
;; Created    : January 2024
;; Keywords   : apex languages tree-sitter

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;


;;SOQL highlight syxtax base on https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_typos.htm

;;; Code:

(require 'treesit)
(eval-when-compile (require 'rx))
(require 'c-ts-common) ; For comment indent and filling.
(require 'cl-macs)
(require 'apex-lsp)
(require 'apex-ai)
(when (require 'dape nil 'noerror)
  (require 'apex-dap))

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-induce-sparse-tree "treesit.c")
(declare-function treesit-node-start "treesit.c")
(declare-function treesit-node-type "treesit.c")
(declare-function treesit-node-child-by-field-name "treesit.c")
(declare-function treesit-node-child-by-field-name "treesit.c")
(declare-function treesit-query-capture "treesit.c")

(defcustom apex-ts-mode-indent-offset '4
  "Number of spaces for each indentation step in `apex-ts-mode'."
  :type 'integer
  :safe 'integerp
  :group 'apex)

;; Settings custom faces for `apex-ts-mode'
(defface font-lock-apex-error
  '((t :foreground "red" :underline t))
  "Face used for highlight syntax errors in `apex-ts-mode'")

(defvar font-lock-apex-error-face 'font-lock-apex-error)

(defvar apex-ts-mode--root-dir (file-name-directory load-file-name)
  "Root directory.")

(defvar apex-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    ;; Taken from the cc-langs version
    (modify-syntax-entry ?_  "_"     table)
    (modify-syntax-entry ?\\ "\\"    table)
    (modify-syntax-entry ?+  "."     table)
    (modify-syntax-entry ?-  "."     table)
    (modify-syntax-entry ?=  "."     table)
    (modify-syntax-entry ?%  "."     table)
    (modify-syntax-entry ?<  "."     table)
    (modify-syntax-entry ?>  "."     table)
    (modify-syntax-entry ?&  "."     table)
    (modify-syntax-entry ?|  "."     table)
    (modify-syntax-entry ?\240 "."   table)
    (modify-syntax-entry ?/  ". 124b" table)
    (modify-syntax-entry ?*  ". 23"   table)
    (modify-syntax-entry ?\n "> b"  table)
    (modify-syntax-entry ?\^m "> b" table)
    (modify-syntax-entry ?@ "'" table)
    table)
  "Syntax table for `apex-ts-mode'.")

(defvar apex-ts-mode--indent-rules
  `((apex
     ((parent-is "parser_output") column-0 0)
     ((node-is "}") column-0 c-ts-common-statement-offset)
     ((node-is ")") parent-bol 0)
     ((node-is "else") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((and (parent-is "comment") c-ts-common-looking-at-star)
      c-ts-common-comment-start-after-first-star -1)
     ((parent-is "comment") prev-adaptive-prefix 0)
     ((parent-is "text_block") no-indent)
     ((parent-is "class_body") column-0 c-ts-common-statement-offset)
     ((parent-is "array_initializer") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "annotation_type_body") column-0 c-ts-common-statement-offset)
     ((parent-is "interface_body") column-0 c-ts-common-statement-offset)
     ((parent-is "constructor_body") column-0 c-ts-common-statement-offset)
     ((parent-is "enum_body_declarations") parent-bol 0)
     ((parent-is "enum_body") column-0 c-ts-common-statement-offset)
     ((parent-is "switch_block") column-0 c-ts-common-statement-offset)
     ((query "(method_declaration (block _ @indent))") parent-bol apex-ts-mode-indent-offset)
     ((query "(method_declaration (block (_) @indent))") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "local_variable_declaration") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "expression_statement") parent-bol apex-ts-mode-indent-offset)
     ((match "type_identifier" "field_declaration") parent-bol 0)
     ((parent-is "field_declaration") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "variable_declarator") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "method_invocation") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "function_definition") parent-bol 0)
     ((parent-is "conditional_expression") first-sibling 0)
     ((parent-is "assignment_expression") parent-bol 2)
     ((parent-is "binary_expression") parent 0)
     ((parent-is "parenthesized_expression") first-sibling 1)
     ((parent-is "argument_list") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "modifiers") parent-bol 0)
     ((parent-is "formal_parameters") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "formal_parameter") parent-bol 0)
     ((parent-is "if_statement") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "for_statement") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "while_statement") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "switch_statement") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "case_statement") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "do_statement") parent-bol apex-ts-mode-indent-offset)
     ((parent-is "block") column-0 c-ts-common-statement-offset)))
  "Tree-sitter indent rules.")

(defvar apex-ts-mode--apex-keywords
  '("break" "catch"
    "class" "continue" "default" "do" "else"
    "enum" "extends" "final" "finally"
    "for" "if" "implements" "instanceof"
    "interface" "new" "private" "protected"
    "public" "return" "static" "switch" "throw" "try" "while")
  "Apex keywords for tree-sitter font-locking.")

(defvar apex-ts-mode--operators
  '("+" ":" "++" "-" "--" "&" "&&" "|" "||" "="
    "!=" "==" "*" "/" "%" "<" "<=" ">" ">="
    "-=" "+=" "*=" "/=" "%=" "^" "^="
    "|=" "~" ">>" ">>>" "<<" "?" "&=")
  "Apex operators for tree-sitter font-locking.")


(defvar apex-ts-mode--soql-keywords
  '("SELECT" "FROM" "LIMIT" "ORDER_BY"
    "GROUP_BY" "HAVING" "DESC" "ASC" "OR" "AND"
    "UPDATE" "EXCLUDES" "NULL" "WHERE" "WITH")
  "Keywords use for soql statement.")

(defvar apex-ts-mode--soql-operators
  '("=" "!=" "<>" ">" "<" "INCLUDES" "NOT_IN" "IN" "LIKE")
  "Operators use for soql statement.")

(defun apex-ts-mode--string-highlight-helper ()
  "Returns, for strings, a query based on what is supported by
te available version of Tree-sitter for Apex."
  (condition-case nil
      (progn (treesit-query-capture 'apex '((text_block) @font-lock-string-face))
             `((string_literal) @font-lock-string-face
               (text_block) @font-lock-string-face))
    (error
     `((string_literal) @font-lock-string-face))))

(defvar apex-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'apex
   :feature 'comment
   `((line_comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face)

   :language 'apex
   :feature 'constant
   `((identifier) @font-lock-constant-face
     ;; (:match "[A-Z_][A-Z_\\d]*\\'" @font-lock-constant-face))
     [(boolean)] @font-lock-constant-face)

   :language 'apex
   :override t
   :feature 'keyword
   `([,@apex-ts-mode--apex-keywords          ;
      (this)
      (super)] @font-lock-keyword-face
      (labeled_statement
       (identifier) @font-lock-keyword-face)
      (modifiers
       (modifier) @font-lock-keyword-face)
      (dml_expression
       (dml_type) @font-lock-keyword-face))

   :language 'apex
   :override t
   :feature 'operator
   `([,@apex-ts-mode--operators] @font-lock-operator-face
     "@" @font-lock-constant-face)

   :language 'apex
   :override t
   :feature 'annotation
   `((annotation
      name: (identifier) @font-lock-constant-face))

   :language 'apex
   :feature 'string
   (apex-ts-mode--string-highlight-helper)

   :language 'apex
   :override t
   :feature 'literal
   `((null_literal) @font-lock-constant-face
     (int) @font-lock-number-face
     (decimal_floating_point_literal) @font-lock-number-face)

   :language 'apex
   :override t
   :feature 'type
   '((interface_declaration
      name: (identifier) @font-lock-type-face)

     (class_declaration
      name: (identifier) @font-lock-type-face)

     (enum_declaration
      name: (identifier) @font-lock-type-face)

     (constructor_declaration
      name: (identifier) @font-lock-type-face)

     (field_access
      object: (identifier) @font-lock-type-face)

     (type_identifier) @font-lock-type-face

     [(void_type)] @font-lock-type-face)

   :language 'apex
   :override t
   :feature 'definition
   `((method_declaration
      name: (identifier) @font-lock-function-name-face)

     (variable_declarator
      name: (identifier) @font-lock-variable-name-face)

     (formal_parameter
      name: (identifier) @font-lock-variable-name-face)

     (catch_formal_parameter
      name: (identifier) @font-lock-variable-name-face))

   :language 'apex
   :override t
   :feature 'expression
   '((method_invocation
      object: (identifier) @font-lock-variable-use-face)

     (method_invocation
      name: (identifier) @font-lock-function-call-face)

     (argument_list (identifier) @font-lock-variable-name-face)

     (expression_statement (identifier) @font-lock-variable-use-face))

   :language 'apex
   :override t
   :feature 'error
   '([(ERROR)] @font-lock-apex-error-face)

   :language 'apex
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :language 'apex
   :feature 'delimiter
   '((["," ":" ";"]) @font-lock-delimiter-face)

   ;; SOQL rules
   :language 'apex
   :override t
   :feature 'operator
   `([,@apex-ts-mode--soql-operators] @font-lock-operator-face)

   :language 'apex
   :override t
   :feature 'keyword
   `([,@apex-ts-mode--soql-keywords] @font-lock-keyword-face)

   :language 'apex
   :override t
   :feature 'definition
   '((field_identifier) @font-lock-property-use-face
     (storage_identifier) @font-lock-constant-face)

   :language 'apex
   :override t
   :feature 'literal
   '((string_literal) @font-lock-string-face
     [(int) (decimal)] @font-number-face)

   :language 'apex
   :override t
   :feature 'expression
   '((fields_expression) @font-lock-expression-face)

   :language 'apex
   :override t
   :feature 'alias
   '((storage_alias (identifier) @font-lock-variable-name-face))

   :language 'apex
   :override t
   :feature 'type
   '([(fields_type) (update_type)] @font-lock-type-face))
  "Tree-sitter font-lock settings for `apex-ts-mode'.")

(defun apex-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (pcase (treesit-node-type node)
    ((or "method_declaration"
        "class_declaration"
        "interface_declaration")
     (treesit-node-text
      (treesit-node-child-by-field-name node "name")
      t))))

(defun apex-ts-mode--variable-name (node)
  "Return the variable name of NODE."
  (treesit-node-text (apex-ts-mode--field-name-recursion "declarator.name" node)))

(defun apex-ts-mode--declaration-name (node)
  "Get name of class NODE."
  (let ((declaration-name (treesit-node-text (treesit-node-child-by-field-name node "name") t))
        (super-class (treesit-node-text (treesit-node-child-by-field-name node "superclass")))
        (interfaces-class (treesit-node-text (treesit-node-child-by-field-name node "interfaces")))
        (class-declaration (string= (treesit-node-type node) "class_declaration")))

    (concat declaration-name
            (if super-class
                (concat " " super-class)
              "")
            (if interfaces-class
                (concat " " interfaces-class)
              ""))))

(defun apex-ts-mode--field-name-recursion (path node)
  "Node recursion to get last field name."
  (when (null node)
    (error "current node is nil: %S." path))
  (when-let ((path-splited (string-split path "\\.")))

    (cond ((length> path-splited 1)
           (apex-ts-mode--field-name-recursion (string-join (cdr path-splited) ".")
                                               (treesit-node-child-by-field-name node (car path-splited))))
          (t
           (treesit-node-child-by-field-name node (car path-splited))))))

(defun apex-ts-mode--soql-embeded ()
  "Auto hints for embedded SOQL statement."
  (require 'soql-company nil 'noerror)
  (add-hook 'eglot-managed-mode-hook #'soql-company-setup))

(defun apex-ts-mode-p ()
  "Check current context is apex."
  (eq major-mode 'apex-ts-mode))

(defun apex-ts-mode-setup ()
  "Initialize tree-siter config for `apex-ts-mode'."

  ;; Comments.
  (c-ts-common-comment-setup)

  ;; Indent.
  (setq-local c-ts-common-indent-type-regexp-alist
              `((block . ,(rx (or "class_body"
                                  "array_initializer"
                                  "constructor_body"
                                  "interface_body"
                                  "enum_body"
                                  "switch_block"
                                  "block")))
                (close-bracket . "}")
                (if . "if_statement")
                (else . ("if_statement" . "alternative"))
                (for . "for_statement")
                (while . "while_statement")
                (do . "do_statement")))

  (setq-local c-ts-common-indent-offset 'apex-ts-mode-indent-offset)
  (setq-local treesit-simple-indent-rules apex-ts-mode--indent-rules)

  ;; Electric
  (setq-local electric-indent-chars
              (append "{}()<>*/:;," electric-indent-chars))

  ;; Navigation.
  (setq-local treesit-defun-type-regexp
              (regexp-opt '("method_declaration"
                            "class_declaration"
                            "interface_declaration"
                            "enum_declaration"
                            "constructor_declaration")))
  ;; Clean-up
  (setq-local treesit-defun-name-function #'apex-ts-mode--defun-name)

  ;; Font-lock.
  (setq-local treesit-font-lock-settings apex-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '(( comment definition)
                ( constant keyword string type alias)
                ( annotation expression literal soql sosl error)
                ( bracket delimiter operator)))

  ;; Imenu.
  (setq-local treesit-simple-imenu-settings
              '(("Class" "\\`class_declaration\\'" nil apex-ts-mode--declaration-name)
                ("Interface" "\\`interface_declaration\\'" nil apex-ts-mode--declaration-name)
                ("Enum" "\\`enum_declaration\\'" nil apex-ts-mode--declaration-name)
                ("Method" "\\`method_declaration\\'" nil nil)
                ("Field Variable" "\\`field_declaration\\'" nil apex-ts-mode--variable-name)
                ("Local Variable" "\\`local_variable_declaration\\'" nil apex-ts-mode--variable-name)

                ("Sobject" "\\`storage_identifier\\'" nil (lambda (NODE)
                                                            (treesit-node-text NODE)))))
  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode apex-ts-mode prog-mode "Apex"
  "Major mode for editing Apex, powered by tree-sitter."
  :group 'apex
  :syntax-table apex-ts-mode--syntax-table

  (unless (treesit-ready-p 'apex)
    (error "Tree-sitter for Apex isn't available"))

  (treesit-parser-create 'apex)

  (apex-ts-mode-setup))

(when (treesit-ready-p 'apex)
  (add-to-list 'auto-mode-alist '("\\.apex\\'" . apex-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.cls\\'" . apex-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.trigger\\'" . apex-ts-mode)))

(add-hook 'apex-ts-mode-hook #'apex-ts-mode--soql-embeded)

;; Imenu
(defmacro apex-ts-mode--define-source-annotate (&optional text)
  "Define annotate for consult source."
  `(lambda (cand)
     (let* (;; Return type display
            (type-text (propertize (or (plist-get cand :type)
                                       "Void")
                                   'face 'font-lock-type-face)))
       type-text)))
             
(defmacro apex-ts-mode--define-source-action ()
  "Define action for consult source."
  `(lambda (cand) 
     (goto-char (plist-get cand :marker))))


;; Consult sources
(defvar apex-ts-mode--consult-source-field 
  `(:name "Field"
          :narrow ?f
          :category Field
          :face font-lock-variable-name-face
          :state ,#'apex-ts-mode--consult-preview
          :annotate ,(apex-ts-mode--define-source-annotate)
          :action ,(apex-ts-mode--define-source-action)))
                   
                     

(defvar apex-ts-mode--consult-source-method 
  `(:name "Method"
          :narrow ?m
          :category Method
          :face font-lock-function-name-face
          :state ,#'apex-ts-mode--consult-preview
          :annotate ,(apex-ts-mode--define-source-annotate)
          :action ,(apex-ts-mode--define-source-action)))

(defvar apex-ts-mode--consult-source-class 
  `(:name "Class"
          :narrow ?c
          :category Class 
          :face font-lock-type-face
          :state ,#'apex-ts-mode--consult-preview
          :annotate ,(apex-ts-mode--define-source-annotate)
          :action ,(apex-ts-mode--define-source-action)))

(defvar apex-ts-mode--consult-source-property
  `(:name "Property"
           :narrow ?p
           :category Property
           :face font-lock-variable-name-face
           :state ,#'apex-ts-mode--consult-preview
           :annotate ,(apex-ts-mode--define-source-annotate)
           :action ,(apex-ts-mode--define-source-action)))

(defvar apex-ts-mode--consult-source-constructor
  `(:name "Constructor"
           :narrow ?s
           :category Constructor
           :face font-lock-type-face
           :state ,#'apex-ts-mode--consult-preview
           :annotate ,(apex-ts-mode--define-source-annotate)
           :action ,(apex-ts-mode--define-source-action)))

(defvar apex-ts-mode--consult-source-enum
  `(:name "Enum"
           :narrow ?e
           :category Enum
           :face font-lock-type-face
           :state ,#'apex-ts-mode--consult-preview
           :annotate ,(apex-ts-mode--define-source-annotate)
           :action ,(apex-ts-mode--define-source-action)))

(defcustom apex-ts-mode--consult-sources '(apex-ts-mode--consult-source-field apex-ts-mode--consult-source-method apex-ts-mode--consult-source-class
                                                                              apex-ts-mode--consult-source-property apex-ts-mode--consult-source-constructor apex-ts-mode--consult-source-enum)
  "Imenu sources for `apex-ts-mode'"
  :group 'apex-ts-mode-consult
  :type 'list
  :safe 'listp)

;;;###autoload
;; (defun apex-ts-mode--eglot-imenu ()
;;   "Overriding eglot imenu default with `consult-muilti'."
;;   (interactive)
;;   (require 'consult-imenu nil t)
;;   (let* ((imenu-items (eglot-imenu)))
;; 
;;     ;; Add candidates to sources
;;     (dolist (source apex-ts-mode--consult-sources)
;;       (let* ((category-name (format "%s" (plist-get (symbol-value source) :category)))
;;              (item (assoc category-name imenu-items))
;;              (candidates (apex-ts-mode--filter-candidate (cdr item))))
;; 
;;         (plist-put (symbol-value source) :items candidates)))
;;                                                 
;; 
;;     (consult--multi apex-ts-mode--consult-sources)))
;; 
;; (cl-defun apex-ts-mode--filter-candidate (candidates)
;;  "Filter candidate according category."
;;  (cl-loop for candidate in candidates
;;           collect (apex-ts-mode--rebuild-eglot-candidate candidate)))
;; 
;; (defun apex-ts-mode--rebuild-eglot-candidate (candidate)
;;   "Rebuild items return from `eglot-imenu'.
;;    
;;    Eglot construct item: (text . pos)"
;;   (let* ((text-split (split-string (car candidate) ":"))
;;          (display-text (car text-split))
;;          (type (and (cadr text-split) (replace-regexp-in-string "[() ]" "" (cadr text-split))))
;;          (marker (cdr candidate)))
;; 
;;     (cons (propertize display-text)
;;           (list :type type
;;              :marker marker))))
;; 
;; (defun apex-ts-mode--candidate-type (candidate)
;;  "Get candidate type."
;;  (get-text-property 0 'breadcrumb-kind candidate))
;; 
;; (defun apex-ts-mode--candidate-region (candidate)
;;  "Get candidate region."
;;  (get-text-property 0 'breadcrumb-region candidate))
;; 
;; (defun apex-ts-mode--consult-preview ()
;;   "Handle imenu preview."
;;   (let ((preview (consult--jump-preview)))
;;     (lambda (action cand) 
;;       (funcall preview action (and (markerp (plist-get cand :marker)) (plist-get cand :marker))))))

;;; Yasnippet
(with-eval-after-load 'yasnippet
  (require 'apex-ts-mode-yasnippet)
  (apex-ts-mode-yasnippet-initialize))

(provide 'apex-ts-mode)
;;; apex-ts-mode.el ends here
