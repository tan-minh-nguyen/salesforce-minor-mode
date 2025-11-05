;;; LWC html mode -- html tree-sitter support for LWC html file -*- lexical-binding: t; -*-

;;; Code
(require 'lwc-ts-common)

(defcustom lwc-html-ts-mode--indent-offset 4
  "LWC indention offset."
  :group 'lwc-html
  :type 'integer
  :safe 'integerp)

(defvar lwc-html-ts-mode--regex-capture-expression "{[^}]*}"
  "Regex use for capture LWC expression.")

(defvar lwc-html-ts-mode--html-font-lock-settings
  (treesit-font-lock-rules
   :language 'html
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'html
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
      (:match "^lightning-.+" @font-lock-builtin-face)))

   :language 'html
   :feature 'attribute
   '((attribute (attribute_name)
                @font-lock-constant-face
                "=" @font-lock-bracket-face
                [((quoted_attribute_value) @font-lock-string-face)
                 ((attribute_value) @font-lock-function-call-face)]))

   :language 'html
   :feature 'declaration
   '((doctype) @font-keyword-doc-face)

   :language 'html
   :feature 'delimiter
   '(["<!" "<" ">" "/>" "</"] @font-lock-bracket-face))
  "Tree-sitter HTML font-lock settings for `lwc-html-ts-mode'.")

(defvar lwc-html-ts-mode--html-indent-rules
  `(html
    ((parent-is "document") column-0 0)
    ((node-is "comment") parent lwc-html-ts-mode--indent-offset)
    ((node-is ,(regexp-opt '("element" "self_closing_tag"))) parent lwc-html-ts-mode--indent-offset)
    ((node-is "end_tag") parent 0)
    ((node-is "/") parent 0)
    ((node-is "text") parent 0)
    ((node-is "attribute") prev-sibling 2)
    ((node-is ">") parent 0)
    ((node-is "start_tag") prev-sibling 0)
    (no-node parent 0))
  "Indent rules for html on lwc component.")


;; Config indent rules is apply for Visualforce page,
;; TODO HTML - indent rules offset is 2
;; TODO Javascript
;; TODO Css
;; (defvar lwc-html-ts-mode--indent-rules
;;   `((,@lwc-html-ts-mode--html-indent-rules)
;;     (,@lwc-html-ts-mode--css-indent-rules)
;;     (,@lwc-html-ts-mode--js-indent-rules))
;;   "Tree-sitter indent rules for `lwc-html-ts-mode'.")

;; Get treesitter parser on position
(defun lwc-html-ts-mode--parser-at-pos (pos)
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
(defalias #'treesit-simple-imenu #'lwc-html-ts-mode--treesit-simple-imenu
  "Simple imenu for `lwc-html-ts-mode'")

(defun lwc-html-ts-mode--treesit-simple-imenu ()
  "Imenu index for `lwc-html-ts-mode'"
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

(defun lwc-html-ts-mode--css-setup ()
  "Setup font lock settings for css."
  (when-let ((_ (treesit-ready-p 'css t)))

    (treesit-range-rules
     :embed 'css
     :host 'html
     '((style_element (raw_text) @capture)))))

;; (defun lwc-html-ts-mode--js-setup ()
;;   "Setup font lock settings for javascript."
;;   (when-let (_ (treesit-ready-p 'javascript t))

;;     (treesit-range-rules
;;      :embed 'javascript
;;      :host 'html
;;      '((script_element (raw_text) @capture)))))

(defun lwc-html-mode-auto ()
  "Auto enable major-mode for file in Salesforce project."
  (when (lwc-ts-mode--lwc-file-p)
    (lwc-html-ts-mode)))

(defun lwc-ts-mode--html ()
  "HTML settings of tree-sitter for `lwc-html-ts-mode'."

  (treesit-parser-create 'html)

  ;; Font-lock.
  (setq-local treesit-font-lock-settings
              `(,@lwc-html-ts-mode--html-font-lock-settings))
  (setq-local treesit-font-lock-feature-list
              '((selector comment definition query)
                (tag attribute expression keyword literal regex)
                (declaration builtin operator constant function inline-script)
                (bracket delimiter)))

  ;; Electric

  ;; Indent.
  (setq-local treesit-simple-indent-rules `((,@lwc-html-ts-mode--html-indent-rules)))

  ;; Imenu
  (setq-local treesit-simple-imenu-settings
              `(("Element" lwc-html-ts-mode--element-p nil lwc-ts-mode--format-element html)
                ;; ("Component" "\\`element\\'" nil visualforce-ts-mode--find-component)))
                ("Expression" lwc-html-ts-mode--expression-p nil lwc-ts-mode--format-expression html)
                ;; JS
                ("Variable" "\\`lwc_declaration\\'" nil (lambda (node)
                                                          (treesit-node-text (treesit-node-child-by-field-name node "name"))))
                ("Function" "\\`function_declaration\\'" nil (lambda (node)
                                                               (treesit-node-text (treesit-node-child-by-field-name node "name"))))))

  ;; Range settings
  (setq-local treesit-range-settings
              `(,@(lwc-html-ts-mode--css-setup)))
  (setq-local treesit-language-at-point-function #'lwc-html-ts-mode--parser-at-pos)

  ;; (setq treesit--indent-verbose t)
  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode lwc-html-ts-mode fundamental-mode "lwc html"
  "Major mode use tree-sitter for Visualforce page, powered by tree-sitter."
  :group 'lwc
  (unless (treesit-ready-p 'html t)
    (error "Tree-sitter for html isn't available."))
  (lwc-ts-mode--html)

  (treesit-major-mode-setup)

  (setq-local eglot-workspace-configuration
              '(:lwc-ts-mode (:documentSelector [(:language "html" :scheme "file")
                                                 (:language "javascript" :scheme "file")
                                                 (:language "typescript" :scheme "file")]))))

;; configuration lsp bridge
;; (defvar lwc-lsp-mode--root-dir (file-name-directory load-file-name)
;;   "Root directory.")

;; (when (require 'lsp-bridge nil t)
;;   (with-eval-after-load 'lsp-bridge
;;     (add-to-list 'lsp-bridge-single-lang-server-mode-list '(lwc-html-ts-mode . "lwc"))
;;     (add-to-list 'lsp-bridge-formatting-indent-alist '(lwc-html-ts-mode . lwc-ts-mode--indent-offset))))

;; ;; Enable lsp-bridge
;; (defun lsp-bridge-lwc-mode ()
;;   (interactive)
;;   (let ((langserver-dir (concat lwc-lsp-mode--root-dir "/language-server/")))

;;     (setq-local lsp-bridge-user-langserver-dir langserver-dir)

;;     (lsp-bridge-mode)))

(add-to-list 'auto-mode-alist '("\\.html\\'" . lwc-html-mode-auto))

(provide 'lwc-html-ts-mode)
