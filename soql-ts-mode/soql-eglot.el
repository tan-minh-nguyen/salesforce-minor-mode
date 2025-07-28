;;; soql-eglot.el -*- lexical-binding: t; -*- SOQL Language server for eglot

;;;###autoload
(defun soql-ts-mode--generate-server-lsp-command ()
  "generate command run apex server."
  ;; `(,soql-ts-mode--lsp-path "--stdio")
  )

;; Eglot config for soql
(defcustom soql-ts-mode--eglot-config '()
  "JSON use for LSP initialization config."
  :type 'list
  :group 'soql)

;;;###autoload
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(soql-ts-mode . (,@(soql-ts-mode--generate-server-lsp-command)
                                 ,@soql-ts-mode--eglot-config))))


(provide 'soql-eglot)
