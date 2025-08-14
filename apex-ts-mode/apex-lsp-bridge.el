;;; apex-lsp-bridge.el --- LSP bridge support for Apex -*- lexical-binding: t -*-

(defvar apex-lsp-bridge-language-dir (expand-file-name "language-sever" (file-name-directory load-file-name))
  "Language server configuration for LSP bridge.")

(defun apex-lsp-setup-bridge ()
  "Setup LSP bridge for project."
  (setq-local lsp-bridge-user-langserver-dir apex-lsp-bridge-language-dir))

(with-eval-after-load 'lsp-bridge
 (add-to-list 'lsp-bridge-single-lang-server-mode-list '(apex-ts-mode . "apex"))
 (add-to-list 'lsp-bridge-formatting-indent-alist '(apex-ts-mode . apex-ts-mode-indent-offset)))

(provide 'apex-lsp-bridge)
