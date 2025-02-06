;;; LWC ts common -- common file use for lwc mode -*- lexical-binding: t; -*-

;;; Code
(require 'treesit)
(require 'sgml-mode)

(defcustom lwc-ts-mode--lsp-path "lwc-language-server"
  "Path of LSP bin."
  :type 'string
  :group 'lwc)

(defcustom lwc-ts-mode--eglot-config '()
  "JSON use for LSP initialization config."
  :type 'list
  :group 'lwc)

(defun lwc-ts-mode--fontify-expression (NODE override start end &rest _)
  "Fontify NODE expressions in Visualforce mode."
  (let* ((node-text (treesit-node-text NODE t))
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
  "Extract expression in `NODE-TEXT'."
  (let ((matches '())
        (pos 0))

    (while (string-match lwc-ts-mode--regex-capture-expression node-text pos)
      (push `(,(match-string 0 node-text) . (,(match-beginning 0) . ,(match-end 0))) matches)
      (setq pos (match-end 0)))
    matches))

(defun lwc-ts-mode--extract-keywords (keywords expression)
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

(defun lwc-ts-mode--fontify-keywords (expression node-pos override)
  "Fontify keywords in `lwc-ts-mode'."
  (when-let* ((format-keyword `,(mapcar (lambda (keyword)
                                          (concat keyword "("))
                                        lwc-ts-mode--keywords))
              (keyword-matches (lwc-ts-mode--extract-keywords `,(regexp-opt format-keyword) expression)))

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

(defun lwc-ts-mode--expression-p (NODE)
  "Check if NODE is expression on `lwc-ts-mode'"
  (when-let ((node-type (treesit-node-type NODE))
             (node-text (treesit-node-text NODE t)))

    (and (or (string= "attribute_value" node-type)
          (string= "text" node-type))
       (string-match-p lwc-ts-mode--regex-capture-expression node-text))))

(defun lwc-ts-mode--element-p (NODE)
  "Find NODE elements on `lwc-ts-mode'."
  (when-let ((node-type (treesit-node-type NODE)))

    (or (string= "self_closing_tag" node-type)
       (string= "start_tag" node-type))))

(defun lwc-ts-mode--find-component (NODE)
  "Find lwc components NODE."
  (when-let (tag-name (treesit-node-text (treesit-node-child NODE 1 "tag_name")))

    (string-match-p ":" tag-name)))

(defun lwc-ts-mode--format-expression (NODE)
  "Format expression NODE for imenu on lwc page."
  (let ((node-text (treesit-node-text NODE t))
        (matches '())
        (pos 0))

    (while (string-match lwc-ts-mode--regex-capture-expression node-text pos)
      (push (match-string 0 node-text) matches)
      (setq pos (match-end 0)))

    (concat "#" (string-join matches " #"))))

(defun lwc-ts-mode--rescursion-children-node (NODE depth-list)
  "Helper recursion NODE to get last depth."
  (let* ((depth (car depth-list))
         (index (if (stringp depth)
                    0
                  depth))
         (node-name (if (stringp depth)
                        depth
                      0)))

    (if (length> depth-list 1)
        (lwc-ts-mode--rescursion-children-node
         (treesit-node-child NODE index node-name)
         (cdr depth-list))
      (treesit-node-child NODE index node-name))))


(defun lwc-ts-mode--rescursion-children-node-text (NODE depth-list)
  "Heler recursion NODE to get last NODE, then return as text."
  (treesit-node-text (visualforce-ts-mode--rescursion-children-node NODE depth-list) t))

(defun lwc-ts-mode--format-element (NODE)
  "Find tag name NODE."
  (let* ((attr-nodes (treesit-node-children NODE "attribute"))
         (id-format `(lambda (node)
                       (concat "#" (lwc-ts-mode--rescursion-children-node-text node
                                                                               '(-1 "attribute_value")))))
         (class-format `(lambda (node)
                          (when-let ((class-node (lwc-ts-mode--rescursion-children-node-text node
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
    (concat (lwc-ts-mode--rescursion-children-node-text NODE '("tag_name")) attr-string)))

(provide 'lwc-ts-common)
