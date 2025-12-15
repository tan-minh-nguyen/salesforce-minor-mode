;;; apex-completion-context.el --- Detect SOQL/SOSL context in Apex -*- lexical-binding: t; -*-

;;; Commentary:
;; Uses tree-sitter to detect if point is inside embedded SOQL/SOSL query.
;; This allows context-aware completion to work seamlessly with Eglot.

;;; Code:

(require 'treesit)

(defun apex-completion--in-soql-p ()
  "Return non-nil if point is inside SOQL query."
  (when-let ((node (treesit-node-at (point))))
    (treesit-parent-until 
     node
     (lambda (n)
       (member (treesit-node-type n)
               '("soql_query_body" 
                 "query_expression"
                 "soql_literal"))))))

(defun apex-completion--in-sosl-p ()
  "Return non-nil if point is inside SOSL query."
  (when-let ((node (treesit-node-at (point))))
    (treesit-parent-until 
     node
     (lambda (n)
       (member (treesit-node-type n)
               '("sosl_query_body" 
                 "find_expression"
                 "sosl_literal"))))))

(defun apex-completion--current-context ()
  "Determine current completion context.
Returns 'soql, 'sosl, or 'apex."
  (cond
   ((apex-completion--in-soql-p) 'soql)
   ((apex-completion--in-sosl-p) 'sosl)
   (t 'apex)))

(defun apex-completion--debug-node-at-point ()
  "Show tree-sitter node hierarchy at point for debugging."
  (interactive)
  (let ((node (treesit-node-at (point)))
        (nodes '()))
    (while node
      (push (treesit-node-type node) nodes)
      (setq node (treesit-node-parent node)))
    (message "Node hierarchy: %s" (string-join nodes " -> "))))

(provide 'apex-completion-context)

;;; apex-completion-context.el ends here
