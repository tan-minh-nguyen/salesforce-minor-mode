;;; apex-lsp.el --- LSP support for Apex -*- lexical-binding: t -*-

;; Configurations lsp-bridge
(defcustom apex-lsp-path "~/.local/apex-lsp/apex-lsp.jar"
  "Path of LSP bin."
  :type 'string
  :group 'apex-lsp)

;; Eglot config for apex
(defcustom apex-lsp-eglot-config '(:initializationOptions (:enableEmbeddedSoqlCompletion t))
  "JSON use for LSP initialization config."
  :type 'list
  :group 'apex)

;;;###autoload
(defun apex-lsp--generate-server-lsp-command ()
  "generate command run apex server."
  `("java" "-cp" ,(expand-file-name apex-lsp-path) "apex.jorje.lsp.ApexLanguageServerLauncher"))

;;;###autoload
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(apex-ts-mode . (,@(apex-lsp--generate-server-lsp-command)
                                 ,@apex-lsp-eglot-config))))

(provide 'apex-lsp)
