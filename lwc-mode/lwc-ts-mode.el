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


;; Auto detect file
(defun lwc-ts-mode--lwc-file ()
  "Dectect file in lwc directory `lwc-ts-mode'."
  (when-let ((_ (dx-project-p))
             (lwc-dir (expand-file-name dx-default-lwc-path (projectile-project-root))))
    (string-search lwc-dir (buffer-file-name))))

;;;###autoload
(defun lwc-ts-mode-enable-safe ()
  "Enable `lwc-ts-mode'."
  (interactive)
  (cond ((and (lwc-ts-mode--lwc-file)
            (eq (file-name-extension (buffer-file-name)) "js"))
         (lwc-js-ts-mode))
        ((and (lwc-ts-mode--lwc-file)
            (eq (file-name-extension (buffer-file-name)) "html"))
         (lwc-html-ts-mode))))

(add-to-list 'auto-mode-alist '("\\.\\(js\\|html\\)\\'" . lwc-ts-mode-enable-safe))

(provide 'lwc-ts-mode)
