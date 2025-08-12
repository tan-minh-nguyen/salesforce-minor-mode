;;; Visualforce-lsp.el -- LSP server configuration -*- lexical-binding: t; -*-

;; configuration lsp bridge
(defvar apex-lsp-bridge-language-dir (expand-file-name "language-sever" (file-name-directory load-file-name))
  "Language server configuration for LSP Bridge.")

(with-eval-after-load 'lsp-bridge
  (add-to-list 'lsp-bridge-single-lang-server-mode-list '(visualforce-ts-mode . "visualforce"))
  (add-to-list 'lsp-bridge-formatting-indent-alist '(visualforce-ts-mode . visualforce-ts-mode--indent-offset)))

;; Enable lsp-bridge
(defun lsp-bridge-visualforce-mode ()
  (setq-local lsp-bridge-user-langserver-dir apex-lsp-bridge-language-dir))

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

(provide 'visualforce-lsp)
