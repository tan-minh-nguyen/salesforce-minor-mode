;;; apex-log-ts-mode.el --- Apex log syntax highlighting with tree-sitter -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Free Software Foundation, Inc.

;; Author: Tan Nguyen
;; Maintainer: Tan Nguyen
;; Created: January 2024
;; Keywords: languages apex salesforce tree-sitter
;; URL: https://github.com/your-repo/salesforce-minor-mode
;; Package-Requires: ((emacs "29.1") (s "1.12.0"))

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides major mode support for Salesforce Apex debug log files
;; using tree-sitter for syntax highlighting and parsing.
;;
;; Features:
;; - Syntax highlighting for log events, timestamps, and governor limits
;; - Header line showing governor limit usage
;; - Tree-sitter based parsing for accurate highlighting
;;
;; Usage:
;;   (require 'apex-log-ts-mode)
;;   ;; Opens .log files in apex-log-ts-mode automatically

;;; Code:

(require 'treesit)
(require 'cl-lib)
(require 's)

;;; Customization

(defgroup apex-log nil
  "Major mode for editing Apex debug log files."
  :group 'languages
  :prefix "apex-log-")

(defcustom apex-log-governor-table
  '(("Number of SOQL queries" . "SOQL")
    ("Number of query rows" . "SOQL rows")
    ("Number of SOSL queries" . "SOSL")
    ("Number of DML statements" . "DML")
    ("Number of Publish Immediate DML" . "Pub DML")
    ("Number of DML rows" . "DML rows")
    ("Maximum CPU time" . "CPU")
    ("Maximum heap size" . "Heap")
    ("Number of callouts" . "Callouts")
    ("Number of Email Invocations" . "Email")
    ("Number of future calls" . "Future")
    ("Number of queueable jobs added to the queue" . "Jobs")
    ("Number of Mobile Apex push calls" . "Push"))
  "Mapping of governor limit names to their abbreviated display forms.
Each entry is a cons cell (FULL-NAME . SHORT-NAME) where:
  FULL-NAME is the complete governor limit name as it appears in logs
  SHORT-NAME is the abbreviated form shown in the header line."
  :type '(alist :key-type string :value-type string)
  :group 'apex-log)

(defcustom apex-log-show-header-line t
  "Whether to show governor limits in the header line.
When non-nil, displays a summary of governor limit usage in the header line."
  :type 'boolean
  :group 'apex-log)

(defcustom apex-log-header-warning-threshold 0.8
  "Threshold for displaying governor limits in warning color.
When a limit's usage exceeds this percentage (0.0 to 1.0),
it will be displayed with a warning face."
  :type 'float
  :group 'apex-log)

(defcustom apex-log-header-critical-threshold 0.95
  "Threshold for displaying governor limits in critical color.
When a limit's usage exceeds this percentage (0.0 to 1.0),
it will be displayed with a critical/error face."
  :type 'float
  :group 'apex-log)

(defcustom apex-log-header-separator "  │  "
  "Separator string between governor limits in the header line."
  :type 'string
  :group 'apex-log)

;;; Variables

(defvar apex-log-ts-mode--indent-rules
  `((apex-log
     ((parent-is "log_header") column-0 0)))
  "Tree-sitter indentation rules for `apex-log-ts-mode'.")

(defvar apex-log-ts-mode--keywords
  '("APEX_CODE" "DEBUG" "APEX_PROFILING" "CALLOUT"
    "DB" "NBA" "SYSTEM" "VALIDATION" "VISUALFORCE" "WAVE"
    "WORKFLOW" "EXTERNAL")
  "Apex log category keywords for syntax highlighting.")

(defvar apex-log-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'apex-log
   :feature 'version
   '((log_header (version)) @font-lock-constant-face)
   
   :language 'apex-log
   :feature 'event
   '((log_entry
      (timestamp
       (time) @font-lock-comment-face
       (duration) @font-lock-number-face)
      (event_identifier) @font-lock-constant-face)
     (location [(number) "EXTERNAL"] @font-lock-type-face)
     (event_detail) @font-lock-variable-name-face
     (event_detail_value) @font-lock-string-face)

   :language 'apex-log
   :feature 'limit
   '((limit
      (identifier) @font-lock-builtin-face
      (number) @font-lock-regexp-face
      (number) @font-lock-constant-face))

   :language 'apex-log
   :override t
   :feature 'keyword
   `([,@apex-log-ts-mode--keywords] @font-lock-keyword-face)

   :language 'apex-log
   :override t
   :feature 'delimiter
   '(["|" ":"] @font-lock-delimiter-face))
  "Tree-sitter font-lock settings for `apex-log-ts-mode'.")

;;; Helper Functions

(defun apex-log-ts-mode--governor-short-name (full-name)
  "Convert governor limit FULL-NAME to its short form.
Returns the abbreviated name from `apex-log-governor-table',
or the original name if no mapping exists."
  (or (cdr (assoc full-name apex-log-governor-table))
     full-name))

(defun apex-log-ts-mode--calculate-usage-percentage (consumed available)
  "Calculate usage percentage from CONSUMED and AVAILABLE values.
Both arguments should be strings representing numbers.
Returns a float between 0.0 and 1.0, or nil if calculation fails."
  (condition-case nil
      (let ((consumed-num (string-to-number consumed))
            (available-num (string-to-number available)))
        (if (> available-num 0)
            (/ (float consumed-num) available-num)
          0.0))
    (error nil)))

(defun apex-log-ts-mode--get-usage-face (percentage)
  "Return the appropriate face for usage PERCENTAGE.
PERCENTAGE should be a float between 0.0 and 1.0."
  (cond
   ((>= percentage apex-log-header-critical-threshold)
    'error)
   ((>= percentage apex-log-header-warning-threshold)
    'warning)
   (t 'success)))

(defun apex-log-ts-mode--format-governor-limit (node)
  "Format a governor limit NODE for display in header line.
NODE should be a tree-sitter node representing a governor limit.
Returns a propertized string with color-coding based on usage.
Format: \"NAME: consumed/available\" with appropriate face."
  (let* ((name-node (treesit-node-child-by-field-name node "name"))
         (consumed-node (treesit-node-child-by-field-name node "consumed"))
         (available-node (treesit-node-child-by-field-name node "available"))
         (full-name (s-trim (treesit-node-text name-node t)))
         (short-name (apex-log-ts-mode--governor-short-name full-name))
         (consumed (treesit-node-text consumed-node t))
         (available (treesit-node-text available-node t))
         (percentage (apex-log-ts-mode--calculate-usage-percentage consumed available))
         (face (when percentage (apex-log-ts-mode--get-usage-face percentage)))
         (formatted (format "%s: %s/%s" short-name consumed available)))
    (if face
        (propertize formatted 'face face)
      formatted)))

;;;###autoload
(defun apex-log-ts-mode--update-header-line ()
  "Update header line with governor limit information from current buffer.
Parses all governor limits from the log file and displays them
in a compact format in the header line with color-coding based on usage."
  (when apex-log-show-header-line
    (if-let* ((root-node (treesit-buffer-root-node))
              (governor-limits (treesit-query-capture root-node '((limit) @limit))))
        (setq-local header-line-format
                    (string-join
                     (mapcar (lambda (capture)
                               (apex-log-ts-mode--format-governor-limit (cdr capture)))
                             governor-limits)
                     apex-log-header-separator))
      (setq-local header-line-format nil))))

;;;###autoload
(defun apex-log-toggle-header-line ()
  "Toggle the display of governor limits in the header line."
  (interactive)
  (setq-local apex-log-show-header-line (not apex-log-show-header-line))
  (if apex-log-show-header-line
      (progn
        (apex-log-ts-mode--update-header-line)
        (message "Governor limits header line enabled"))
    (setq-local header-line-format nil)
    (message "Governor limits header line disabled")))

(defun apex-log-ts-mode--setup ()
  "Configure buffer-local settings for `apex-log-ts-mode'."
  ;; Indentation
  (setq-local treesit-simple-indent-rules apex-log-ts-mode--indent-rules)
  
  ;; Font-lock
  (setq-local treesit-font-lock-settings apex-log-ts-mode--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((event keyword limit)
                (delimiter version)))

  ;; Finalize tree-sitter setup
  (treesit-major-mode-setup))

;;; Major Mode Definition

(defvar-keymap apex-log-ts-mode-map
  :doc "Keymap for `apex-log-ts-mode'."
  "C-c C-h" #'apex-log-toggle-header-line)

;;;###autoload
(define-derived-mode apex-log-ts-mode prog-mode "Apex Log"
  "Major mode for viewing Salesforce Apex debug log files.

This mode provides syntax highlighting for Apex log files using
tree-sitter, including:
  - Log events and timestamps with duration
  - Governor limits and resource usage (color-coded)
  - Debug statements and categories
  - Stack traces and code locations

Governor Limit Header:
  The header line displays a summary of all governor limits with
  color-coding based on usage:
    - Green: Normal usage (< 80%)
    - Yellow/Warning: High usage (80-95%)
    - Red/Error: Critical usage (>= 95%)

  Toggle the header display with \\[apex-log-toggle-header-line].

Customization:
  - `apex-log-show-header-line': Enable/disable header line display
  - `apex-log-header-warning-threshold': Warning color threshold (0.0-1.0)
  - `apex-log-header-critical-threshold': Critical color threshold (0.0-1.0)
  - `apex-log-header-separator': Separator between limits in header
  - `apex-log-governor-table': Mapping of limit names to abbreviations

\\{apex-log-ts-mode-map}"
  :group 'apex-log
  :after-hook (apex-log-ts-mode--update-header-line)
  
  (unless (treesit-ready-p 'apex-log)
    (error "Tree-sitter grammar for Apex log is not available"))

  ;; Create parser
  (treesit-parser-create 'apex-log)
  
  ;; Setup mode
  (apex-log-ts-mode--setup))

;;; Auto-mode association

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.log\\'" . apex-log-ts-mode))

(provide 'apex-log-ts-mode)

;;; apex-log-ts-mode.el ends here
