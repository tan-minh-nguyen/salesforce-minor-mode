;;; apex-ts-mode-tempel.el --- configuration tempel for Apex mode -*- lexical-binding: t -*-

(defvar apex-ts-mode-tempel-file (expand-file-name "snippets/templates" apex-load-directory)
  "Snippets file for Tempel.")

;;;###autoload
(defun apex-ts-mode-tempel-initialize ()
  "Initialize the tempel setup for `apex-ts-mode'."
  (add-to-list 'tempel-path apex-ts-mode-tempel-file))

(provide 'apex-ts-mode-tempel)
