;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-core)
(require 'treesit)

;; (defun dx-soql-string ()
;;   "Fetch salesforce record by calling API through Salesforce CLI library"
;;   (interactive)
;;   (let* ((cache-dir (dx--get-cache-folder-path))
;;          ;; config local hook for minibuffer
;;          (minibuffer-history (cl-remove-if (lambda (item)
;;                                              (not (null (s-index-of item "SELECT"))))
;;                                            minibuffer-history))
;;          (minibuffer-mode-hook '(soql-ts-mode))
;;          (max-mini-window-height 5))
;; 
;;     (dx-execute-soql :query (completing-read "SOQL: " minibuffer-history nil 'require-match))))
;; 
;; (defun dx-fetch-record-through-file ()
;;   "Fetch record through file."
;;   (interactive)
;;   (dx-execute-soql :file (read-file-name "SOQL File: ")))

(provide 'dx-query)
