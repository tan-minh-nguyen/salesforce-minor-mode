;;; packages/salesforce-packages/soql-completion/soql-completion.el -*- lexical-binding: t; -*- SOQL auto completion

;; Code
(require 'treesit)
(require 'dx-core)

(defvar-local soql-completion-sobject-list '()
  "List sobjects on org.")

(defun soql-completion--setup-eglot ()
  ""
  (add-to-list 'eglot-server-programs
               '(soql-completion . ("soql-lsp" "--stdio"))))

(defun soql-completion--find-files (file-name)
  "Find all files with name."
  (shell-command-to-string (string-join `("find" ,(concat (dx-project-root-dir) soql-completion-metadata-dir) "-iname" ,(format "'%s*'" file-name) "-printf" "'%f\n'" "|" "cut" "-d." "-f1")
					" ")))

(defun soql-completion--sobject ()
  "Get sobject on buffer."
  (when-let ((node (treesit-query-capture (treesit-buffer-root-node) '((storage_identifier (identifier) @capture)))))

    (treesit-node-text (cdar node) t)))

(defun soql-completion--retrieve-sobjects (sobject)
  "Retrieve Sobject in current org."
  (when-let* ((files (soql-completion--find-files sobject)))

    (split-string files)))


(defun soql-completion--convert-items-completion (candidates)
  "Convert completion return from SOQL server to current SObject on org."
  (cl-loop for keyword in candidates
           until (string-match-p "__[A-Z_]*" keyword)
           for cur-point = (point)
           for beg-point = (progn
                             (search-forward-regexp "[ ]" nil t -1)
                             (point))
           finally return `(,@soql-completion-sobject-list)))

;; (defun soql-completion--init-h ()
;;   "Inititalize settings for `soql-completion'.")

;; (add-hook 'dx-minor-mode-hook #'soql-completion--init-h)

(provide 'soql-completion)
