;;; ob-soql-vars.el --- SOQL query strings for Apex -*- lexical-binding: t -*-

;; Copyright (C) 2024 Free Software Foundation, Inc.

;; Author     : Tan Nguyen
;; Maintainer : Tan Nguyen
;; Created    : December 2024
;; Keywords   : soql apex salesforce org-babel
;; Package-Requires: ((emacs "29.1"))
;; Version    : 1.0.0

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
;;
;; Store SOQL query strings so Apex blocks can execute them with proper typing.
;; Extracts SObject type from query to generate type-safe Apex code.
;;
;; Usage:
;;   #+NAME: my-accounts
;;   #+BEGIN_SRC soql
;;   SELECT Id, Name FROM Account LIMIT 10
;;   #+END_SRC
;;
;;   #+BEGIN_SRC apex :var accounts=my-accounts
;;   // Generated: List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 10];
;;   for (Account acc : accounts) {
;;       System.debug(acc.Name);  // Direct field access, no casting!
;;   }
;;   #+END_SRC

;;; Code:

(require 'ob)

;;; Query String Cache

(defvar ob-soql-vars--query-cache (make-hash-table :test 'equal)
  "Cache mapping block names to SOQL query strings.")

;;; Storage Functions

(defun ob-soql-vars-store-query (name query-string)
  "Store QUERY-STRING under NAME for use by Apex blocks.
NAME is the #+NAME of the SOQL block.
QUERY-STRING is the SOQL query text."
  (when (and name query-string)
    (let ((normalized (ob-soql-vars--normalize-query query-string)))
      (puthash name normalized ob-soql-vars--query-cache)
      normalized)))

(defun ob-soql-vars-get-query (name)
  "Retrieve stored SOQL query string by NAME.
Returns query string or nil if not found."
  (gethash name ob-soql-vars--query-cache))

(defun ob-soql-vars-clear-cache ()
  "Clear all stored SOQL query strings."
  (interactive)
  (clrhash ob-soql-vars--query-cache)
  (message "SOQL query cache cleared"))

;;; Query Normalization

(defun ob-soql-vars--normalize-query (query)
  "Normalize QUERY for use in Apex.
- Trim whitespace
- Join multi-line queries
- Remove extra spaces"
  (let* ((trimmed (string-trim query))
         (single-line (string-join (split-string trimmed "\n" t "[ \t]+") " ")))
    ;; Collapse multiple spaces to single space
    (replace-regexp-in-string "[ \t]+" " " single-line)))

(defun ob-soql-vars--escape-for-apex (query)
  "Escape QUERY string for use in Apex SOQL literal.
Note: For inline SOQL [SELECT...], we don't need to escape quotes."
  ;; Inline SOQL doesn't need escaping
  query)

;;; SObject Type Extraction

(defun ob-soql-vars--extract-sobject (query)
  "Extract SObject type from SOQL QUERY.
Returns SObject name like 'Account', 'Contact', 'CustomObject__c'.
Handles standard and custom objects."
  (when (string-match "\\bFROM\\s-+\\([A-Za-z0-9_]+\\)" query)
    (match-string 1 query)))

;;; Apex Code Generation

(defun ob-soql-vars-to-apex-query (var-name query-string)
  "Generate Apex code to execute QUERY-STRING and store in VAR-NAME.
Extracts SObject type for type-safe List<SObjectType> declaration.
Uses inline SOQL syntax [SELECT...] for clean, type-safe code."
  (let ((sobject (ob-soql-vars--extract-sobject query-string)))
    (if sobject
        ;; Type-safe: List<Account> accounts = [SELECT Id, Name FROM Account];
        (format "List<%s> %s = [%s];"
                sobject
                var-name
                query-string)
      ;; Fallback to generic if can't extract type
      (format "List<SObject> %s = Database.query('%s');"
              var-name
              (ob-soql-vars--escape-for-dynamic-query query-string)))))

(defun ob-soql-vars--escape-for-dynamic-query (query)
  "Escape QUERY for use in Database.query() string literal.
Only used as fallback when SObject type can't be extracted."
  (replace-regexp-in-string "'" "\\\\'" query))

;;; Integration

;;;###autoload
(defun ob-soql-vars-enable ()
  "Enable SOQL query string passing to Apex.
Captures query strings from SOQL blocks for Apex use."
  (interactive)
  ;; Hook into org-babel to capture SOQL blocks
  (advice-add 'org-babel-execute:soql :before #'ob-soql-vars--capture-query)
  (message "SOQL query passing enabled"))

;;;###autoload
(defun ob-soql-vars-disable ()
  "Disable SOQL query string passing."
  (interactive)
  (advice-remove 'org-babel-execute:soql #'ob-soql-vars--capture-query)
  (message "SOQL query passing disabled"))

(defun ob-soql-vars--capture-query (body params)
  "Capture SOQL BODY before execution.
PARAMS contains org-babel parameters.
Stores query if block has #+NAME."
  ;; Get block info to find name
  (when-let* ((info (org-babel-get-src-block-info))
              (name (nth 4 info)))  ; Block name from #+NAME:
    (ob-soql-vars-store-query name body)))

;; Auto-enable when loaded
(ob-soql-vars-enable)

(provide 'ob-soql-vars)
;;; ob-soql-vars.el ends here
