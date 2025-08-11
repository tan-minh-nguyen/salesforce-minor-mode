;;; soql-lsp.el -*- lexical-binding: t; -*- SOQL LSP
;;; LSP configurations

(defcustom soql-ts-mode-lsp-path "soql-lsp"
  "Path of LSP bin."
  :type 'string
  :group 'soql)

;; Eglot config for soql
(defcustom soql-ts-mode--eglot-config '()
  "JSON use for LSP initialization config."
  :type 'list
  :group 'soql)

(defun soql-ts-mode--generate-server-lsp-command ()
  "generate command run apex server."
  `(,soql-ts-mode-lsp-path "--stdio"))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(soql-ts-mode . (,@(soql-ts-mode--generate-server-lsp-command)
                                 ,@soql-ts-mode--eglot-config))))


;; LSP-BRIDGE
(defvar soql-lsp-bridge-language-dir (expand-file-name "language-sever" (file-name-base load-file-name))
  "Language server configuration for LSP bridge.")

(with-eval-after-load 'lsp-bridge
  (add-to-list 'lsp-bridge-single-lang-server-mode-list '(soql-ts-mode . "soql")))

(provide 'soql-lsp)
