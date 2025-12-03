;;; salesforce-menu.el --- Transient menu definitions for Salesforce -*- lexical-binding: t -*-

;;; Commentary:
;; This package provides transient menu definitions and utilities for
;; Salesforce minor mode, including common argument definitions and
;; input readers for various data types.

;;; Code:

(require 'transient)

;;; Variables

(defvar-local salesforce--menu:output-dir ""
  "Default path for generating resources.")

;;; Transient Argument Definitions

(transient-define-argument salesforce--menu:-o ()
  :class 'transient-option
  :description "Target org for command"
  :key "-o"
  :shortarg "-o"
  :argument "--target-org="
  :reader #'salesforce--menu:--target-org-reader
  :init-value #'salesforce--menu:--target-org-handler)

(transient-define-argument salesforce--menu:--api-version ()
  :class 'transient-option
  :description "API version for command"
  :key "-v"
  :shortarg "--api-version"
  :argument "--api-version="
  :reader #'salesforce--menu:--api-version-reader
  :init-value #'salesforce--menu:--api-version-handler)

(transient-define-argument salesforce--menu:-d ()
  :class 'transient-option
  :description "Output directory"
  :key "-d"
  :shortarg "-d"
  :argument "--output-dir="
  :reader #'salesforce--menu:read-directory
  :init-value #'salesforce--menu:--output-dir-handler)

;;; Reader Functions

(defun salesforce--menu:read-string (prompt initial-input history 
                                            &optional message-error)
  "Read a non-empty string from the minibuffer with validation.
PROMPT is displayed to the user.
INITIAL-INPUT is the default value.
HISTORY is the history list to use.
MESSAGE-ERROR is shown when input is empty (defaults to generic message)."
  (save-match-data
    (cl-block nil
      (while t
        (let ((str (read-from-minibuffer prompt initial-input nil nil history)))
          (unless (string-empty-p str)
            (cl-return str)))
        (message (or message-error "Please input a value."))
        (sit-for 1)))))

(defun salesforce--menu:read-directory (prompt initial-input history 
                                               &optional message-error)
  "Read a directory path from the minibuffer with validation.
PROMPT is displayed to the user.
INITIAL-INPUT is the default directory.
HISTORY is the history list to use.
MESSAGE-ERROR is shown when no directory is selected."
  (save-match-data
    (cl-block nil
      (while t
        (let ((str (read-directory-name prompt initial-input)))
          (unless (string-empty-p str)
            (cl-return (expand-file-name str))))
        (message (or message-error "Please select a directory."))
        (sit-for 1)))))

(defun salesforce--menu:read-file (prompt initial-input history 
                                          &optional message-error)
  "Read a file path from the minibuffer with validation.
PROMPT is displayed to the user.
INITIAL-INPUT is the default file.
HISTORY is the history list to use.
MESSAGE-ERROR is shown when no file is selected."
  (save-match-data
    (cl-block nil
      (while t
        (let ((str (read-file-name prompt nil initial-input)))
          (unless (string-empty-p str)
            (cl-return str)))
        (message (or message-error "Please select a file."))
        (sit-for 1)))))

(defun salesforce--menu:read-number (prompt initial-input history 
                                            &optional message-error)
  "Read a number from the minibuffer with validation.
PROMPT is displayed to the user.
INITIAL-INPUT is the default number.
HISTORY is the history list to use.
MESSAGE-ERROR is shown when input is not a valid number."
  (save-match-data
    (cl-block nil
      (while t
        (let ((num (read-number prompt initial-input)))
          (when num
            (cl-return num)))
        (message (or message-error "Please input a number."))
        (sit-for 1)))))

;;; Specialized Readers

(defun salesforce--menu:--target-org-reader (prompt initial-input history)
  "Read an org alias/name from available orgs.
PROMPT is displayed to the user.
INITIAL-INPUT is the default value.
HISTORY is the history list to use."
  (completing-read prompt nil))

(defun salesforce--menu:--api-version-reader (prompt initial-input history)
  "Read an API version string.
PROMPT is displayed to the user.
INITIAL-INPUT is the default value.
HISTORY is the history list to use."
  (salesforce--menu:read-string prompt initial-input history 
                                "Please enter an API version."))

;;; Init Value Handlers

(defun salesforce--menu:--api-version-handler (obj)
  "Set default value for --api-version parameter in OBJ.
Uses the value from `salesforce-api-version'."
  (when salesforce-api-version
    (transient-infix-set obj (format "%s" salesforce-api-version))))

(defun salesforce--menu:--target-org-handler (obj)
  "Set default value for --target-org parameter in OBJ.
Uses the value from `salesforce-org-name'."
  (when salesforce-org-name
    (transient-infix-set obj (format "%s" salesforce-org-name))))

(defun salesforce--menu:--output-dir-handler (obj)
  "Set default value for --output-dir parameter in OBJ.
Uses the value from `salesforce--menu:output-dir'."
  (transient-infix-set obj (format "%s" salesforce--menu:output-dir)))

(provide 'salesforce-menu)

;;; salesforce-menu.el ends here
