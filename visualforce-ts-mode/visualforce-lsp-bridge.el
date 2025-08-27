;;; Visualforce-lsp-bridge.el -- LSP Bridge server configuration -*- lexical-binding: t; -*-

;; configuration lsp bridge
(defvar apex-lsp-bridge-language-dir (expand-file-name "language-sever" (file-name-directory load-file-name))
  "Language server configuration for LSP Bridge.")

(with-eval-after-load 'lsp-bridge
  (add-to-list 'lsp-bridge-single-lang-server-mode-list '(visualforce-ts-mode . "visualforce"))
  (add-to-list 'lsp-bridge-formatting-indent-alist '(visualforce-ts-mode . visualforce-ts-mode--indent-offset)))

;; Enable lsp-bridge
(defun lsp-bridge-visualforce-mode ()
  (setq-local lsp-bridge-user-langserver-dir apex-lsp-bridge-language-dir))

(provide 'visualforce-lsp-bridge)
