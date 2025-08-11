;;; salesforce-transient-menu.el --- define transient menu for salesforce-minor-mode -*- lexical-binding: t -*-

(require 'transient)

(defvar-local salesforce--transient-menu:output-dir ""
  "Default path for generate resources.")

(transient-define-argument salesforce--transient-menu:-o ()
  :class 'transient-option
  :description "set target org for command"
  :key "-o"
  :shortarg "-o"
  :argument "--target-org="
  :reader #'salesforce-core--transient-menu:--target-org-reader
  :init-value #'salesforce--transient-menu:--target-org-handler)   

(transient-define-argument salesforce--transient-menu:--api-version ()
  :class 'transient-option
  :description "set api version for command"
  :key "-v"
  :shortarg "--api-version"
  :argument "--api-version="
  :reader #'salesforce--transient-menu:--api-version-reader
  :init-value #'salesforce--transient-menu:--api-version-handler)

(transient-define-argument salesforce--transient-menu:-d ()
  :class 'transient-option
  :description "file save export result"
  :key "-d"
  :shortarg "-d"
  :argument "--output-dir="
  :reader #'salesforce--transient-menu:read-directory
  :init-value #'salesforce--transient-menu:--output-dir-handler)

(defun salesforce--transient-menu:--api-version-reader (prompt initial-input history)
  "Read a org alias and return org string."
  (salesforce--transient-menu:read-string prompt initial-input history "Please enter a API Version."))

(defun salesforce--transient-menu:read-string (prompt initial-input history &optional message-error)
  "Read input string in transient menu."
  (save-match-data
    (cl-block nil
      (while t
        (let ((str (read-from-minibuffer prompt initial-input nil nil history)))
          (unless (string-equal str "")
            (cl-return str)))
        (message (or message-error "Please input value."))
        (sit-for 1)))))

(defun salesforce--transient-menu:read-directory (prompt initial-input history &optional message-error)
  "Read input directory in transient menu."
  (save-match-data
    (cl-block nil
      (while t
        (let ((str (read-directory-name prompt initial-input)))
          (unless (string-equal str "")
            (cl-return (expand-file-name str))))
        (message (or message-error "Please select a directory name."))
        (sit-for 1)))))

(defun salesforce--transient-menu:read-file (prompt initial-input history &optional message-error)
  "Read input file in transient menu."
  (save-match-data
    (cl-block nil
      (while t
        (let ((str (read-file-name prompt nil initial-input)))
          (unless (string-equal str "")
            (cl-return str)))
        (message (or message-error "Please select a file name."))
        (sit-for 1)))))

(defun salesforce--transient-menu:--target-org-reader (prompt initial-input history)
  "Read a org alias and return org string."
  (completing-read "Org name: " nil))

(defun salesforce--transient-menu:--api-version-handler (obj)
  "Set default value for --api-version param."
  (when salesforce-api-version
    (transient-infix-set obj (format "%s" salesforce-api-version))))

(defun salesforce--transient-menu:--target-org-handler (obj)
  "Set default value for --api-version param."
  (when salesforce-org-name
    (transient-infix-set obj (format "%s" salesforce-org-name))))

(defun salesforce--transient-menu:--output-dir-handler (obj)
  "Set default value for --output-api param."
  (transient-infix-set obj (format "%s" salesforce--transient-menu:output-dir)))

(provide 'salesforce-transient-menu)
