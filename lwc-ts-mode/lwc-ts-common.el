;;; LWC ts common -- common file use for lwc mode -*- lexical-binding: t; -*-

;;; Code
(require 'treesit)
(require 'sgml-mode)

(defcustom lwc-ts-mode--lsp-path "lwc-language-server"
  "Path to the LWC Language Server executable.
This should be either an absolute path or the name of an executable available in `exec-path'."
  :type 'string
  :group 'lwc)

(defcustom lwc-ts-mode--eglot-config '()
  "Configuration settings for LWC Language Server Protocol (LSP) initialization.
This list will be passed to Eglot for configuring the LSP client."
  :type 'list
  :group 'lwc)

(defun lwc-ts-mode--fontify-expression (node override start end &rest _)
  "Apply syntax highlighting to LWC template expressions in the given NODE.
NODE is the treesit node to process. OVERride determines how face properties
are applied (t, prepend, or append). START and END define the buffer region
to process. Handles both property binding and expression keywords."
  (let* ((node-text (treesit-node-text node t))
         (node-pos (treesit-node-start NODE))
         (matches (lwc-ts-mode--extract-expression node-text)))

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
        (lwc-ts-mode--fontify-keywords match node-pos override)))))

(defun lwc-ts-mode--extract-expression (node-text)
  "Find all LWC template expressions in NODE-TEXT.
Returns a list of matches in format ((EXPR . (START . END))...).
Matches template syntax like {variable} or {object.property}."
  (let ((expression-matches '())
        (pos 0))

    (while (string-match lwc-ts-mode--regex-capture-expression node-text pos)
      (push `(,(match-string 0 node-text) . (,(match-beginning 0) . ,(match-end 0))) matches)
      (setq pos (match-end 0)))
    matches))

(defun lwc-ts-mode--extract-keywords (keywords expression)
  "Find positions of KEYWORDS within an LWC template EXPRESSION.
EXPRESSION should be in format (TEXT . (START . END)). Returns a list
of (START . END) positions for each keyword match."
  (let* ((expr-string (car expression))
         (expr-start (cadr expression))
         (pos 0)
         (keyword-positions '()))

    (while (string-match keywords (upcase expr-string) pos)
      (when-let* ((hl-start (+ expr-start (match-beginning 0)))
                  (hl-end (+ hl-start (- (match-end 0) (match-beginning 0)))))

        (push `(,hl-start . ,hl-end) matches))
      (setq pos (match-end 0)))
    matches))

(defun lwc-ts-mode--fontify-keywords (expression node-pos override)
  "Apply keyword highlighting to LWC template expressions.
EXPRESSION is the parsed template expression, NODE-POS is its starting position
in the buffer, OVERride controls face property application."
  (when-let* ((keyword-patterns `,(mapcar (lambda (keyword)
                                            (concat keyword "("))
                                          lwc-ts-mode--keywords))
              (keyword-matches (lwc-ts-mode--extract-keywords `,(regexp-opt keyword-patterns) expression)))

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

(defun lwc-ts-mode--expression-p (node)
  "Check if NODE represents an LWC template expression.
Returns non-nil if the node is an attribute value or text node containing
template expression syntax like {variable}."
  (when-let ((node-type (treesit-node-type node))
             (node-text (treesit-node-text node t)))

    (and (or (string= "attribute_value" node-type)
          (string= "text" node-type))
       (string-match-p lwc-ts-mode--regex-capture-expression node-text))))

(defun lwc-ts-mode--element-p (node)
  "Check if NODE represents an HTML element tag.
Returns non-nil for both self-closing (<tag/>) and regular opening tags (<tag>)."
  (when-let ((node-type (treesit-node-type node)))

    (or (string= "self_closing_tag" node-type)
       (string= "start_tag" node-type))))

(defun lwc-ts-mode--find-component (node)
  "Check if NODE represents an LWC component tag.
Components are identified by the presence of a namespace prefix (colon) in the tag name."
  (when-let (tag-name (treesit-node-text (treesit-node-child node 1 "tag_name")))

    (string-match-p ":" tag-name)))

(defun lwc-ts-mode--format-expression (node)
  "Format template expressions for Imenu menu display.
NODE is the treesit node containing expressions. Returns a string
with all expressions concatenated, prefixed with #."
  (let ((node-text (treesit-node-text node t))
        (expressions-found '())
        (pos 0))

    (while (string-match lwc-ts-mode--regex-capture-expression node-text pos)
      (push (match-string 0 node-text) matches)
      (setq pos (match-end 0)))

    (concat "#" (string-join matches " #"))))

(defun lwc-ts-mode--recursion-children-node (node depth-list)
  "Recursively traverse NODE's children according to DEPTH-LIST.
DEPTH-LIST is a list of child indices or node types to follow.
Returns the final node at the end of the traversal path."
  (let* ((depth (car depth-list))
         (index (if (stringp depth)
                    0
                  depth))
         (node-name (if (stringp depth)
                        depth
                      0)))

    (if (length> depth-list 1)
        (lwc-ts-mode--recursion-children-node
         (treesit-node-child node index node-name)
         (cdr depth-list))
      (treesit-node-child NODE index node-name))))


(defun lwc-ts-mode--recursion-children-node-text (node depth-list)
  "Get text from node found by recursive child traversal.
First calls `lwc-ts-mode--recursion-children-node' with DEPTH-LIST,
then returns the text of the resulting node."
  (treesit-node-text (lwc-ts-mode--recursion-children-node node depth-list) t))

(defun lwc-ts-mode--format-element (node)
  "Format element information for Imenu display.
NODE is the treesit element node to format. Returns a string combining
the tag name with CSS selectors from id and class attributes."
  (let* ((attr-nodes (treesit-node-children node "attribute"))
         (format-id-attribute
          (lambda (n)
            (concat "#" (lwc-ts-mode--recursion-children-node-text n '(-1 "attribute_value")))))
         (format-class-attribute
          (lambda (n)
            (when-let ((class-val (lwc-ts-mode--recursion-children-node-text n '(-1 "attribute_value"))))
              (concat "." (string-join (split-string class-val) " .")))))

         (formatted-attributes (mapconcat 
                                (lambda (n)
                                  (pcase (treesit-node-text (treesit-node-child n 0 "attribute_name") t)
                                    ("id" (funcall format-id-attribute n))
                                    ((or "class" "styleClass") (funcall format-class-attribute n))
                                    (_ "")))
                                attr-nodes)))
    (concat (lwc-ts-mode--recursion-children-node-text node '("tag_name")) formatted-attributes)))

(defun lwc-ts-mode--lwc-file-p ()
  "Check file is LWC."
  (require 'salesforce-project nil 'noerror)
  (and (salesforce-project-p)
     (string-prefix-p (salesforce-core--join-path salesforce-metadata-root-dir salesforce-lwc-dir)
                      (buffer-file-name))))

(provide 'lwc-ts-common)
