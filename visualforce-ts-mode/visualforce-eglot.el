;;; Visualforce-eglot.el -- LSP server configuration -*- lexical-binding: t; -*-

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

(provide 'visualforce-eglot)
