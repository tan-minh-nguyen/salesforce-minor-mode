;;; LWC ts mode -- tree-sitter support for LWC -*- lexical-binding: t; -*-

(require 'lwc-ts-common)
(require 'lwc-js-ts-mode)
(require 'lwc-html-ts-mode)

;; config eglot
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               (cons '((lwc-html-ts-mode :language-id "lwc-html")
                       (lwc-js-ts-mode :language-id "lwc-javascript"))
                     `(,lwc-ts-mode--lsp-path "--stdio" ,@lwc-ts-mode--eglot-config))))

(provide 'lwc-ts-mode)
