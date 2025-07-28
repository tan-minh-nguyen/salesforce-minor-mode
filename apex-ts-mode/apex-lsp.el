;;; apex-lsp.el --- LSP support for Apex -*- lexical-binding: t -*-

;; Configurations lsp-bridge
(defcustom apex-lsp-type 'eglot
  "Type of LSP client to use."
  :type '(choice
          (const :tag "Eglot (built‑in)" eglot)
          ;;(const :tag "lsp‑mode" lsp-mode)
          (const :tag "lsp‑bridge" lsp-bridge))
  :group 'apex-lsp)

(defcustom apex-lsp-path "~/.local/apex-lsp/apex-lsp.jar"
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
  (when (eq apex-lsp-type 'eglot)
    (add-to-list 'eglot-server-programs
                 `(apex-ts-mode . (,@(apex-lsp--generate-server-lsp-command)
                                   ,@apex-lsp-eglot-config)))
    (add-hook 'apex-ts-mode-hook #'eglot-ensure)))

(defvar apex-lsp-bridge-language-dir (expand-file-name "language-sever" load-file-name)
  "Language server configuration for LSP bridge.")

(with-eval-after-load 'lsp-bridge
  (when (eq apex-lsp-type 'lsp-bridge)
    (add-to-list 'lsp-bridge-single-lang-server-mode-list '(apex-ts-mode . "apex"))
    (add-to-list 'lsp-bridge-default-mode-hooks #'apex-ts-mode)
    (add-to-list 'lsp-bridge-formatting-indent-alist '(apex-ts-mode . apex-ts-mode-indent-offset))))

(provide 'apex-lsp)
