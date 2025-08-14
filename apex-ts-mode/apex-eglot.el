;;; apex-eglot.el --- Eglot support for Apex -*- lexical-binding: t -*-

(defcustom apex-lsp-path "apex-lsp"
  "Path of LSP bin."
  :type 'string
  :group 'apex-eglot)

;; Eglot config for apex
(defcustom apex-lsp-eglot-config '(:initializationOptions (:enableEmbeddedSoqlCompletion t))
  "JSON use for LSP initialization config."
  :type 'list
  :group 'apex-eglot)

(defun apex-lsp--generate-server-lsp-command ()
  "generate command run apex server."
  `("java" "-cp" ,(expand-file-name apex-lsp-path) "apex.jorje.lsp.ApexLanguageServerLauncher"))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(apex-ts-mode . (,@(apex-lsp--generate-server-lsp-command)
                                 ,@apex-lsp-eglot-config))))

(provide 'apex-eglot)
