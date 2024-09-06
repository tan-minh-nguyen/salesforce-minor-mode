;;; lwc-ts-mode.el -*- lexical-binding: t; -*- LWC mode

(require 'js-ts-mode)
(require 'dx-config)
(require 'dx-core)

(defun lwc-ts-mode-setup ()
  "Initialize Treesiter setup."
  (treesit-parser-create 'javascript)

  ;; TODO: get lwc path directly from dx library
  (add-to-list 'auto-mode-alist `(,(concat (dx--get-lwc-directory) "/.*\\.js\\'") . lwc-ts-mode)))

(define-derived-mode lwc-ts-mode js-ts-mode "Lwc"
  "LWC mode powered by Treesiter."
  :group 'lwc-ts-mode

  (unless (treesit-parser-p 'javascript)
    (error "Treesiter javascript is required."))

  (lwc-ts-mode-setup))

;; Eglot config for apex
(defcustom lwc-ts-mode--eglot-config '(:initializationOptions (:enableEmbeddedSoqlCompletion t))
  "JSON use for LSP initialization config."
  :type 'list
  :group 'apex)

(defcustom apex-ts-mode--lsp-path "~/.local/lwc-lsp/lwc-lsp.jar"
  "Path of LSP bin."
  :type 'string
  :group 'apex)

;;;###autoload
(defun apex-ts-mode--generate-server-lsp-command ()
  "generate command run apex server."
  `("java" "-cp" ,(expand-file-name lwc-ts-mode--lsp-path) "apex.jorje.lsp.ApexLanguageServerLauncher"))

;;;###autoload
(defun lwc-ts-mode--setup-eglot ()
  "Add config eglot for `lwc-ts-mode'."
  (add-to-list 'eglot-server-programs
               `(lwc-ts-mode . (,@(lwc-ts-mode--generate-server-lsp-command)
				,@lwc-ts-mode--eglot-config))))


(provide 'lwc-ts-mode)
