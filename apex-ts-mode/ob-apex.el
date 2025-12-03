;;; ob-apex.el --- Org-babel functions for Apex evaluation -*- lexical-binding: t -*-

;; Copyright (C) 2025 Tan Nguyen

;; Author: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Version: 0.01
;; Package-Requires: ((emacs "27.1") (org "9.0"))
;; Keywords: literate programming, reproducible research, salesforce, apex
;; Homepage: https://github.com/your/repo

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This file provides support for executing Apex code blocks within Org-mode
;; using org-babel. It includes functions for expanding, executing, and
;; filtering Apex code, as well as handling variable declarations and results.
;;
;; Features:
;; - Execute Apex code blocks in Org-mode
;; - Variable binding and type inference
;; - Log filtering by type (DEBUG, EXECUTABLE, SYSTEM, GOVERNOR)
;; - Automatic result insertion
;;
;; Requirements:
;; - Salesforce CLI must be installed and configured
;; - Emacs major mode for Apex should be installed
;;
;; TODO: Support org session for Apex

;;; Code:

(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)
(require 'salesforce-core)
(require 'apex-ts-mode)

;;; Configuration

(add-to-list 'org-babel-tangle-lang-exts '("apex" . "cls"))

;;; Default Header Arguments

(defvar org-babel-default-header-args:apex 
  '((:results . "none")
    (:org . "")
    (:filter-type . "DEBUG")
    (:filter-value . nil))
  "Default header arguments for Apex code blocks.")

(defvar org-babel-default-inline-header-args:apex 
  '((:results . "none")
    (:org . "")
    (:filter-type . "DEBUG")
    (:filter-value . nil))
  "Default header arguments for inline Apex code blocks.")

;;; Filter Keywords

(defvar org-babel-executable-keywords 
  '("VARIABLE_ASSIGNMENT"
    "STATEMENT_EXECUTE"
    "METHOD_ENTRY"
    "CONSTRUCTOR_EXIT"
    "CODE_UNIT_STARTED")
  "Keywords used for filtering with Executable type.")

(defvar org-babel-system-keywords 
  '("VARIABLE_ASSIGNMENT"
    "STATEMENT_EXECUTE"
    "METHOD_ENTRY"
    "CONSTRUCTOR_EXIT"
    "CODE_UNIT_STARTED")
  "Keywords used for filtering with System type.")

(defvar org-babel-debug-keywords 
  '("VARIABLE_ASSIGNMENT"
    "STATEMENT_EXECUTE"
    "METHOD_ENTRY"
    "CONSTRUCTOR_EXIT"
    "CODE_UNIT_STARTED")
  "Keywords used for filtering with Debug type.")

(defvar org-babel-governor-keywords 
  '("LIMIT_USAGE_FOR_NS"
    "Number of"
    "Maximum CPU"
    "Maximum heap")
  "Keywords used for filtering with Governor type.")

;;; Constants

(defconst ob-apex--result-types '("none" "value" "output")
  "Valid result types for Apex code blocks.")

(defconst ob-apex--filter-types '("DEBUG" "EXECUTABLE" "SYSTEM" "GOVERNOR")
  "Valid filter types for Apex log output.")

;;; Type Mapping

(defconst ob-apex--type-mapping
  '(("string" . "String")
    ("number" . "Decimal")
    ("boolean" . "Boolean")
    ("object" . "Object"))
  "Mapping from internal type names to Apex type names.")

;;; Body Expansion

(defun org-babel-expand-body:apex (body params &optional processed-params)
  "Expand BODY according to PARAMS, return the expanded body.
PROCESSED-PARAMS can be provided to avoid reprocessing.
This function prepares the Apex code by adding variable declarations
based on the provided parameters."
  (let ((vars (org-babel--get-vars
               (or processed-params
                  (org-babel-process-params params)))))
    (concat
     (mapconcat #'ob-apex--declare-variable vars "\n")
     (when vars "\n")
     body "\n")))

;;; Code Execution

;;;###autoload
(defun org-babel-execute:apex (body params)
  "Execute a block of Apex code with org-babel.
BODY is the content of the code block.
PARAMS are the header arguments."
  (let* ((processed-params (org-babel-process-params params))
         (full-body (org-babel-expand-body:apex body params processed-params)))
    (ob-apex--execute-apex-code processed-params full-body)))

(defun ob-apex--execute-apex-code (processed-params content)
  "Execute Apex code in Org source.
PROCESSED-PARAMS are the parameters for execution.
CONTENT is the code to execute."
  (let* ((uuid (org-id-uuid))
         (buffer (current-buffer))
         (tempfile (make-temp-file "temp-code"))
         (result-eval (ob-apex--get-param :results processed-params))
         (org-name (ob-apex--get-param :org processed-params))
         (log-filter-type (ob-apex--get-param :filter-type processed-params))
         (log-filter-value (ob-apex--get-param :filter-value processed-params)))
    
    (write-region content nil tempfile)
    
    ;; Clear default result
    (org-babel-remove-result)
    
    (unless (ob-apex--result-is-none-p result-eval)
      (ob-apex--insert-result-placeholder uuid))
    
    (salesforce-core--apex-process
     :args `("run" "-f" ,tempfile "-o" ,org-name "--json")
     (unless (ob-apex--result-is-none-p result-eval)
       (with-current-buffer buffer
         (save-excursion
           (ob-apex--replace-result-placeholder 
            uuid 
            (ob-apex--filter-log (map-nested-elt json-instance '("result" "logs"))
                                 log-filter-type
                                 log-filter-value)))))
     (alert "Run apex code complete"
            :title "Salesforce Alert"))))

;;; Result Handling

(defun ob-apex--result-is-none-p (result-type)
  "Check if RESULT-TYPE indicates no results should be displayed."
  (string-equal-ignore-case result-type "none"))

(defun ob-apex--insert-result-placeholder (uuid)
  "Insert a result placeholder with UUID at point."
  (re-search-forward "#\\+end_src")
  (insert (format "\n#+RESULTS:\n#+begin_src apex-log :uuid %s\n %s\n#+end_src"
                  uuid uuid)))

(defun ob-apex--replace-result-placeholder (uuid content)
  "Replace the result placeholder identified by UUID with CONTENT."
  (goto-char (point-min))
  (when (re-search-forward uuid nil t 2)
    (delete-line)
    (insert content)))

;;; Log Filtering

(defun ob-apex--filter-log (content type value)
  "Filter CONTENT of the log file based on TYPE and VALUE."
  (let ((filter-fn (ob-apex--get-filter-fn type value)))
    (mapconcat (lambda (line)
                 (when (funcall filter-fn line)
                   (concat line "\n")))
               (split-string content "\n")
               "")))

(defun ob-apex--get-filter-fn (type value)
  "Return the appropriate filter function based on TYPE and VALUE.
The filter function checks if a line matches the specified TYPE 
and optionally contains VALUE."
  (let ((base-filter-fn (ob-apex--get-base-filter-fn type)))
    (if (and value (not (string-empty-p value)))
        (lambda (line) 
          (and (funcall base-filter-fn line) 
               (string-match-p (regexp-quote value) line)))
      base-filter-fn)))

(defun ob-apex--get-base-filter-fn (type)
  "Return the base filter function for TYPE."
  (cond 
   ((string-equal-ignore-case type "DEBUG")
    (lambda (line) (string-match-p "DEBUG" line)))
   ((string-equal-ignore-case type "EXECUTABLE")
    (lambda (line) (string-match-p (regexp-opt org-babel-executable-keywords) line)))
   ((string-equal-ignore-case type "SYSTEM")
    (lambda (line) (string-match-p (regexp-opt org-babel-system-keywords) line)))
   ((string-equal-ignore-case type "GOVERNOR")
    (lambda (line) (string-match-p (regexp-opt org-babel-governor-keywords) line)))
   (t (lambda (_) nil))))

;;; Variable Declaration

(defun ob-apex--declare-variable (pair)
  "Generate Apex variable declaration code from PAIR.
PAIR is a cons cell of (variable-name . value)."
  (let ((key (car pair))
        (value (cdr pair)))
    (ob-apex--build-var-code key (format "%s" value))))

(defun ob-apex--build-var-code (key value)
  "Build variable declaration code for Apex.
KEY is the variable name.
VALUE is the variable value."
  (let* ((type (ob-apex--infer-type value))
         (apex-type (ob-apex--get-apex-type type))
         (formatted-value (ob-apex--format-value type value)))
    (format "%s %s = %s;" apex-type key formatted-value)))

;;; Type Inference

(defun ob-apex--infer-type (value)
  "Infer the type of VALUE for Apex variable declaration."
  (cond 
   ((string-match-p "^'" value) "string")
   ((string-match-p "^[0-9]+\\(?:\\.[0-9]+\\)?$" value) "number")
   ((string-match-p "^\\(?:[Tt]rue\\|[Ff]alse\\)$" value) "boolean")
   (t "object")))

(defun ob-apex--get-apex-type (type)
  "Get the Apex type corresponding to internal TYPE."
  (or (cdr (assoc type ob-apex--type-mapping))
      "Object"))

(defun ob-apex--format-value (type value)
  "Format VALUE based on its TYPE for Apex variable declaration."
  (pcase type
    ("string" (format "'%s'" (string-trim value "'" "'")))
    ("number" value)
    ("boolean" value)
    (_ (format "new %s()" value))))

;;; Utility Functions

(defun ob-apex--get-param (key param-list)
  "Extract the parameter value associated with KEY from PARAM-LIST."
  (cdr (assq key param-list)))

;;; Session Support (Placeholder)

(defun org-babel-prep-session:apex (session params)
  "Prepare SESSION according to the header arguments specified in PARAMS.
This function is currently a placeholder and does not perform any actions.
TODO: Implement session support for Apex."
  (error "Sessions are not yet supported for Apex code blocks"))

;;; Variable Conversion (Placeholder)

(defun org-babel-apex-var-to-apex (var)
  "Convert an elisp VAR into a string of Apex source code.
Specifies a variable of the same value."
  (format "%s" var))

;;; Template Functions (Unused - Consider Removal)

(defun org-babel-apex-table-or-string (results)
  "Convert RESULTS into an Emacs-lisp table or return as a string.
This function is currently a placeholder.
TODO: Implement proper result handling or remove if unused."
  results)

(defun org-babel-apex-initiate-session (&optional session)
  "Create and return an initialized SESSION.
If SESSION already exists, return the existing session.
This function is currently a placeholder.
TODO: Implement session initialization or remove if unused."
  (error "Sessions are not yet supported for Apex code blocks"))

(provide 'ob-apex)

;;; ob-apex.el ends here
