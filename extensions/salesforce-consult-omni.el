;;; salesforce-consult-omni.el --- Integrate with consult-omni package -*- lexical-binding: t -*-

;; Copyright (C) 2025 Tan Nguyen

;; Author: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (consult-omni "0.1"))
;; Keywords: salesforce, consult, search
;; URL: https://github.com/your/repo

;;; Commentary:
;; This package provides integration between Salesforce and consult-omni,
;; enabling unified search across Salesforce records and metadata through
;; the consult interface.
;;
;; Features:
;; - Search Salesforce records using SOSL
;; - Query Salesforce metadata using SOQL
;; - Unified search interface through consult-omni
;; - Preview and open records in browser

;;; Code:

(require 'salesforce-data)
(require 'salesforce-core)
(require 'salesforce-project)
(require 'url-util)

;;; Customization

(defgroup salesforce-consult-omni nil
  "Customization options for Salesforce Consult Omni."
  :group 'salesforce
  :prefix "salesforce-consult-omni-")

(defcustom salesforce-consult-omni-default-fields '("Name")
  "Default Salesforce fields used when searching for records."
  :type '(repeat string)
  :group 'salesforce-consult-omni)

(defcustom salesforce-consult-omni-default-returning '("Contact (Id, Name)")
  "Default Salesforce sObjects and fields to return when searching.
Each entry is expected to follow the format: 
  \"SObject (Field1, Field2, ...)\"."
  :type '(repeat string)
  :group 'salesforce-consult-omni)

;;; URL Building

(defun salesforce-consult-omni--build-url (&rest parts)
  "Build a URL from PARTS by joining them together."
  (string-join parts ""))

(defun salesforce-consult-omni--build-search-endpoint (query)
  "Build the search endpoint URL for QUERY."
  (salesforce-consult-omni--build-url 
   salesforce-project-url
   "/services/data/v" salesforce-api-version "/search"
   "?q=" (url-hexify-string query)))

(defun salesforce-consult-omni--build-query-endpoint (query)
  "Build the query endpoint URL for QUERY."
  (salesforce-consult-omni--build-url 
   salesforce-project-url
   "/services/data/v" salesforce-api-version "/query"
   "?q=" (replace-regexp-in-string " " "+" query)))

(defun salesforce-consult-omni--build-record-url (id)
  "Build the record URL for record ID."
  (concat salesforce-project-url "/" id))

;;; SOSL/SOQL Building

(cl-defun salesforce-consult-omni--build-sosl (input &key fields objects)
  "Build SOSL query string from INPUT.
FIELDS specifies which fields to search in.
OBJECTS specifies which objects to return."
  (format "FIND {%s} IN %s Fields RETURNING %s"
          input
          (string-join (or fields salesforce-consult-omni-default-fields) ",")
          (if objects
              (string-join 
               (mapcar (lambda (object)
                         (concat object "(Id,Name)"))
                       objects)
               ",")
            (string-join salesforce-consult-omni-default-returning ","))))

(defun salesforce-consult-omni--extract-soql-clause (soql-string)
  "Extract fields, table, where, and limit clauses from SOQL-STRING.
Supports SELECT … FROM … [WHERE …] [LIMIT …].
Returns a list: (fields object where limit)."
  (let ((case-fold-search t)
        fields object where limit)

    ;; SELECT … FROM …
    (when (string-match
           "SELECT[ \t\n]+\\(.+?\\)[ \t\n]+FROM[ \t\n]+\\([a-zA-Z0-9_]+\\)"
           soql-string)
      (setq fields (match-string 1 soql-string)
            object (match-string 2 soql-string)))

    ;; WHERE (non-greedy, stops before LIMIT if present)
    (when (string-match
           "WHERE[ \t\n]+\\(.*?\\)\\(?:[ \t\n]+LIMIT\\|$\\)"
           soql-string)
      (setq where (match-string 1 soql-string)))

    ;; LIMIT N
    (when (string-match "LIMIT[ \t\n]+\\([0-9]+\\)" soql-string)
      (setq limit (match-string 1 soql-string)))

    (list fields object where limit)))

;;; Request Handling

(defun salesforce-consult-omni--build-headers ()
  "Build HTTP headers for Salesforce API requests."
  `(("Authorization" . ,(concat "Bearer " salesforce-project-token))))

;;; Result Processing

(cl-defun salesforce-consult-omni--process-results
    (&key source label data)
  "Process search results and return annotated candidates.
SOURCE is the source name for the results.
LABEL is the field to use as the title.
DATA is the array of result items."
  (mapcar 
   (lambda (item)
     (let* ((id (gethash "Id" item))
            (title (gethash (or label "Name") item))
            (url (salesforce-consult-omni--build-record-url id))
            (decorated (funcall consult-omni-default-format-candidate
                                :source source
                                :url url
                                :title title)))
       (propertize decorated
                   :source source
                   :title title
                   :url url)))
   data))

;;; Search Implementation

(cl-defun salesforce-consult-omni--search-records 
    (input &rest args &key callback &allow-other-keys)
  "Search Salesforce records using SOSL with INPUT.
ARGS contains additional options parsed from the input.
CALLBACK is called with the results when complete."
  (pcase-let* ((`(,query . ,opts) 
                (consult-omni--split-command 
                 input 
                 (seq-difference args (list :callback callback))))
               (opts (car-safe opts))
               (fields (plist-get opts :fields))
               (objects (plist-get opts :objects))
               (label (plist-get opts :label))
               (sosl-string (salesforce-consult-omni--build-sosl 
                             query 
                             :fields fields 
                             :objects objects))
               (endpoint (salesforce-consult-omni--build-search-endpoint 
                          sosl-string)))

    (consult-omni--fetch-url 
     endpoint 
     consult-omni-http-retrieve-backend
     :encoding 'utf-8
     :headers (salesforce-consult-omni--build-headers)
     :parser #'consult-omni--json-parse-buffer
     :callback
     (lambda (attrs)
       (when-let* ((raw-results (map-nested-elt attrs '("searchRecords")))
                   (annotated-results 
                    (salesforce-consult-omni--process-results
                     :source "Search"
                     :label label
                     :data raw-results)))
         (funcall callback annotated-results)
         annotated-results)))))

(cl-defun salesforce-consult-omni--query-metadata 
    (input &rest args &key callback &allow-other-keys)
  "Query Salesforce metadata using SOQL with INPUT.
ARGS contains additional options parsed from the input.
CALLBACK is called with the results when complete."
  (pcase-let* ((`(,query . ,opts) 
                (consult-omni--split-command 
                 input 
                 (seq-difference args (list :callback callback))))
               (opts (car-safe opts))
               (label (plist-get opts :label))
               (endpoint (salesforce-consult-omni--build-query-endpoint query)))

    (consult-omni--fetch-url 
     endpoint 
     consult-omni-http-retrieve-backend
     :encoding 'utf-8
     :headers (salesforce-consult-omni--build-headers)
     :parser #'consult-omni--json-parse-buffer
     :callback
     (lambda (attrs)
       (when-let* ((raw-results (map-nested-elt attrs '("records")))
                   (annotated-results 
                    (salesforce-consult-omni--process-results
                     :source "Query"
                     :label label
                     :data raw-results)))
         (funcall callback annotated-results)
         annotated-results)))))

;;; Callbacks

(defun salesforce-consult-omni--doc-callback (cand)
  "Open the URL associated with candidate CAND in a browser."
  (browse-url (get-text-property 0 :url cand)))

;;; Consult-Omni Source Definitions

(consult-omni-define-source "Search"
                            :narrow-char ?r
                            :type 'dynamic
                            :require-match t
                            :category 'consult-omni-salesforce
                            :face 'consult-omni-engine-title-face
                            :request #'salesforce-consult-omni--search-records
                            :on-preview #'ignore
                            :on-callback #'salesforce-consult-omni--doc-callback
                            :search-hist 'consult-omni--search-history
                            :select-hist 'consult-omni--selection-history
                            :group #'consult-omni--group-function
                            :sort t
                            :static 'both)

(consult-omni-define-source "Metadata"
                            :narrow-char ?q
                            :type 'dynamic
                            :require-match t
                            :category 'consult-omni-salesforce
                            :face 'consult-omni-engine-title-face
                            :request #'salesforce-consult-omni--query-metadata
                            :on-preview #'ignore
                            :on-callback #'salesforce-consult-omni--doc-callback
                            :search-hist 'consult-omni--search-history
                            :select-hist 'consult-omni--selection-history
                            :group #'consult-omni--group-function
                            :sort t
                            :static 'both)

;;; Interactive Commands

(defun salesforce-consult-omni-search-metadata ()
  "Query Salesforce metadata using SOQL through consult-omni."
  (interactive)
  (consult-omni-multi 
   nil
   (concat "[" (propertize salesforce-org-name
                           'face 'consult-omni-prompt-face)
           "] Query Records: ")
   '("Metadata")))

(defun salesforce-consult-omni-dispatch-search ()
  "Search Salesforce records using SOSL through consult-omni."
  (interactive)
  (consult-omni-multi 
   nil
   (concat "[" (propertize salesforce-org-name
                           'face 'consult-omni-prompt-face)
           "] Search Records: ")
   '("Search")))

(provide 'salesforce-consult-omni)

;;; salesforce-consult-omni.el ends here
