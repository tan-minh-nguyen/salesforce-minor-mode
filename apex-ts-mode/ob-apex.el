;;; ob-apex.el --- Org-babel functions for Apex evaluation -*- lexical-binding: t -*-

;; Copyright (C) your name here

;; Author: tan.nguyen.w.information@gmail.com
;; Keywords: literate programming, reproducible research
;; Homepage: https://orgmode.org
;; Version: 0.01

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

;;; Requirements:

;; Requirements:
;; - Salesforce CLI must be installed and configured.
;; - Emacs major mode for Apex should be installed.

;;TODO: support org session for Apex

(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)
(require 'salesforce-core)
(require 'apex-company)
(require 'apex-ts-mode)

(add-to-list 'org-babel-tangle-lang-exts '("apex" . "cls"))

;; Declare default header arguments for Apex code blocks.
(defvar org-babel-default-header-args:apex (list '(:results . "none")
                                              '(:org . "")
                                              '(:filter-type . "DEBUG")
                                              '(:filter-value . nil)))

(defvar org-babel-default-inline-header-args:apex (list '(:results . "none")
                                                     '(:org . "")
                                                     '(:filter-type . "DEBUG")
                                                     '(:filter-value . nil)))

(defvar org-babel-executable-keywords '("VARIABLE_ASSIGNMENT"
                                        "STATEMENT_EXECUTE"
                                        "METHOD_ENTRY"
                                        "CONSTRUCTOR_EXIT"
                                        "CODE_UNIT_STARTED")
  "Keywords use for filter with Executable type.")

(defvar org-babel-system-keywords '("VARIABLE_ASSIGNMENT"
                                    "STATEMENT_EXECUTE"
                                    "METHOD_ENTRY"
                                    "CONSTRUCTOR_EXIT"
                                    "CODE_UNIT_STARTED")
  "Keywords use for filter with System type.")

(defvar org-babel-debug-keywords '("VARIABLE_ASSIGNMENT"
                                   "STATEMENT_EXECUTE"
                                   "METHOD_ENTRY"
                                   "CONSTRUCTOR_EXIT"
                                   "CODE_UNIT_STARTED")
  "Keywords use for filter with Debug type.")

(defvar org-babel-governor-keywords '("LIMIT_USAGE_FOR_NS"
                                      "Number of"
                                      "Maximum CPU"
                                      "Maximum heap")
  "Keywords use for filter with Government type.")

(defun org-babel-expand-body:apex (body params &optional processed-params)
  "Expand BODY according to PARAMS, return the expanded body.
This function prepares the Apex code by adding variable declarations
based on the provided parameters."
  (let ((vars
         (org-babel--get-vars
          (or processed-params
             (org-babel-process-params params)))))

    (concat
     (mapconcat #'ob-apex--binding-declare-variable vars "\n")
     "\n" body "\n")))

;;;###autoload
(defun org-babel-execute:apex (body params)
  "Execute a block of Apex code with org-babel.
BODY is the content of the code block, and PARAMS are the header arguments."
  (let* ((processed-params (org-babel-process-params params))
         (full-body (org-babel-expand-body:apex
                        body params processed-params)))

    (ob-apex--execute-apex-code processed-params full-body)))

(defun ob-apex--get-param (key param-list)
  "Extract the parameter value associated with KEY from PARAM-LIST."
  (cdr (assq key param-list)))

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
The filter function checks if a line matches the specified TYPE and contains VALUE."
  (let ((base-filter-fn
         (cond ((string-equal-ignore-case type "DEBUG")
                (lambda (line) (search "DEBUG" line)))
               ((string-equal-ignore-case type "EXECUTABLE")
                (lambda (line) (string-match (regexp-opt org-babel-executable-keywords) line)))
               ((string-equal-ignore-case type "SYSTEM")
                (lambda (line) (string-match (regexp-opt org-babel-system-keywords) line)))
               ((string-equal-ignore-case type "GOVERNOR")
                (lambda (line) (match-string (regexp-opt org-babel-governor-keywords) line)))
               (t (lambda (_) nil)))))
    (if (and value (not (string-equal value "")))
        (lambda (line) (and (funcall base-filter-fn line) (search value line)))
      base-filter-fn)))

(defun ob-apex--execute-apex-code (processed-params content)
  "Execute Apex code in Org source.
PROCESSED-PARAMS are the parameters for execution, and CONTENT is the code to execute."
  (let* ((uuid (org-id-uuid))
         (buffer (current-buffer))
         (tempfile (make-temp-file "temp-code"))
         (result-eval (ob-apex--get-param :results processed-params))
         (log-filter-type (ob-apex--get-param :filter-type processed-params))
         (log-filter-value (ob-apex--get-param :filter-value processed-params)))

    (write-region content nil tempfile)

    ;; Clear default result
    (org-babel-remove-result)

    (unless (string-equal-ignore-case result-eval "none")
      (re-search-forward "#\\+end_src")
      ;; Insert new result with uuid
      (insert (format "\n#+RESULTS:\n#+begin_src apex-log :uuid %s\n %s\n#+end_src"
                      uuid
                      uuid)))

    (salesforce-core--apex-process
     :cmd `("run" "-f" ,tempfile "-o" ,(cdr (assq :org processed-params)) "--json")
     (unless (string-equal-ignore-case result-eval "none")
       (with-current-buffer buffer
         ;; Replace uuid with log content
         (save-excursion
           (beginning-of-buffer)
           (re-search-forward uuid nil t 2)
           (delete-line)

           (insert (ob-apex--filter-log (salesforce-core--get-data-json "result.logs" json-instance)
                                        log-filter-type
                                        log-filter-value)))))

     (alert "Run apex code complete"
            :title "Salesforce Alert"))))

(defun ob-apex--binding-declare-variable (pair)
  "Handle binding value of variable to execute content.
PAIR is a cons cell of variable name and value."
  (cl-loop for (key . value) in pair
           as cast-value = (format "%s" value)
           concat (ob-apex--build-var-code key cast-value)))

(defun ob-apex--build-var-code (key value)
  "Build variable declaration code for Apex.
KEY is the variable name, and VALUE is the variable value."
  (let* ((type (ob-apex--determine-type value))
         (apex-type (ob-apex--get-apex-type type))
         (formatted-value (ob-apex--format-value type value)))
    (format "%s %s = %s;" apex-type key formatted-value)))

(defun ob-apex--determine-type (value)
  "Determine the type of VALUE for Apex variable declaration."
  (cond ((string-match-p "^'" value) "string")
        ((string-match-p "^[1-9]+$" value) "number")
        ((string-match-p "^([Tt]rue|[Ff]alse)$" value) "boolean")
        (t "object")))

(defun ob-apex--get-apex-type (type)
  "Get the Apex type corresponding to TYPE for variable declaration."
  (pcase type
    ("string" "String")
    ("number" "Decimal")
    ("boolean" "Boolean")
    (_ "Object")))

(defun ob-apex--format-value (type value)
  "Format VALUE based on its TYPE for Apex variable declaration."
  (pcase type
    ("string" (format "'%s'" value))
    ("number" value)
    ("boolean" value)
    (_ (format "new %s" value))))

(defun org-babel-prep-session:apex (session params)
  "Prepare SESSION according to the header arguments specified in PARAMS.
This function is currently a placeholder and does not perform any actions.")

(defun org-babel-elisp-var-to-apex (var)
  "Convert an elisp VAR into a string of Apex source code specifying a var of the same value."
  (format "%s" var))

;; Hints value based on value of header arguments
;; FIXME: Trigger eglot in specific workspace
(when (require 'company-org-header nil 'noerror)
  (defcustom ob-apex-header-completions `((:workspace . salesforce-core--projects)
                                          (:org . salesforce-core--orgs))
    "Handles completions for org headers."
    :type 'alist
    :group 'ob-apex)

  (defcustom ob-apex-src-code-hook '(ob-apex-initialize-completion)
    "List of hooks to run when editing SOQL source code blocks."
    :type '(repeat function)
    :group 'ob-apex)

  (defun ob-apex-initialize-completion ()
    "Initialize the SOQL completion hook."
    (when-let ((default-directory (assoc-default :workspace company-header-args)))))
      ;; (call-interactively #'eglot)
      
  (add-to-list 'company-header-src-block-hooks `(apex-ts-mode . ,ob-apex-src-code-hook))
  (add-to-list 'company-header-handles `(apex-ts . ,ob-apex-header-completions)))

(defun org-babel-template-table-or-string (results)
  "Convert RESULTS into an Emacs-lisp table if they look like a table, otherwise return as a string.")

(defun org-babel-template-initiate-session (&optional session)
  "Create and return an initialized SESSION if there is not a current inferior-process-buffer.")

(defun ob-apex-company ()
  "Enable company mode for Apex org-babel integration."
  (when (apex-ts-mode-p)
    (apex-company-setup)))

(add-hook 'org-src-mode-hook #'ob-apex-company)

(provide 'ob-apex)
