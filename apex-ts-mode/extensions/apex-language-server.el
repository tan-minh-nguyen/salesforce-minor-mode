;;; apex-language-server.el --- configuration apex LSP -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(defcustom apex-lsp-install-path (expand-file-name "lsp/apex-lsp.jar" user-emacs-directory)
  "Path install Apex LSP.")

(defcustom apex-lsp-link-download "https://raw.githubusercontent.com/forcedotcom/salesforcedx-vscode/develop/packages/salesforcedx-vscode-apex/jars/apex-jorje-lsp.jar"
  "Link download Apex LSP.")

(defcustom apex-lsp-path (expand-file-name "lsp/apex-lsp.jar" user-emacs-directory)
  "Path of LSP bin."
  :type 'string
  :group 'apex-eglot)

;; Eglot config for apex
(defcustom apex-lsp-eglot-config '(:initializationOptions (:enableEmbeddedSoqlCompletion t))
  "JSON use for LSP initialization config."
  :type 'list
  :group 'apex-eglot)

(defun apex-lsp--generate-server-lsp-command ()
  "generate command run apex server."
  `("java" "-cp" ,(expand-file-name apex-lsp-path) "apex.jorje.lsp.ApexLanguageServerLauncher"))

(defvar apex-lsp-bridge-language-dir (expand-file-name "language-sever" (file-name-directory load-file-name))
  "Language server configuration for LSP bridge.")

(defun apex-lsp-setup-bridge ()
  "Setup LSP bridge for project."
  (setq-local lsp-bridge-user-langserver-dir apex-lsp-bridge-language-dir))

(defun apex-lsp-install-server ()
  "Install LSP server for apex-mode."
  (interactive)
  (unless (executable-find "curl")
    (error "curl file not found."))
  (unless (file-exists-p (file-name-directory apex-lsp-install-path))
    (make-directory (file-name-directory apex-lsp-install-path)))

  (if (and (file-exists-p apex-lsp-install-path)
         (yes-or-no-p "are you want to reinstall Apex LSP ?."))
      (apex-download-lsp-file apex-lsp-install-path)
    (apex-download-lsp-file apex-lsp-install-path)))

(defun apex-download-lsp-file (save-path)
  "Download Apex LSP file into SAVE-PATH."
  (make-process
   :name "install-apex-LSP"
   :command `("curl" "-L" "-o" ,save-path ,apex-lsp-link-download)
   :filter
   (lambda (&rest args)
     (message "installing apex LSP..."))
   :sentinel
   (lambda (proc event)
     (pcase event
       ("finished\n" (message "install Apex LSP successfully."))
       (_ (message event))))))

;;;#autoload
(defun apex-language-server-bridge ()
  "Configures LSP Bridge"
  ;; Load Apex language server
  (add-to-list 'lsp-bridge-single-lang-server-mode-list '(apex-ts-mode . "apex"))
  (add-to-list 'lsp-bridge-formatting-indent-alist '(apex-ts-mode . apex-ts-mode-indent-offset)))

;;;#autoload
(defun apex-language-server-eglot ()
  "Configures LSP Eglot"

  (add-to-list 'eglot-server-programs
               (cons 'apex-ts-mode `(,@(apex-lsp--generate-server-lsp-command)
                                     ,@apex-lsp-eglot-config))))

(provide 'apex-language-server)
