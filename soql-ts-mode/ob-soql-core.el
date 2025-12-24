;;; ob-soql-core.el --- Core functionality for SOQL org-babel -*- lexical-binding: t -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author     : Tan Nguyen <tan.nguyen@furucrm.com>
;; Maintainer : Tan Nguyen
;; Created    : December 2024
;; Keywords   : soql salesforce org-babel
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
;; This module provides core functionality for SOQL org-babel integration.
;; It consolidates functionality previously spread across multiple files:
;; - ob-soql-vars.el    (SOQL-to-Apex variable passing)
;; - ob-soql-display.el (Result display formatters)
;; - ob-soql-update.el  (Salesforce update integration)
;;
;; SECTION 1: SOQL-to-Apex Variable Passing
;;   Store SOQL queries for use in Apex blocks with type-safe code generation.
;;   Extract SObject type from queries to generate List<Account> instead of
;;   generic List<SObject>.
;;
;; SECTION 2: Result Display Formatters
;;   Multiple output formats for query results:
;;   - org-table: Traditional org-mode tables
;;   - vtable: Modern Emacs 29+ table widget
;;   - tabulated-list: Standard Emacs tabular display
;;   - csv: Direct CSV mode display
;;
;; SECTION 3: Salesforce Update Integration
;;   Push edits back to Salesforce:
;;   - Single record updates
;;   - Bulk API for multiple records
;;   - Field metadata caching
;;   - Error handling and recovery
;;
;; Note: Interactive editing functionality (field editing, change tracking,
;;       preview, revert) has been moved to ob-soql-vtable.el where it is
;;       implemented using vtable's native action system.

;;; Code:

(require 'ob)
(require 'csv-mode nil t)
(require 'salesforce-core)

;;; Feature Detection

(defconst ob-soql-core--has-vtable (>= emacs-major-version 29)
  "Whether vtable is available (Emacs 29+).")

;;; ========================================
;;; Customization Group
;;; ========================================

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

(defcustom ob-soql-enable-edit t
  "Enable editing of SOQL query results."
  :type 'boolean
  :group 'ob-soql)

(defcustom ob-soql-confirm-before-commit t
  "Ask for confirmation before committing changes to Salesforce."
  :type 'boolean
  :group 'ob-soql)

(defcustom ob-soql-bulk-update-threshold 5
  "Number of pending updates to trigger bulk API.
Set to nil to always use single record updates.
Set to 1 to always use bulk API."
  :type '(choice (const :tag "Never use bulk" nil)
                 (integer :tag "Threshold count"))
  :group 'ob-soql)

(defcustom ob-soql-metadata-cache-ttl (* 60 60)
  "Time-to-live for cached SObject metadata in seconds.
Default: 1 hour (3600 seconds)."
  :type 'integer
  :group 'ob-soql)

;;; ========================================
;;; Section 1: SOQL-to-Apex Variable Passing
;;; ========================================

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

(defun ob-soql-vars--capture-query (body params)
  "Capture SOQL BODY before execution.
PARAMS contains org-babel parameters.
Stores query if block has #+NAME."
  ;; Get block info to find name
  (when-let* ((info (org-babel-get-src-block-info))
              (name (nth 4 info)))  ; Block name from #+NAME:
    (ob-soql-vars-store-query name body)))

;;; ========================================
;;; Section 2: Result Display Formatters
;;; ========================================

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

(defun ob-soql-core--detect-output-format ()
  "Detect appropriate output format based on context."
  (if (eq ob-soql-output-format 'auto)
      (if (and (boundp 'org-babel-current-src-block-location)
               org-babel-current-src-block-location)
          'org-table
        (if ob-soql-core--has-vtable 'vtable 'tabulated-list))
    ob-soql-output-format))

(defun ob-soql-core--parse-csv (csv-string)
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

(defun ob-soql-core--extract-fields (csv-string)
  "Extract field names from CSV-STRING header."
  (when (and csv-string (not (string-empty-p csv-string)))
    (let ((first-line (car (split-string csv-string "\n" t))))
      (split-string first-line ","))))

(defun ob-soql-core--extract-sobject (query)
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
  (let* ((fields (ob-soql-core--extract-fields csv-data))
         (records (ob-soql-core--parse-csv csv-data))
         (detected-sobject (or sobject (ob-soql-core--extract-sobject query))))
    (list :query query
          :org org
          :org-url org-url
          :sobject detected-sobject
          :fields fields
          :records records
          :csv-data csv-data)))

(defun ob-soql-core--truncate-string (str max-width)
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
  (let ((display-format (or format (ob-soql-core--detect-output-format))))
    (pcase display-format
      ('org-table (ob-soql--display-as-org-table csv-data metadata))
      ('vtable (ob-soql--display-as-vtable metadata))
      ('tabulated-list (ob-soql--display-as-tabulated-list metadata))
      ('csv (ob-soql--display-as-csv csv-data metadata))
      (_ (error "Unknown display format: %s" display-format)))))

;;; Org-Table Display

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
  (if (not ob-soql-core--has-vtable)
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
                                  (ob-soql-core--truncate-string 
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
      
      ;; Initialize metadata with state fields
      (setq-local ob-soql--query-metadata
                  (plist-put (plist-put (plist-put metadata
                                                   :pending-updates nil)
                                        :original-records (copy-tree records))
                             :field-metadata nil))
      
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
                                               (ob-soql-core--truncate-string
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
         (records (plist-get metadata :records))
         (buffer (generate-new-buffer (format "*SOQL Results: %s*" 
                                              (or sobject "Query")))))
    (with-current-buffer buffer
      (insert csv-data)
      (csv-mode)
      
      ;; Initialize metadata with state fields and CSV data
      (setq-local ob-soql--query-metadata
                  (plist-put (plist-put (plist-put (plist-put metadata
                                                              :pending-updates nil)
                                                   :original-records (copy-tree records))
                                        :field-metadata nil)
                             :csv-data csv-data))
      
      ;; Activate SOQL minor mode
      (ob-soql-csv-minor-mode 1)
      
      (goto-char (point-min)))
    
    (pop-to-buffer buffer)
    buffer))

;;; CSV Minor Mode

(defvar ob-soql-csv-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Same keys as results-mode
    (define-key map (kbd "RET") #'ob-soql-open-record)
    (define-key map (kbd "e")   #'ob-soql-edit-field)
    (define-key map (kbd "c")   #'ob-soql-commit-changes)
    (define-key map (kbd "r")   #'ob-soql-revert-changes)
    (define-key map (kbd "p")   #'ob-soql-preview-changes)
    (define-key map (kbd "g")   #'ob-soql-refresh-results)
    (define-key map (kbd "M")   #'ob-soql-load-metadata)
    (define-key map (kbd "?")   #'ob-soql-show-help)
    (define-key map (kbd "q")   #'quit-window)
    map)
  "Keymap for `ob-soql-csv-minor-mode'.")

(define-minor-mode ob-soql-csv-minor-mode
  "Minor mode for SOQL results displayed in CSV format.
Provides keybindings for editing and committing changes."
  :keymap ob-soql-csv-mode-map
  :lighter " SOQL")

;;; Results Mode

(defvar ob-soql-results-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Always available
    (define-key map (kbd "RET") #'ob-soql-open-record)
    (define-key map (kbd "g")   #'ob-soql-refresh-results)
    (define-key map (kbd "?")   #'ob-soql-show-help)
    (define-key map (kbd "q")   #'quit-window)
    ;; Edit actions (check :editable at runtime)
    (define-key map (kbd "e")   #'ob-soql-edit-field)
    (define-key map (kbd "c")   #'ob-soql-commit-changes)
    (define-key map (kbd "r")   #'ob-soql-revert-changes)
    (define-key map (kbd "p")   #'ob-soql-preview-changes)
    (define-key map (kbd "M")   #'ob-soql-load-metadata)
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

;;; ========================================
;;; Section 3: Salesforce Update Integration
;;; ========================================
;; Note: Interactive editing functionality has been moved to vtable actions.
;; This section now only contains the core Salesforce update functions
;; that are called by vtable action handlers.

;;; Variables

(defvar ob-soql--metadata-cache (make-hash-table :test 'equal)
  "Cache for SObject metadata.
Keys: \"org:sobject\"
Values: (metadata . timestamp).")

;;; Single Record Update

(defun ob-soql-core--update-record (record-id field-updates sobject org)
  "Update a single record in Salesforce.
RECORD-ID: Salesforce record ID
FIELD-UPDATES: Alist of (field . value)
SOBJECT: SObject type
ORG: Target org name"
  (let* ((values-str (mapconcat (lambda (update)
                                  (pcase-let ((`(,field . ,value) update))
                                    (format "%s='%s'" field 
                                            (ob-soql-core--escape-value value))))
                                field-updates
                                " "))
         (args `("update" "record"
                 "-s" ,sobject
                 "-i" ,record-id
                 "-v" ,values-str
                 "-o" ,org
                 "--json")))
    
    (let ((result (ob-soql-core--execute-sf-command args)))
      (if (eq (plist-get result :status) 0)
          (progn
            (message "Updated record %s" record-id)
            t)
        (error "Failed to update record %s: %s" 
               record-id 
               (plist-get result :message))))))

(defun ob-soql-core--update-records-sequential (updates sobject org)
  "Update multiple records sequentially.
UPDATES: List of (record-id . field-updates)
SOBJECT: SObject type
ORG: Target org name
Returns number of successful updates."
  (let ((total (length updates))
        (success 0)
        (failed 0))
    
    (dolist (update updates)
      (pcase-let ((`(,record-id . ,field-updates) update))
        (condition-case err
            (progn
              (ob-soql-core--update-record record-id field-updates sobject org)
              (setq success (1+ success)))
          (error
           (setq failed (1+ failed))
           (message "Failed to update %s: %s" record-id (error-message-string err))))))
    
    ;; Report results
    (if (= failed 0)
        (message "Successfully updated %d record%s" 
                 success (if (= success 1) "" "s"))
      (message "Updated %d records, %d failed" success failed))
    
    success))

;;; Bulk Update

(defun ob-soql-core--update-records-bulk (updates sobject org)
  "Update multiple records using bulk API.
UPDATES: List of (record-id . field-updates)
SOBJECT: SObject type
ORG: Target org name
Returns plist with :successful and :failed counts."
  (let* ((fields (ob-soql-core--collect-updated-fields updates))
         (csv-file (make-temp-file "soql-bulk-update-" nil ".csv"))
         (csv-content (ob-soql-core--build-update-csv updates fields)))
    
    (unwind-protect
        (progn
          ;; Write CSV file
          (write-region csv-content nil csv-file)
          
          ;; Execute bulk update
          (let* ((args `("import" "bulk"
                         "-f" ,csv-file
                         "-s" ,sobject
                         "-o" ,org
                         "--wait" "10"
                         "--json"))
                 (result (ob-soql-core--execute-sf-command args)))
            
            (if (eq (plist-get result :status) 0)
                (let ((successful (plist-get result :successfulRecords))
                      (failed-count (plist-get result :failedRecords)))
                  (message "Bulk update complete: %d successful, %d failed" 
                           successful failed-count)
                  (list :successful successful :failed failed-count))
              (error "Bulk update failed: %s" (plist-get result :message)))))
      
      ;; Cleanup temp file
      (when (file-exists-p csv-file)
        (delete-file csv-file)))))

(defun ob-soql-core--collect-updated-fields (updates)
  "Collect all unique field names from UPDATES."
  (let ((fields '("Id")))
    (dolist (update updates)
      (pcase-let ((`(,_record-id . ,field-updates) update))
        (dolist (field-update field-updates)
          (pcase-let ((`(,field . ,_value) field-update))
            (unless (member field fields)
              (push field fields))))))
    (nreverse fields)))

(defun ob-soql-core--build-update-csv (updates fields)
  "Build CSV content for bulk update.
UPDATES: List of (record-id . field-updates)
FIELDS: List of field names"
  (let ((lines (list (string-join fields ","))))
    (dolist (update updates)
      (pcase-let* ((`(,record-id . ,field-updates) update)
                   (values (mapcar (lambda (field)
                                     (if (string= field "Id")
                                         record-id
                                       (or (alist-get field field-updates nil nil #'string=)
                                           "")))
                                   fields)))
        (push (string-join values ",") lines)))
    (string-join (nreverse lines) "\n")))

;;; Salesforce CLI Execution

(defun ob-soql-core--execute-sf-command (args)
  "Execute Salesforce CLI command with ARGS.
Returns plist with :status, :message, and other result data."
  (let* ((full-args (cons "data" args))
         (process (salesforce-core--data-process
                   :args full-args
                   :sync t))
         (buf (process-buffer process)))
    
    (unwind-protect
        (with-current-buffer buf
          (let* ((output (buffer-string))
                 (json-data (condition-case nil
                                (json-parse-string output :object-type 'plist)
                              (error nil))))
            
            (if json-data
                (list :status (plist-get json-data :status)
                      :message (or (plist-get json-data :message) "")
                      :result (plist-get json-data :result)
                      :successfulRecords (plist-get (plist-get json-data :result) 
                                                    :numberRecordsProcessed)
                      :failedRecords (plist-get (plist-get json-data :result) 
                                                :numberRecordsFailed))
              ;; Fallback for non-JSON output
              (list :status 1
                    :message output
                    :result nil))))
      
      (when (buffer-live-p buf)
        (kill-buffer buf)))))

;;; Field Metadata

(defun ob-soql-core--get-sobject-metadata (sobject org &optional force-refresh)
  "Get metadata for SOBJECT in ORG.
Uses cache unless FORCE-REFRESH is non-nil."
  (let* ((cache-key (format "%s:%s" org sobject))
         (cached (gethash cache-key ob-soql--metadata-cache))
         (now (float-time)))
    (if (and cached 
             (not force-refresh)
             (< (- now (cdr cached)) ob-soql-metadata-cache-ttl))
        (car cached)
      ;; Fetch and cache
      (let ((metadata (ob-soql-core--fetch-sobject-describe sobject org)))
        (puthash cache-key (cons metadata now) ob-soql--metadata-cache)
        metadata))))

(defun ob-soql-core--fetch-sobject-describe (sobject org)
  "Fetch SObject describe metadata for SOBJECT from ORG.
Returns alist of (field-name . properties)."
  (condition-case err
      (let* ((args `("schema" "sobject" "describe"
                     "-s" ,sobject
                     "-o" ,org
                     "--json"))
             (process (salesforce-core--data-process
                       :args args
                       :sync t))
             (buf (process-buffer process)))
        
        (unwind-protect
            (with-current-buffer buf
              (let* ((json-data (json-parse-string (buffer-string) :object-type 'plist))
                     (fields (plist-get (plist-get json-data :result) :fields)))
                
                (mapcar (lambda (field)
                          (cons (plist-get field :name)
                                (list :updateable (plist-get field :updateable)
                                      :type (plist-get field :type)
                                      :label (plist-get field :label))))
                        fields)))
          
          (when (buffer-live-p buf)
            (kill-buffer buf))))
    
    (error
     (message "Failed to fetch SObject metadata: %s" (error-message-string err))
     ;; Return basic metadata as fallback
     nil)))



;;; Helper Functions for VTable Actions

(defun ob-soql-core--show-changes-preview (pending-updates metadata)
  "Show preview of PENDING-UPDATES.
PENDING-UPDATES: List of (record-id . field-updates)
METADATA: Query metadata plist"
  (let ((count (length pending-updates))
        (preview-buf (get-buffer-create "*SOQL Changes Preview*")))
    (with-current-buffer preview-buf
      (erase-buffer)
      (insert (format "Pending Changes (%d record%s)\n" 
                      count (if (= count 1) "" "s")))
      (insert (make-string 60 ?=) "\n\n")
      
      ;; Determine update method
      (when (and ob-soql-bulk-update-threshold
                 (>= count ob-soql-bulk-update-threshold))
        (insert (format "Will use BULK API (threshold: %d)\n\n" 
                        ob-soql-bulk-update-threshold)))
      
      ;; List each change
      (dolist (update pending-updates)
        (pcase-let ((`(,record-id . ,changes) update))
          (insert (format "Record: %s\n" record-id))
          (dolist (change changes)
            (pcase-let ((`(,field . ,new-value) change))
              (insert (format "  %s: %s\n" field new-value))))
          (insert "\n")))
      
      (insert (make-string 60 ?=) "\n")
      (insert "Press 'c' in the SOQL Results buffer to commit these changes.\n")
      (goto-char (point-min))
      (special-mode))
    
    (pop-to-buffer preview-buf)))

;;; Error Handling

(defun ob-soql-core--handle-update-error (error-data record-updates)
  "Handle update error and provide recovery options.
ERROR-DATA: Error information
RECORD-UPDATES: List of failed updates"
  (let ((error-msg (if (listp error-data)
                       (error-message-string error-data)
                     (format "%s" error-data))))
    
    (with-current-buffer (get-buffer-create "*SOQL Update Error*")
      (erase-buffer)
      (insert "SOQL Update Failed\n")
      (insert (make-string 60 ?=) "\n\n")
      (insert (format "Error: %s\n\n" error-msg))
      (insert "Your changes have been preserved and can be retried.\n")
      (insert "Press 'c' again to retry, or 'r' to revert changes.\n")
      (goto-char (point-min))
      (special-mode))
    
    (pop-to-buffer "*SOQL Update Error*")))

;;; Utility Functions

(defun ob-soql-core--escape-value (value)
  "Escape VALUE for Salesforce CLI command.
Handles quotes and special characters."
  (replace-regexp-in-string "'" "\\\\'" (format "%s" value)))

;;; ========================================
;;; Shared Action Handlers
;;; ========================================

(defun ob-soql-open-record ()
  "Open current record in Salesforce browser.
Works in vtable, tabulated-list, and csv modes."
  (interactive)
  (unless ob-soql--query-metadata
    (user-error "No SOQL query metadata available"))
  
  (let* ((metadata ob-soql--query-metadata)
         (record (ob-soql-core--get-record-at-point metadata))
         (org-url (plist-get metadata :org-url))
         (id (assoc-default "Id" record (lambda (v1 v2)
                                          (string= (downcase v1) (downcase v2))))))
    (if id
        (browse-url (concat org-url "/" id))
      (message "Id field not found on record."))))

(defun ob-soql-edit-field ()
  "Edit field value at point.
Works in vtable, tabulated-list, and csv modes."
  (interactive)
  (unless ob-soql--query-metadata
    (user-error "No SOQL query metadata available"))
  
  (let ((metadata ob-soql--query-metadata))
    ;; Check if editable
    (unless (plist-get metadata :editable)
      (user-error "Results are read-only. Use :editable t header argument"))
    
    (let* ((record (ob-soql-core--get-record-at-point metadata))
           (field (ob-soql-core--get-field-at-point metadata))
           (record-id (assoc-default "Id" record (lambda (v1 v2)
                                                   (string= (downcase v1) (downcase v2)))))
           (current-value (alist-get field record nil nil #'string=))
           (field-info (ob-soql-core--get-field-info field metadata)))
      
      (unless record-id
        (user-error "Cannot edit: record has no Id field"))
      (unless field
        (user-error "No field at point"))
      
      ;; Check if field is read-only
      (when (and field-info (not (plist-get field-info :updateable)))
        (user-error "Field '%s' is read-only" field))
      
      ;; Prompt for new value
      (let ((new-value (read-string (format "New value for %s: " field) current-value)))
        (ob-soql-core--track-change record-id field new-value current-value metadata)
        (ob-soql-core--update-display-value record-id field new-value metadata)
        (message "Field updated (not committed). Press 'c' to commit or 'r' to revert.")))))

(defun ob-soql-commit-changes ()
  "Commit pending changes to Salesforce.
Works in all output modes."
  (interactive)
  (unless ob-soql--query-metadata
    (user-error "No SOQL query metadata available"))
  
  (let* ((metadata ob-soql--query-metadata)
         (pending-updates (plist-get metadata :pending-updates)))
    (unless pending-updates
      (user-error "No pending changes to commit"))
    
    (let* ((count (length pending-updates))
           (sobject (plist-get metadata :sobject))
           (org (plist-get metadata :org))
           (use-bulk (and ob-soql-bulk-update-threshold
                          (>= count ob-soql-bulk-update-threshold))))
      
      (unless sobject
        (user-error "Cannot commit: SObject type unknown"))
      
      (when (or (not ob-soql-confirm-before-commit)
                (yes-or-no-p (format "Commit %d change%s to Salesforce using %s? "
                                     count
                                     (if (= count 1) "" "s")
                                     (if use-bulk "bulk API" "single updates"))))
        
        (message "Committing changes...")
        (condition-case err
            (progn
              (if use-bulk
                  (ob-soql-core--update-records-bulk pending-updates sobject org)
                (ob-soql-core--update-records-sequential pending-updates sobject org))
              
              ;; Clear pending updates on success
              (plist-put metadata :pending-updates nil)
              ;; Update original records to current state
              (plist-put metadata :original-records
                         (copy-tree (plist-get metadata :records)))
              (message "Changes committed successfully"))
          (error
           (message "Update failed: %s" (error-message-string err))))))))

(defun ob-soql-revert-changes ()
  "Revert all pending changes.
Works in all output modes."
  (interactive)
  (unless ob-soql--query-metadata
    (user-error "No SOQL query metadata available"))
  
  (let ((metadata ob-soql--query-metadata))
    (when (or (not ob-soql-confirm-before-commit)
              (yes-or-no-p "Revert all changes? "))
      (plist-put metadata :pending-updates nil)
      (plist-put metadata :records
                 (copy-tree (plist-get metadata :original-records)))
      
      ;; Refresh display based on mode
      (cond
       ((and (boundp 'vtable-object) vtable-object)
        (require 'vtable)
        (vtable-revert-command))
       ((derived-mode-p 'tabulated-list-mode)
        (ob-soql-core--update-display-value nil nil nil metadata))
       ((derived-mode-p 'csv-mode)
        ;; Rebuild entire CSV buffer
        (let ((csv-data (plist-get metadata :csv-data)))
          (erase-buffer)
          (insert csv-data)
          (goto-char (point-min)))))
      
      (message "All changes reverted"))))

(defun ob-soql-preview-changes ()
  "Show pending changes preview.
Works in all output modes."
  (interactive)
  (unless ob-soql--query-metadata
    (user-error "No SOQL query metadata available"))
  
  (let ((pending-updates (plist-get ob-soql--query-metadata :pending-updates)))
    (if (null pending-updates)
        (message "No pending changes")
      (ob-soql-core--show-changes-preview pending-updates ob-soql--query-metadata))))

(defun ob-soql-load-metadata ()
  "Load field metadata from Salesforce.
Works in all output modes."
  (interactive)
  (unless ob-soql--query-metadata
    (user-error "No SOQL query metadata available"))
  
  (let* ((metadata ob-soql--query-metadata)
         (sobject (plist-get metadata :sobject))
         (org (plist-get metadata :org)))
    (if (and sobject org)
        (progn
          (message "Loading field metadata for %s..." sobject)
          (let ((field-metadata (ob-soql-core--get-sobject-metadata sobject org t)))
            (plist-put metadata :field-metadata field-metadata)
            (message "Field metadata loaded: %d fields" (length field-metadata))))
      (message "Cannot load metadata: sobject or org not specified"))))

(defun ob-soql-show-help ()
  "Show available actions for SOQL results.
Works in all output modes."
  (interactive)
  (unless ob-soql--query-metadata
    (user-error "No SOQL query metadata available"))
  
  (if (plist-get ob-soql--query-metadata :editable)
      (message "Actions: [RET]Open [e]dit [c]ommit [r]evert [p]review [g]refresh [M]etadata [?]help [q]uit")
    (message "Actions: [RET]Open [g]refresh [?]help [q]uit")))

(defun ob-soql-core--track-change (record-id field new-value old-value metadata)
  "Track a field change in metadata.
RECORD-ID: Salesforce record ID
FIELD: Field name
NEW-VALUE: New value
OLD-VALUE: Original value
METADATA: Query metadata plist"
  (let* ((pending-updates (plist-get metadata :pending-updates))
         (record-updates (assoc-default record-id pending-updates nil #'string=)))
    
    ;; If new value equals original, remove the change
    (if (string= new-value old-value)
        (setq record-updates (assoc-delete-all field record-updates))
      ;; Otherwise, add/update the change
      (setf (alist-get field record-updates nil nil #'string=) new-value))
    
    ;; Update pending updates in metadata
    (if record-updates
        (setf (alist-get record-id pending-updates nil nil #'string=) record-updates)
      ;; Remove record if no changes
      (setq pending-updates (assoc-delete-all record-id pending-updates)))
    
    (plist-put metadata :pending-updates pending-updates)))

(defun ob-soql-core--get-field-info (field metadata)
  "Get field metadata info.
FIELD: Field name
METADATA: Query metadata plist
Returns field info plist or nil"
  (let ((field-metadata (plist-get metadata :field-metadata)))
    (assoc-default field field-metadata nil #'string=)))

;;; ========================================
;;; Display Context Helpers
;;; ========================================

(defun ob-soql-core--get-record-at-point (metadata)
  "Get record at point based on current buffer's display mode.
METADATA: Query metadata plist containing :records.
Returns record alist or nil if no record at point."
  (let ((records (plist-get metadata :records)))
    (cond
     ;; VTable mode
     ((and (boundp 'vtable-object) vtable-object)
      (require 'vtable)
      (when-let ((obj (vtable-current-object)))
        obj))
     
     ;; Tabulated-list mode
     ((derived-mode-p 'tabulated-list-mode)
      (when-let ((id (tabulated-list-get-id)))
        (nth (1- id) records)))
     
     ;; CSV mode  
     ((derived-mode-p 'csv-mode)
      (save-excursion
        (beginning-of-line)
        (unless (= (line-number-at-pos) 1)  ; Skip header line
          (let* ((line (buffer-substring-no-properties (point) (line-end-position)))
                 (values (split-string line ","))
                 (fields (plist-get metadata :fields)))
            (when (= (length values) (length fields))
              (cl-mapcar #'cons fields values))))))
     
     (t nil))))

(defun ob-soql-core--get-field-at-point (metadata)
  "Get field name at point based on current buffer's display mode.
METADATA: Query metadata plist containing :fields.
Returns field name string or nil if no field at point."
  (let ((fields (plist-get metadata :fields)))
    (cond
     ;; VTable mode
     ((and (boundp 'vtable-object) vtable-object)
      (require 'vtable)
      (when-let ((col (vtable-current-column)))
        (plist-get (nth col (vtable-columns vtable-object)) :name)))
     
     ;; Tabulated-list mode
     ((derived-mode-p 'tabulated-list-mode)
      (let* ((pos (point))
             (bol (line-beginning-position))
             (current-col 0))
        ;; Calculate which column we're in based on point position
        (save-excursion
          (goto-char bol)
          (catch 'found
            (dotimes (i (length fields))
              (let* ((col-spec (aref tabulated-list-format i))
                     (col-width (cadr col-spec)))
                (when (< pos (+ (point) col-width))
                  (setq current-col i)
                  (throw 'found nil))
                (forward-char col-width)))))
        (nth current-col fields)))
     
     ;; CSV mode
     ((derived-mode-p 'csv-mode)
      (let ((field-index (ob-soql-core--csv-current-field-index)))
        (when (and field-index (< field-index (length fields)))
          (nth field-index fields))))
     
     (t nil))))

(defun ob-soql-core--csv-current-field-index ()
  "Get 0-based index of field at point in CSV mode.
Returns integer or nil if not in a field."
  (when (derived-mode-p 'csv-mode)
    (save-excursion
      (let ((bol (line-beginning-position))
            (pos (point))
            (index 0))
        (goto-char bol)
        (while (and (< (point) pos)
                    (not (eolp)))
          (when (= (char-after) ?,)
            (setq index (1+ index)))
          (forward-char))
        index))))

(defun ob-soql-core--update-display-value (record-id field new-value metadata)
  "Update display after editing a field value.
RECORD-ID: Salesforce record ID
FIELD: Field name
NEW-VALUE: New value to display
METADATA: Query metadata plist

Updates the visual display based on current buffer's mode."
  ;; First update metadata
  (let ((records (plist-get metadata :records)))
    (dolist (record records)
      (when (string= (assoc-default "Id" record nil #'string=) record-id)
        (setf (alist-get field record nil nil #'string=) new-value))))
  
  ;; Then refresh display
  (cond
   ;; VTable mode
   ((and (boundp 'vtable-object) vtable-object)
    (require 'vtable)
    (vtable-revert-command))
   
   ;; Tabulated-list mode
   ((derived-mode-p 'tabulated-list-mode)
    (let* ((records (plist-get metadata :records))
           (fields (plist-get metadata :fields)))
      (setq tabulated-list-entries
            (let ((id 0))
              (mapcar (lambda (record)
                        (setq id (1+ id))
                        (list id
                              (apply #'vector
                                     (mapcar (lambda (field)
                                               (ob-soql-core--truncate-string
                                                (or (alist-get field record nil nil #'string=) "")
                                                ob-soql-display-max-column-width))
                                             fields))))
                      records)))
      (tabulated-list-print t)))  ; Keep cursor position
   
   ;; CSV mode
   ((derived-mode-p 'csv-mode)
    (let* ((records (plist-get metadata :records))
           (fields (plist-get metadata :fields))
           (record (ob-soql-core--get-record-at-point metadata)))
      (when record
        ;; Rebuild current line
        (let ((line (mapconcat (lambda (field)
                                 (or (alist-get field record nil nil #'string=) ""))
                               fields
                               ",")))
          (save-excursion
            (beginning-of-line)
            (delete-region (point) (line-end-position))
            (insert line))))))
   
   (t nil)))

;;; Helper Macros and Functions

(defun ob-soql-core--org-url (org)
  "Return the Salesforce instance URL for ORG."
  (salesforce-project--get-user-data org "instanceUrl"))

(defun ob-soql-core--modify-csv (csv org-hyperlink)
  "Return CSV after converting 'Id' field values into ORG-HYPERLINK."
  (let* ((lines (string-split csv "\n" t))
         (headers (car lines))
         (rows (cdr lines))
         (header-fields (string-split headers ","))
         (id-pos (cl-position "id" header-fields
                              :test (lambda (a b)
                                      (string= (downcase a) (downcase b))))))
    (if id-pos
        (string-join
         (cons headers
               (mapcar (lambda (line)
                         (let ((cols (string-split line ",")))
                           (when (and (< id-pos (length cols)))
                             (setf (nth id-pos cols)
                                   (ob-soql-core--convert-id-to-hyperlink (nth id-pos cols) org-hyperlink)))
                           (string-join cols ",")))
                       rows))
         "\n")
      csv)))

(defun ob-soql-core--convert-id-to-hyperlink (id org-hyperlink)
  "Convert Salesforce ID into an ORG-HYPERLINK."
  (format "[[%s][%s]]" (concat org-hyperlink "/" id) id))

(cl-defmacro ob-soql-core-buffer-modifications (&rest body &key buffer append &allow-other-keys)
  "Modification on read-only buffer.
BUFFER: Target buffer
APPEND: If non-nil, append instead of replace
BODY: Code to execute with modifications allowed"
  (let ((body (seq-difference body (list :buffer buffer :append append))))
    `(with-current-buffer ,buffer
       (with-silent-modifications
         ,@body))))

(defmacro ob-soql-core--with-temp-buffer (&rest body)
  "Execute BODY in a temporary buffer and return the result.
The buffer is automatically cleaned up."
  `(let ((buf (generate-new-buffer " *ob-soql-temp*")))
     (unwind-protect
         (with-current-buffer buf
           ,@body)
       (when (buffer-live-p buf)
         (kill-buffer buf)))))

(provide 'ob-soql-core)

;;; ob-soql-core.el ends here
