;;; LWC ts mode -- tree-sitter support for LWC -*- lexical-binding: t; -*-

(require 'lwc-ts-common)
(require 'lwc-js-ts-mode)
(require 'lwc-html-ts-mode)

;; config eglot
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `((lwc-js-ts-mode :language-id "javascript") . (,lwc-ts-mode--lsp-path "--stdio" ,@lwc-ts-mode--eglot-config)))
  (add-to-list 'eglot-server-programs
               `((lwc-html-ts-mode :language-id "html") . (,lwc-ts-mode--lsp-path "--stdio" ,@lwc-ts-mode--eglot-config))))


(defun lwc-ts-mode--lwc-file-p ()
  "Check file is LWC."
  (require 'salesforce-project nil 'noerror)
  (and (salesforce-project-p)
     (string-prefix-p (salesforce-core--build-path salesforce-metadata-root-dir salesforce-lwc-dir)
                      (buffer-file-name))))

(defun lwc-ts-mode-auto ()
  "Auto enable majore-mode for file in Salesforce project."
  (when (lwc-ts-mode--lwc-file-p)
    (lwc-ts-mode)))

;;;###autoload
(define-derived-mode lwc-ts-mode fundamental-mode "lwc"
  "Major mode use tree-sitter for Visualforce page, powered by tree-sitter."
  :group 'lwc
  (cond ((string= (file-name-extension (buffer-file-name)) "js")
         (unless (treesit-ready-p 'javascript t)
           (error "Tree-sitter for js isn't available."))
         (lwc-js-ts-mode--js-file))
        ((string= (file-name-extension (buffer-file-name)) "html")
         (unless (treesit-ready-p 'html t)
           (error "Tree-sitter for html isn't available."))
         (lwc-html-ts-mode--html-file)))

  (treesit-major-mode-setup)

  (when (lwc-ts-mode--lwc-file-p)
    (setq-default eglot-workspace-configuration
                  '(:lwc-ts-mode (:documentSelector [(:language "html" :scheme "file")
                                                     (:language "javascript" :scheme "file")
                                                     (:language "typescript" :scheme "file")])))))


;;(add-to-list 'auto-mode-alist '("\\.\\(js\\|html\\)\\'" . lwc-ts-mode-auto))

(provide 'lwc-ts-mode)
