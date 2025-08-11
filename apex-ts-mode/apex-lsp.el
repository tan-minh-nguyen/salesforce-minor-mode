;;; apex-lsp.el --- LSP support for Apex -*- lexical-binding: t -*-

(defcustom apex-lsp-path "apex-lsp"
  "Path of LSP bin."
  :type 'string
  :group 'apex-lsp)

;; Eglot config for apex
(defcustom apex-lsp-eglot-config '(:initializationOptions (:enableEmbeddedSoqlCompletion t))
  "JSON use for LSP initialization config."
  :type 'list
  :group 'apex-lsp)

(defun apex-lsp--generate-server-lsp-command ()
  "generate command run apex server."
  `("java" "-cp" ,(expand-file-name apex-lsp-path) "apex.jorje.lsp.ApexLanguageServerLauncher"))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(apex-ts-mode . (,@(apex-lsp--generate-server-lsp-command)
                                 ,@apex-lsp-eglot-config))))

(defvar apex-lsp-bridge-language-dir (expand-file-name "language-sever" load-file-name)
  "Language server configuration for LSP bridge.")

(with-eval-after-load 'lsp-bridge
 (add-to-list 'lsp-bridge-single-lang-server-mode-list '(apex-ts-mode . "apex"))
 (add-to-list 'lsp-bridge-formatting-indent-alist '(apex-ts-mode . apex-ts-mode-indent-offset)))

(provide 'apex-lsp)
