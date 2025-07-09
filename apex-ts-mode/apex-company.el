;;; apex-company.el --- auto completions in block src edit -*- lexical-binding: t -*-

(defvar apex-company-capture-rules '((local_variable_declaration) @variable)
  "Rules capture symbols in buffer.")

(defun apex-company--candidates (&optional prefix)
  "Get apex candidates."
  (cl-loop for (_ . node) in (treesit-query-capture (treesit-buffer-root-node)
                                                    apex-company-capture-rules)
           as var = (treesit-node-child-by-field-name node "declarator")
           as var-type = (treesit-node-child-by-field-name node "type")
           as var-name = (treesit-node-child-by-field-name var "name")
           as var-name-text = (treesit-node-text var-name t)
           as var-type-text = (treesit-node-text var-type t)
           when (s-prefix-p prefix var-name-text)
           collect (propertize var-name-text
                               'annotation var-type-text)))

(defun apex-company--annotation (candidate)
  "Format annotation for candidate."
  (format "%s" (get-text-property 0 'annotation candidate)))

(defun company-apex (command &optional arg &rest ignored)
  "Company backend for apex, use treesit to build auto completions list."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-apex))
    (prefix (and (apex-ts-mode-p)
                 (company-grab-symbol)))
    (candidates (apex-company--candidates arg))
    (annotation (apex-company--annotation arg))))

(defun apex-company-setup ()
  "Setup Apex company backend."
  (add-to-list (make-local-variable 'company-backends) 'company-apex))

(provide 'apex-company)
