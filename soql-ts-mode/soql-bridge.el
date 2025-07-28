;;; soql-lsp.el -*- lexical-binding: t; -*- SOQL LSP
;;; LSP configurations

(defcustom soql-ts-mode--lsp-path "soql-lsp"
  "Path of LSP bin."
  :type 'string
  :group 'soql)

;; LSP-BRIDGE
(with-eval-after-load 'lsp-bridge
  (add-to-list 'lsp-bridge-single-lang-server-mode-list '(soql-ts-mode . "soql"))
  ;; (add-to-list 'lsp-bridge-default-mode-hooks 'apex-ts-mode-hook)
  )

(defun lsp-bridge-soql-mode (server-dir)
  "Configurate LSP for `soql-ts-mode'."
  (interactive (list (concat soql-ts-mode--root-dir "language-server/")))
  (setq-local lsp-bridge-user-langserver-dir server-dir)
  (lsp-bridge-mode))

(provide 'soql-bridge)
