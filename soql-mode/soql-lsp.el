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

(defun lsp-bridge-soql-mode ()
  "Configurate LSP for `soql-ts-mode'."
  (interactive)
  (let ((langserver-dir (concat soql-ts-mode--root-dir "language-server/")))

    (setq-local lsp-bridge-user-langserver-dir langserver-dir)

    (lsp-bridge-mode)))

;; EGLOT
;;;###autoload
(defun soql-ts-mode--generate-server-lsp-command ()
  "generate command run apex server."
  `(,soql-ts-mode--lsp-path "--stdio"))

;; Eglot config for soql
(defcustom soql-ts-mode--eglot-config '()
  "JSON use for LSP initialization config."
  :type 'list
  :group 'soql)

;;;###autoload
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(soql-ts-mode . (,@(soql-ts-mode--generate-server-lsp-command)
                                 ,@soql-ts-mode--eglot-config))))

(provide 'soql-lsp)
