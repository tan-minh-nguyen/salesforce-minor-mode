;;; apex-ts-mode-yasnippet.el --- configuration yasnippet for Apex mode -*- lexical-binding: t -*-

(defvar apex-ts-mode-snippets-dir (expand-file-name "language-sever" load-file-name)
  "Snippets directory for yasnippets-mode.")

;;;###autoload
(defun apex-ts-mode-yasnippet-initialize ()
  "Initialize the yasnippet setup for `apex-ts-mode'."
  (add-to-list 'yas-snippet-dirs (expand-file-name "snippets" apex-ts-mode--root-dir)))

(provide 'apex-ts-mode-yasnippet)
