;;; ob-soql-display.el --- Display formatters for SOQL results -*- lexical-binding: t -*-

;; Copyright (C) 2025

;; Author: tan.nguyen@furucrm.com
;; Keywords: salesforce, soql, org-babel
;; Version: 1.0

;;; Commentary:
;; This module provides multiple display format options for SOQL query results:
;; - org-table: Traditional org-mode table format
;; - vtable: Modern Emacs 29+ interactive table widget
;; - tabulated-list: Standard Emacs tabular display
;; - csv: Direct CSV mode display

;;; Code:

(require 'ob)
(require 'csv-mode nil t)

;;; Customization

(defgroup ob-soql nil
  "SOQL query support for org-babel."
  :group 'org-babel)

(defcustom ob-soql-output-format 'auto
  "Output format for SOQL query results.
When 'auto, chooses based on context:
- In org-babel blocks: org-table (for static results)
- In standalone query: vtable (for interactive results)"
  :type '(choice (const :tag "Auto-detect" auto)
                 (const :tag "Org Table" org-table)
                 (const :tag "VTable" vtable)
                 (const :tag "Tabulated List" tabulated-list)
                 (const :tag "CSV Mode" csv))
  :group 'ob-soql)

(defcustom ob-soql-display-max-column-width 50
  "Maximum width for table columns."
  :type 'integer
  :group 'ob-soql)

(defcustom ob-soql-display-truncate-strings t
  "Whether to truncate long string values in display."
  :type 'boolean
  :group 'ob-soql)

;;; Variables

(defvar-local ob-soql--query-metadata nil
  "Metadata for current SOQL results.
Plist with keys:
  :query - Original SOQL query
  :org - Target org name
  :org-url - Instance URL
  :sobject - Primary SObject type
  :fields - List of field names
  :records - List of record data (alist per record)
  :csv-data - Original CSV string")

;;; Utility Functions

(defun ob-soql--detect-output-format ()
  "Detect appropriate output format based on context."
  (if (eq ob-soql-output-format 'auto)
      (if (and (boundp 'org-babel-current-src-block-location)
               org-babel-current-src-block-location)
          'org-table
        (if (>= emacs-major-version 29) 'vtable 'tabulated-list))
    ob-soql-output-format))

(defun ob-soql--parse-csv (csv-string)
  "Parse CSV-STRING into list of records.
Returns list of alists where keys are field names."
  (when (and csv-string (not (string-empty-p csv-string)))
    (let* ((lines (split-string csv-string "\n" t))
           (headers (split-string (car lines) ","))
           (data-lines (cdr lines)))
      (mapcar (lambda (line)
                (let ((values (split-string line ",")))
                  (cl-mapcar #'cons headers values)))
              data-lines))))

(defun ob-soql--extract-fields (csv-string)
  "Extract field names from CSV-STRING header."
  (when (and csv-string (not (string-empty-p csv-string)))
    (let ((first-line (car (split-string csv-string "\n" t))))
      (split-string first-line ","))))

(defun ob-soql--extract-sobject (query)
  "Extract primary SObject from SOQL QUERY.
Returns SObject API name or nil if ambiguous."
  (when (string-match "FROM[[:space:]]+\\([[:alnum:]_]+\\)" query)
    (match-string 1 query)))

(defun ob-soql--build-metadata (query org org-url csv-data &optional sobject)
  "Build metadata plist for SOQL results.
QUERY: The SOQL query string
ORG: Target org name
ORG-URL: Salesforce instance URL
CSV-DATA: Raw CSV data string
SOBJECT: Optional SObject type override"
  (let* ((fields (ob-soql--extract-fields csv-data))
         (records (ob-soql--parse-csv csv-data))
         (detected-sobject (or sobject (ob-soql--extract-sobject query))))
    (list :query query
          :org org
          :org-url org-url
          :sobject detected-sobject
          :fields fields
          :records records
          :csv-data csv-data)))

(defun ob-soql--truncate-string (str max-width)
  "Truncate STR to MAX-WIDTH, adding ellipsis if needed."
  (if (and ob-soql-display-truncate-strings
           (> (length str) max-width))
      (concat (substring str 0 (- max-width 3)) "...")
    str))

;;; Display Dispatching

(defun ob-soql-display-results (csv-data metadata &optional format)
  "Display SOQL results in specified FORMAT.
CSV-DATA: Raw CSV string
METADATA: Query metadata plist
FORMAT: Output format symbol (defaults to auto-detect)"
  (let ((display-format (or format (ob-soql--detect-output-format))))
    (pcase display-format
      ('org-table (ob-soql--display-as-org-table csv-data metadata))
      ('vtable (ob-soql--display-as-vtable metadata))
      ('tabulated-list (ob-soql--display-as-tabulated-list metadata))
      ('csv (ob-soql--display-as-csv csv-data metadata))
      (_ (error "Unknown display format: %s" display-format)))))

;;; Org-Table Display (Original)

(defun ob-soql--display-as-org-table (csv-data metadata)
  "Display results as org-table.
CSV-DATA: CSV string with hyperlinks
METADATA: Query metadata plist
Returns the org-table string for org-babel insertion."
  (let ((buf (generate-new-buffer " *ob-soql-temp*")))
    (unwind-protect
        (with-current-buffer buf
          (insert csv-data)
          (org-table-convert-region (point-min) (point-max))
          (buffer-string))
      (when (buffer-live-p buf)
        (kill-buffer buf)))))

;;; VTable Display (Emacs 29+)

(defun ob-soql--display-as-vtable (metadata)
  "Display results using vtable widget.
METADATA: Query metadata plist
Returns buffer displaying the vtable."
  (if (< emacs-major-version 29)
      (progn
        (message "vtable requires Emacs 29+, falling back to tabulated-list")
        (ob-soql--display-as-tabulated-list metadata))
    (require 'vtable)
    (let* ((records (plist-get metadata :records))
           (fields (plist-get metadata :fields))
           (sobject (plist-get metadata :sobject))
           (buffer (generate-new-buffer (format "*SOQL Results: %s*" 
                                                (or sobject "Query")))))
      (with-current-buffer buffer
        (ob-soql-results-mode)
        (setq ob-soql--query-metadata metadata)
        
        ;; Create vtable
        (let ((table (make-vtable
                      :columns (mapcar (lambda (field)
                                         (list :name field
                                               :width (min ob-soql-display-max-column-width
                                                           (max 10 (length field)))))
                                       fields)
                      :objects records
                      :getter (lambda (record column _vtable)
                                (let ((value (alist-get column record nil nil #'string=)))
                                  (ob-soql--truncate-string 
                                   (or value "")
                                   ob-soql-display-max-column-width)))
                      :use-header-line nil)))
          (setq-local vtable-object table))
        
        (goto-char (point-min))
        (setq buffer-read-only t))
      
      (pop-to-buffer buffer)
      buffer)))

;;; Tabulated-List Display

(defun ob-soql--display-as-tabulated-list (metadata)
  "Display results using tabulated-list-mode.
METADATA: Query metadata plist
Returns buffer displaying the table."
  (let* ((records (plist-get metadata :records))
         (fields (plist-get metadata :fields))
         (sobject (plist-get metadata :sobject))
         (buffer (generate-new-buffer (format "*SOQL Results: %s*" 
                                              (or sobject "Query")))))
    (with-current-buffer buffer
      (ob-soql-results-mode)
      (setq ob-soql--query-metadata metadata)
      
      ;; Set up tabulated-list
      (setq tabulated-list-format
            (apply #'vector
                   (mapcar (lambda (field)
                             (list field
                                   (min ob-soql-display-max-column-width
                                        (max 10 (length field)))
                                   t))
                           fields)))
      
      (setq tabulated-list-entries
            (let ((id 0))
              (mapcar (lambda (record)
                        (setq id (1+ id))
                        (list id
                              (apply #'vector
                                     (mapcar (lambda (field)
                                               (ob-soql--truncate-string
                                                (or (alist-get field record nil nil #'string=) "")
                                                ob-soql-display-max-column-width))
                                             fields))))
                      records)))
      
      (tabulated-list-init-header)
      (tabulated-list-print)
      (goto-char (point-min)))
    
    (pop-to-buffer buffer)
    buffer))

;;; CSV Display

(defun ob-soql--display-as-csv (csv-data metadata)
  "Display results in csv-mode.
CSV-DATA: Raw CSV string
METADATA: Query metadata plist
Returns buffer displaying the CSV."
  (let* ((sobject (plist-get metadata :sobject))
         (buffer (generate-new-buffer (format "*SOQL Results: %s*" 
                                              (or sobject "Query")))))
    (with-current-buffer buffer
      (insert csv-data)
      (csv-mode)
      (setq ob-soql--query-metadata metadata)
      (goto-char (point-min)))
    
    (pop-to-buffer buffer)
    buffer))

;;; Results Mode

(defvar ob-soql-results-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "g") #'ob-soql-refresh-results)
    map)
  "Keymap for `ob-soql-results-mode'.")

(define-derived-mode ob-soql-results-mode special-mode "SOQL Results"
  "Major mode for displaying SOQL query results.

\\{ob-soql-results-mode-map}"
  (setq truncate-lines t))

(defun ob-soql-refresh-results ()
  "Refresh SOQL results by re-running the query."
  (interactive)
  (if (not ob-soql--query-metadata)
      (message "No query metadata available")
    (message "Refresh not yet implemented")))

(provide 'ob-soql-display)

;;; ob-soql-display.el ends here
