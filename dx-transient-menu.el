;;; dx-transient-menu.el --- define transient menu for dx-minor-mode -*- lexical-binding: t -*-

(defvar-local dx--transient-menu:output-dir ""
  "Default path for generate resources.")

(transient-define-argument dx--transient-menu:-o ()
  :class 'transient-option
  :description "set target org for command"
  :key "-o"
  :shortarg "-o"
  :argument "--target-org="
  :reader #'dx--transient-menu:--target-org-reader
  :init-value #'dx--transient-menu:--target-org-handler)   

(transient-define-argument dx--transient-menu:--api-version ()
  :class 'transient-option
  :description "set api version for command"
  :key "-v"
  :shortarg "--api-version"
  :argument "--api-version="
  :reader #'dx--transient-menu:--api-version-reader
  :init-value #'dx--transient-menu:--api-version-handler)

(transient-define-argument dx--transient-menu:-d ()
  :class 'transient-option
  :description "file save export result"
  :key "-d"
  :shortarg "-d"
  :argument "--output-dir="
  :reader #'dx--transient-menu:read-directory
  :init-value #'dx--transient-menu:--output-dir-handler)

(defun dx--transient-menu:--api-version-reader (prompt initial-input history)
  "Read a org alias and return org string."
  (dx--transient-menu:read-string prompt initial-input history "Please enter a API Version."))

(defun dx--transient-menu:read-string (prompt initial-input history &optional message-error)
  "Read input string in transient menu."
  (save-match-data
    (cl-block nil
      (while t
        (let ((str (read-from-minibuffer prompt initial-input nil nil history)))
          (unless (string-equal str "")
            (cl-return str)))
        (message (or message-error "Please input value."))
        (sit-for 1)))))

(defun dx--transient-menu:read-directory (prompt initial-input history &optional message-error)
  "Read input directory in transient menu."
  (save-match-data
    (cl-block nil
      (while t
        (let ((str (read-directory-name prompt initial-input)))
          (unless (string-equal str "")
            (cl-return (expand-file-name str))))
        (message (or message-error "Please select a directory name."))
        (sit-for 1)))))

(defun dx--transient-menu:read-file (prompt initial-input history &optional message-error)
  "Read input file in transient menu."
  (save-match-data
    (cl-block nil
      (while t
        (let ((str (read-file-name prompt nil initial-input)))
          (unless (string-equal str "")
            (cl-return str)))
        (message (or message-error "Please select a file name."))
        (sit-for 1)))))

(defun dx--transient-menu:--target-org-reader (prompt initial-input history)
  "Read a org alias and return org string."
  (completing-read "Org name: " nil))

(defun dx--transient-menu:--api-version-handler (obj)
  "Set default value for --api-version param."
  (when dx-api-version
    (transient-infix-set obj (format "%s" dx-api-version))))

(defun dx--transient-menu:--target-org-handler (obj)
  "Set default value for --api-version param."
  (when dx-org-name
    (transient-infix-set obj (format "%s" dx-org-name))))

(defun dx--transient-menu:--output-dir-handler (obj)
  "Set default value for --output-api param."
  (transient-infix-set obj (format "%s" dx--transient-menu:output-dir)))

(provide 'dx-transient-menu)
