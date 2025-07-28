;;; Visualforce ts mode -- tree-sitter support for Visualforce -*- lexical-binding: t; -*-

;;; Code

(require 'treesit)
(require 'sgml-mode)

(defcustom visualforce-ts-mode--indent-offset 4
  "Visualforce indent offset."
  :group 'visualforce
  :type 'integer)

(defvar visualforce-ts-mode--regex-capture-expression "{![^}]*}"
  "Regex use for capture visualforce expression.")

(defvar visualforce-ts-mode--keywords
  '(
    ;; Advanced
    "CURRENCYRATE" "GETRECORDIDS" "IMAGEPROXYURL" "INCLUDE"
    "ISCHANGED" "JUNCTIONIDLIST" "LINKTO" "PREDICT" "REGEX"
    "REQUIRESCRIPT" "URLFOR" "VLOOKUP"
    ;; DATE
    "ADDMONTHS" "DATE" "DATEVALUE" "DATETIMEVALUE"
    "DAY" "HOUR" "MILLISECOND" "MINUTE" "MONTH" "NOW"
    "SECOND" "TIMENOW" "TIMEVALUE" "TODAY" "WEEKDAY" "YEAR"
    ;; Logical
    "OR" "AND" "IF" "BLANKVALUE" "CASE" "ISBLANK" "ISCLONE"
    "ISNEW" "ISNULL" "ISNUMBER" "NOT" "NULLVALUE" "PRIORVALUE"
    ;; Math
    "ABS" "CEILING" "EXP" "FLOOR" "LN"
    "LOG" "MAX" "MCEILING" "MFLOOR" "MIN"
    "MOD" "ROUND" "SQRT"
    ;; Text
    "BEGINS" "BR" "CASEAFEID" "CONTAINS" "FIND"
    "GETSESSIONID" "HTMLENDCODE" "SPICKVAL" "JSENCODE"
    "JSINHTMLENCODE" "LEFT" "LEN" "LOWER" "LPAD"
    "MID" "RIGHT" "RPAD" "SUBSTITUTE" "TEXT" "TRIM"
    "UPPER" "URLENCODE" "VALUE")
  "Visualfoce helper functions.")

(defvar visualforce-ts-mode--operators
  '("!=" "&&" "||" "==" "+"
    "-" "*" "/" "^" "()"
    ">" "<" "<=" ">=" "<>" "&")
  "Visualforce operators.")

(defvar visualforce-ts-mode--css-operators
  '("+" "-" "*" "/")
  "CSS operators for Visualforce.")

(defvar visualforce-ts-mode--js-operators
  '("!=" "&&" "||" "==" "+"
    "-" "*" "/" "===" "/=" "+="
    ">" "<" "<=" ">=" "|=" "&="
    "-=" "*=")
  "JS operators for Visualforce.")


(defvar visualforce-ts-mode--js-keywords
  '("function" "if" "switch" "case"
    "for" "break" "continue" "return"
    "let" "const" "var" "of" "in" "else"
    "new")
  "JS keywords for Visualforce.")

(defvar visualforce-ts-mode--html-font-lock-settings
  (treesit-font-lock-rules
   :language 'html
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'html
   :feature 'tag
   '((script_element
      (start_tag) @font-lock-doc-markup-face
      (end_tag) @font-lock-doc-markup-face)
     (style_element
      (start_tag) @font-lock-doc-markup-face
      (end_tag) @font-lock-doc-markup-face))

   :language 'html
   :override t
   :feature 'tag
   '((start_tag (tag_name) @font-lock-function-call-face)
     (self_closing_tag (tag_name) @font-lock-function-call-face)
     (end_tag (tag_name) @font-lock-function-call-face))

   :language 'html
   :override t
   :feature 'tag
   '(([(start_tag (tag_name) @font-lock-builtin-face)
       (self_closing_tag (tag_name) @font-lock-builtin-face)
       (end_tag (tag_name) @font-lock-builtin-face)]
      (:match "^apex:.*" @font-lock-builtin-face)))

   :language 'html
   :feature 'attribute
   '((attribute (attribute_name)
      @font-lock-constant-face
      "=" @font-lock-bracket-face
      (quoted_attribute_value) @font-lock-string-face))

   :language 'html
   :override t
   :feature 'expression
   '([(quoted_attribute_value (attribute_value))
      (text)] @visualforce-ts-mode--fontify-expression)

   :language 'html
   :feature 'declaration
   '((doctype) @font-keyword-doc-face)

   ;; :language 'html
   ;; :override t
   ;; :feature 'operator
   ;; `([,@visualforce-ts-mode--operators] @font-lock-operator-face)

   :language 'html
   :feature 'delimiter
   '(["<!" "<" ">" "/>" "</"] @font-lock-bracket-face)

   :language 'html
   :override t
   :feature 'inline-script
   `((attribute ((attribute_name) @font-lock-property-name-face
                 (:match "^on.*$" @font-lock-property-name-face))
      (attribute_value) @visualforce-ts-mode--fontify-inline-script)))
  "Tree-sitter HTML font-lock settings for `visualforce-ts-mode'.")

(defvar visualforce-ts-mode--css-font-lock-settings
  (treesit-font-lock-rules
   ;; CSS font lock rules
   :language 'css
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'css
   :feature 'selector
   '([(class_selector)
      (child_selector)
      (id_selector)
      (tag_name)
      (class_name)] @font-lock-function-name-face
      (pseudo_class_selector (class_name) @font-lock-type-face))

   :language 'css
   :feature 'declaration
   '((declaration
      (property_name) @font-lock-keyword-face))

   :language 'css
   :feature 'builtin
   '((media_statement
      (binary_query (keyword_query) @font-lock-builtin-face
                    "and" @font-lock-operator-face))
     [(important)
      (charset_statement)
      (keyframes_statement (at_keyword))] @font-lock-builtin-face)

   :language 'css
   :feature 'expression
   '((call_expression (function_name) @font-lock-function-call-face))

   :language 'css
   :feature 'constant
   '((plain_value) @font-lock-property-use-face
     (attribute_name) @font-lock-property-use-face)

   :language 'css
   :feature 'literal
   '([(integer_value) (float_value)] @font-lock-number-face
     (string_value) @font-lock-string-face)

   :language 'css
   :feature 'delimiter
   '([":" ";" ","] @font-lock-delimiter-face)

   :language 'css
   :feature 'bracket
   '(["{" "}" "(" ")"] @font-lock-bracket-face))

  "Tree-sitter CSS font-lock settings for `visualforce-ts-mode'.")

(defvar visualforce-ts-mode--js-font-lock-settings
  (treesit-font-lock-rules
   ;; javascript font lock rules
   :language 'javascript
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'javascript
   :feature 'keyword
   `(([,@visualforce-ts-mode--js-keywords] @font-lock-keyword-face))

   :language 'javascript
   :override t
   :feature 'function
   '((function_declaration
      (identifier) @font-lock-function-name-face)
     ((call_expression
       (identifier) @font-lock-function-call-face)))

   :language 'javascript
   :override t
   :feature 'expression
   '((member_expression (identifier) @font-lock-function-call-face)
     (member_expression (property_identifier) @font-lock-property-name-face))

   :language 'javascript
   :feature 'regex
   `((regex
      "/" @font-lock-regexp-grouping-backslash
      (regex_pattern) @font-lock-regexp-face
      "/" @font-lock-regexp-grouping-backslash
      (regex_flags) @font-lock-regexp-grouping-construct))

   :language 'javascript
   :feature 'operator
   `([,@visualforce-ts-mode--js-operators] @font-lock-operator-face)

   :language 'javascript
   :override t
   :feature 'operator
   '(["!"] @font-lock-negation-face)

   :language 'javascript
   :feature 'constant
   '((identifier) @font-lock-type-face
     (true) @font-lock-type-face
     (false) @font-lock-type-face)

   :language 'javascript
   :feature 'literal
   '((string) @font-lock-string-face
     (number) @font-lock-number-face
     (property_identifier) @font-lock-property-name-face)

   ;; :language 'javascript
   ;; :override t
   ;; :feature 'expression
   ;; '([(quoted_attribute_value (attribute_value))
   ;;    (text)] @visualforce-ts-mode--fontify-expression)

   :language 'javascript
   :feature 'delimiter
   '([":" ";" "."] @font-lock-delimiter-face)

   :language 'javascript
   :feature 'bracket
   '(["{" "}" "(" ")" "[" "]"] @font-lock-bracket-face))
  "Tree-sitter Javascipt font-lock settings for `visualforce-ts-mode'.")


(defvar visualforce-ts-mode--css-indent-rules
  `(css
    ((parent-is "rule_set") column-0 0)
    ((node-is "comment") parent visualforce-ts-mode--indent-offset)
    ((node-is "block") prev-sibling 0)
    ((node-is "}") parent 0)
    ((parent-is "block") parent-bol visualforce-ts-mode--indent-offset)
    (no-node parent 0))
  "Indent rules for css on visualforce page.")

(defvar visualforce-ts-mode--js-indent-rules
  `(javascript
    ((parent-is ,(regexp-opt '("variable_declaration" "function_declaration"))) column-0 visualforce-ts-mode--indent-offset)
    ((node-is "statement_block") prev-sibling 2)
    ((parent-is "statement_block") parent-bol visualforce-ts-mode--indent-offset)
    ((parent-is "object") parent visualforce-ts-mode--indent-offset)
    ((field-name "object") parent visualforce-ts-mode--indent-offset)
    ((node-is ,(regexp-opt '("property_identifier" "return_statement")) parent-bol visualforce-ts-mode--indent-offset))
    ((node-is "}") parent-bol 0)
    (no-node parent 0))
  "Indent rules for javascript on visualforce page.")

(defvar visualforce-ts-mode--html-indent-rules
  `(html
    ((parent-is "document") column-0 0)
    ((node-is "comment") parent visualforce-ts-mode--indent-offset)
    ((node-is ,(regexp-opt '("element" "self_closing_tag"))) parent visualforce-ts-mode--indent-offset)
    ((node-is "end_tag") parent 0)
    ((node-is "/") parent 0)
    ((node-is "text") parent 0)
    ((node-is "attribute") prev-sibling 2)
    ((node-is ">") parent 0)
    ((node-is "start_tag") prev-sibling 0)
    (no-node parent 0))
  "Indent rules for html on visualforce page.")


;; Config indent rules is apply for Visualforce page,
;; TODO HTML - indent rules offset is 2
;; TODO Javascript
;; TODO Css
(defvar visualforce-ts-mode--indent-rules
  `((,@visualforce-ts-mode--html-indent-rules)
    (,@visualforce-ts-mode--css-indent-rules)
    (,@visualforce-ts-mode--js-indent-rules))
  "Tree-sitter indent rules for `visualforce-ts-mode'.")

(defun visualforce-ts-mode--fontify-inline-script (NODE override start end &rest _)
  "Fontify js script in Visualforce mode."
  (message "NODE: %s" (treesit-node-text NODE)))

(defun visualforce-ts-mode--fontify-expression (NODE override start end &rest _)
  "Fontify NODE expressions in Visualforce mode."
  (let* ((node-text (treesit-node-text NODE t))
         (node-pos (treesit-node-start NODE))
         (matches (visualforce-ts-mode--extract-expression node-text)))

    (dolist (match matches)
      (when-let* ((expr-start (cadr match))
                  (expr-end (cddr match))
                  (hl-start (+ expr-start node-pos))
                  (hl-end (+ hl-start (- expr-end expr-start))))

        (when (and (>= hl-start start)
                   (<= hl-end end))

          (pcase override
            ('t
             (put-text-property
              hl-start hl-end 'face 'font-lock-property-use-face))
            ('prepend
             (font-lock-prepend-text-property
              hl-start hl-end 'face 'font-lock-property-use-face))
            ('append
             (font-lock-append-text-property
              hl-start hl-end 'face 'font-lock-property-use-face))))

        ;; Fontify keywords in expression
        (visualforce-ts-mode--fontify-keywords match node-pos override)))))

(defun visualforce-ts-mode--extract-expression (node-text)
  "Extract expression in `NODE-TEXT'."
  (let ((matches '())
        (pos 0))

    (while (string-match visualforce-ts-mode--regex-capture-expression node-text pos)
      (push `(,(match-string 0 node-text) . (,(match-beginning 0) . ,(match-end 0))) matches)
      (setq pos (match-end 0)))
    matches))

(defun visualforce-ts-mode--extract-keywords (keywords expression)
  "Extract `KEYWORDS' position in `EXPRESSION'."
  (let* ((expr-string (car expression))
         (expr-start (cadr expression))
         (pos 0)
         (matches '()))

    (while (string-match keywords (upcase expr-string) pos)
      (when-let* ((hl-start (+ expr-start (match-beginning 0)))
                  (hl-end (+ hl-start (- (match-end 0) (match-beginning 0)))))

        (push `(,hl-start . ,hl-end) matches))
      (setq pos (match-end 0)))
    matches))

(defun visualforce-ts-mode--fontify-keywords (expression node-pos override)
  "Fontify keywords in Visualforce mode."
  (when-let* ((format-keyword `,(mapcar (lambda (keyword)
                                          (concat keyword "("))
                                        visualforce-ts-mode--keywords))
              (keyword-matches (visualforce-ts-mode--extract-keywords `,(regexp-opt format-keyword) expression)))

    (dolist (pos keyword-matches)
      (when-let* ((hl-start (+ (car pos) node-pos))
                  ;; Calculate position end highlight, -1 for postion "("
                  (hl-end (+ node-pos (- (cdr pos) 1))))

        (pcase override
          ('t
           (put-text-property
            hl-start hl-end 'face 'font-lock-keyword-face))
          ('prepend
           (font-lock-prepend-text-property
            hl-start hl-end 'face 'font-lock-keyword-face))
          ('append
           (font-lock-append-text-property
            hl-start hl-end 'face 'font-lock-keyword-face)))))))

(defun visualforce-ts-mode--expression-p (NODE)
  "Check if NODE is expression on `visualforce-ts-mode'"
  (when-let ((node-type (treesit-node-type NODE))
             (node-text (treesit-node-text NODE t)))

    (and (or (string= "attribute_value" node-type)
             (string= "text" node-type))
         (string-match-p visualforce-ts-mode--regex-capture-expression node-text))))

(defun visualforce-ts-mode--element-p (NODE)
  "Find NODE elements on `visualforce-ts-mode'."
  (when-let ((node-type (treesit-node-type NODE)))

    (or (string= "self_closing_tag" node-type)
        (string= "start_tag" node-type))))

(defun visualforce-ts-mode--find-component (NODE)
  "Find Visualforce components NODE."
  (when-let (tag-name (treesit-node-text (treesit-node-child NODE 1 "tag_name")))

    (string-match-p ":" tag-name)))

(defun visualforce-ts-mode--format-expression (NODE)
  "Format expression NODE for imenu on Visualforce page."
  (let ((node-text (treesit-node-text NODE t))
        (matches '())
        (pos 0))

    (while (string-match visualforce-ts-mode--regex-capture-expression node-text pos)
      (push (match-string 0 node-text) matches)
      (setq pos (match-end 0)))

    (concat "#" (string-join matches " #"))))

(defun visualforce-ts-mode--rescursion-children-node (NODE depth-list)
  "Helper recursion NODE to get last depth."
  (let* ((depth (car depth-list))
         (index (if (stringp depth)
                    0
                  depth))
         (node-name (if (stringp depth)
                        depth
                      0)))

    (if (length> depth-list 1)
        (visualforce-ts-mode--rescursion-children-node
         (treesit-node-child NODE index node-name)
         (cdr depth-list))
      (treesit-node-child NODE index node-name))))


(defun visualforce-ts-mode--rescursion-children-node-text (NODE depth-list)
  "Heler recursion NODE to get last NODE, then return as text."
  (treesit-node-text (visualforce-ts-mode--rescursion-children-node NODE depth-list) t))

(defun visualforce-ts-mode--format-element (NODE)
  "Find tag name NODE."
  (let* ((attr-nodes (treesit-node-children NODE "attribute"))
         (id-format `(lambda (node)
                       (concat "#" (visualforce-ts-mode--rescursion-children-node-text node
                                                                                       '(-1 "attribute_value")))))
         (class-format `(lambda (node)
                          (when-let ((class-node (visualforce-ts-mode--rescursion-children-node-text node
                                                                                                     '(-1 "attribute_value"))))
                            (concat "."
                                    (string-join (split-string class-node) " .")))))

         (attr-string (mapconcat (lambda (node)
                                   (pcase (treesit-node-text (treesit-node-child node 0 "attribute_name") t)
                                     ("id"
                                      (funcall id-format node))
                                     ((or "class" "styleClass")
                                      (funcall class-format node))
                                     (_ "")))
                                 attr-nodes)))
    (concat (visualforce-ts-mode--rescursion-children-node-text NODE '("tag_name")) attr-string)))

;; Get treesitter parser on position
(defun visualforce-ts-mode--parser-at-pos (pos)
  "Return treesiter parser at POS."
  (let ((html-parser (treesit-parser-create 'html))
        (css-parser (when-let ((_ (treesit-ready-p 'css))
                               (css-parser (treesit-parser-create 'css)))
                      css-parser))
        (js-parser (when-let ((_ (treesit-ready-p 'javascript))
                              (js-parser (treesit-parser-create 'javascript)))
                     js-parser)))

    (cond ((and css-parser
                ;; cover for file not use css tag
                (treesit-parser-included-ranges css-parser)
                (treesit-parser-range-on css-parser pos))
           'css)
          ((and js-parser
                ;; cover for file not use js tag
                (treesit-parser-included-ranges js-parser)
                (treesit-parser-range-on js-parser pos))
           'javascript)
          ((treesit-parser-range-on html-parser pos)
           'html))))
;; Imenu
;; Add language parameter to configuration dynamic parser language
(defalias #'treesit-simple-imenu #'visualforce-ts-mode--treesit-simple-imenu
  "Simple imenu for `visualforce-ts-mode'")

(defun visualforce-ts-mode--treesit-simple-imenu ()
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

(defun visualforce-ts-mode--css-setup ()
  "Setup font lock settings for css."
  (when-let ((_ (treesit-ready-p 'css t)))

    (treesit-range-rules
     :embed 'css
     :host 'html
     '((style_element (raw_text) @capture)))))

(defun visualforce-ts-mode--js-setup ()
  "Setup font lock settings for javascript."
  (when-let (_ (treesit-ready-p 'javascript t))

    (treesit-range-rules
     :embed 'javascript
     :host 'html
     '((script_element (raw_text) @capture)))))

(defun visualforce-ts-mode--html-setup ()
  "Main settings of tree-sitter for `visualforce-ts-mode'."

  (treesit-parser-create 'html)

  ;; Font-lock.
  (setq-local treesit-font-lock-settings
              `(,@visualforce-ts-mode--html-font-lock-settings
                ,@visualforce-ts-mode--css-font-lock-settings
                ,@visualforce-ts-mode--js-font-lock-settings))
  (setq-local treesit-font-lock-feature-list
              '((selector comment definition query)
                (tag attribute expression keyword literal regex)
                (declaration builtin operator constant function inline-script)
                (bracket delimiter)))

  ;; Electric

  ;; Indent.
  (setq-local treesit-simple-indent-rules visualforce-ts-mode--indent-rules)

  ;; Imenu
  (setq-local treesit-simple-imenu-settings
              `(("Element" visualforce-ts-mode--element-p nil visualforce-ts-mode--format-element html)
                ;; ("Component" "\\`element\\'" nil visualforce-ts-mode--find-component)))
                ("Expression" visualforce-ts-mode--expression-p nil visualforce-ts-mode--format-expression html)
                ;; JS
                ("Variable" "\\`variable_declaration\\'" nil (lambda (node)
                                                               (treesit-node-text (treesit-node-child-by-field-name node "name"))))
                ("Function" "\\`function_declaration\\'" nil (lambda (node)
                                                               (treesit-node-text (treesit-node-child-by-field-name node "name"))))))

  ;; Range settings
  (setq-local treesit-range-settings
              `(,@(visualforce-ts-mode--js-setup)
                ,@(visualforce-ts-mode--css-setup)))
  (setq-local treesit-language-at-point-function #'visualforce-ts-mode--parser-at-pos)

  ;; (setq treesit--indent-verbose t)
  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode visualforce-ts-mode sgml-mode "Visualforce"
  "Major mode use tree-sitter for Visualforce page, powered by tree-sitter."
  :group 'visualforce
  :syntax-table sgml-mode-syntax-table

  (unless (treesit-ready-p 'html t)
    (error "Tree-sitter for html isn't available."))

  (visualforce-ts-mode--html-setup))

;; configuration lsp bridge
(defvar visualforce-lsp-mode--root-dir (file-name-directory load-file-name)
  "Root directory.")

(with-eval-after-load 'lsp-bridge
  (add-to-list 'lsp-bridge-single-lang-server-mode-list '(visualforce-ts-mode . "visualforce"))
  (add-to-list 'lsp-bridge-formatting-indent-alist '(visualforce-ts-mode . visualforce-ts-mode--indent-offset)))

;; Enable lsp-bridge
(defun lsp-bridge-visualforce-mode ()
  (interactive)
  (let ((langserver-dir (concat visualforce-lsp-mode--root-dir "/language-server/")))

    (setq-local lsp-bridge-user-langserver-dir langserver-dir)

    (lsp-bridge-mode)))

;; config eglot
(defcustom visualforce-ts-mode--lsp-path "visualforce-lsp"
  "Path of LSP bin."
  :type 'string
  :group 'visualforce)

(defcustom visualforce-ts-mode--eglot-config '(:initializationOptions (:embeddedLanguages (:css t :javascript t)))
  "JSON use for LSP initialization config."
  :type 'list
  :group 'visualforce)

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(visualforce-ts-mode . (,visualforce-ts-mode--lsp-path "--stdio" ,@visualforce-ts-mode--eglot-config))))

(add-to-list 'auto-mode-alist '("\\.page\\'" . visualforce-ts-mode))
(add-to-list 'auto-mode-alist '("\\.component\\'" . visualforce-ts-mode))

(provide 'visualforce-ts-mode)
