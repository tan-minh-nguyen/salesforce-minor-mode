;;; ob-soql-update.el --- Salesforce update integration for SOQL results -*- lexical-binding: t -*-

;; Copyright (C) 2025

;; Author: tan.nguyen@furucrm.com
;; Keywords: salesforce, soql, org-babel
;; Version: 1.0

;;; Commentary:
;; This module handles pushing updates back to Salesforce via the CLI.
;; Supports both single record updates and bulk updates.

;;; Code:

(require 'ob-soql-edit)
(require 'salesforce-core)

;;; Customization

(defcustom ob-soql-metadata-cache-ttl (* 60 60)
  "Time-to-live for cached SObject metadata in seconds.
Default: 1 hour (3600 seconds)."
  :type 'integer
  :group 'ob-soql)

;;; Variables

(defvar ob-soql--metadata-cache (make-hash-table :test 'equal)
  "Cache for SObject metadata.
Keys: \"org:sobject\"
Values: (metadata . timestamp).")

;;; Commit Changes

(defun ob-soql-commit-changes ()
  "Commit pending changes to Salesforce."
  (interactive)
  (unless ob-soql--query-metadata
    (user-error "No SOQL query metadata available"))
  
  (unless ob-soql--pending-updates
    (user-error "No pending changes to commit"))
  
  (let* ((count (length ob-soql--pending-updates))
         (sobject (plist-get ob-soql--query-metadata :sobject))
         (org (plist-get ob-soql--query-metadata :org))
         (use-bulk (and ob-soql-bulk-update-threshold
                        (>= count ob-soql-bulk-update-threshold))))
    
    (unless sobject
      (user-error "Cannot commit: SObject type unknown. Use :sobject header argument"))
    
    ;; Confirm with user
    (when (or (not ob-soql-confirm-before-commit)
              (yes-or-no-p (format "Commit %d change%s to Salesforce using %s? " 
                                   count 
                                   (if (= count 1) "" "s")
                                   (if use-bulk "bulk API" "single updates"))))
      
      (message "Committing changes...")
      
      ;; Execute update
      (condition-case err
          (if use-bulk
              (ob-soql--update-records-bulk ob-soql--pending-updates sobject org)
            (ob-soql--update-records-sequential ob-soql--pending-updates sobject org))
        (error
         (message "Update failed: %s" (error-message-string err))
         (ob-soql--handle-update-error err ob-soql--pending-updates))))))

;;; Single Record Update

(defun ob-soql--update-record (record-id field-updates sobject org)
  "Update a single record in Salesforce.
RECORD-ID: Salesforce record ID
FIELD-UPDATES: Alist of (field . value)
SOBJECT: SObject type
ORG: Target org name"
  (let* ((values-str (mapconcat (lambda (update)
                                  (pcase-let ((`(,field . ,value) update))
                                    (format "%s='%s'" field 
                                            (ob-soql--escape-value value))))
                                field-updates
                                " "))
         (args `("update" "record"
                 "-s" ,sobject
                 "-i" ,record-id
                 "-v" ,values-str
                 "-o" ,org
                 "--json")))
    
    (let ((result (ob-soql--execute-sf-command args)))
      (if (eq (plist-get result :status) 0)
          (progn
            (message "Updated record %s" record-id)
            t)
        (error "Failed to update record %s: %s" 
               record-id 
               (plist-get result :message))))))

(defun ob-soql--update-records-sequential (updates sobject org)
  "Update multiple records sequentially.
UPDATES: List of (record-id . field-updates)
SOBJECT: SObject type
ORG: Target org name"
  (let ((total (length updates))
        (success 0)
        (failed 0))
    
    (dolist (update updates)
      (pcase-let ((`(,record-id . ,field-updates) update))
        (condition-case err
            (progn
              (ob-soql--update-record record-id field-updates sobject org)
              (setq success (1+ success)))
          (error
           (setq failed (1+ failed))
           (message "Failed to update %s: %s" record-id (error-message-string err))))))
    
    ;; Report results
    (if (= failed 0)
        (progn
          (message "Successfully updated %d record%s" 
                   success (if (= success 1) "" "s"))
          (setq ob-soql--pending-updates nil)
          (ob-soql--update-mode-line)
          (ob-soql-refresh-results))
      (message "Updated %d records, %d failed" success failed))))

;;; Bulk Update

(defun ob-soql--update-records-bulk (updates sobject org)
  "Update multiple records using bulk API.
UPDATES: List of (record-id . field-updates)
SOBJECT: SObject type
ORG: Target org name"
  (let* ((fields (ob-soql--collect-updated-fields updates))
         (csv-file (make-temp-file "soql-bulk-update-" nil ".csv"))
         (csv-content (ob-soql--build-update-csv updates fields)))
    
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
                 (result (ob-soql--execute-sf-command args)))
            
            (if (eq (plist-get result :status) 0)
                (let ((successful (plist-get result :successfulRecords))
                      (failed-count (plist-get result :failedRecords)))
                  (message "Bulk update complete: %d successful, %d failed" 
                           successful failed-count)
                  
                  (when (= failed-count 0)
                    (setq ob-soql--pending-updates nil)
                    (ob-soql--update-mode-line)
                    (ob-soql-refresh-results)))
              (error "Bulk update failed: %s" (plist-get result :message)))))
      
      ;; Cleanup temp file
      (when (file-exists-p csv-file)
        (delete-file csv-file)))))

(defun ob-soql--collect-updated-fields (updates)
  "Collect all unique field names from UPDATES."
  (let ((fields '("Id")))
    (dolist (update updates)
      (pcase-let ((`(,_record-id . ,field-updates) update))
        (dolist (field-update field-updates)
          (pcase-let ((`(,field . ,_value) field-update))
            (unless (member field fields)
              (push field fields))))))
    (nreverse fields)))

(defun ob-soql--build-update-csv (updates fields)
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

(defun ob-soql--execute-sf-command (args)
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

(defun ob-soql--get-sobject-metadata (sobject org &optional force-refresh)
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
      (let ((metadata (ob-soql--fetch-sobject-describe sobject org)))
        (puthash cache-key (cons metadata now) ob-soql--metadata-cache)
        metadata))))

(defun ob-soql--fetch-sobject-describe (sobject org)
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
     (ob-soql--fetch-field-metadata sobject org))))

(defun ob-soql--load-field-metadata ()
  "Load field metadata for current query's SObject."
  (interactive)
  (when-let* ((sobject (plist-get ob-soql--query-metadata :sobject))
              (org (plist-get ob-soql--query-metadata :org)))
    (message "Loading field metadata for %s..." sobject)
    (setq ob-soql--field-metadata 
          (ob-soql--get-sobject-metadata sobject org t))
    (message "Field metadata loaded: %d fields" (length ob-soql--field-metadata))))

;;; Error Handling

(defun ob-soql--handle-update-error (error-data record-updates)
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

(defun ob-soql--escape-value (value)
  "Escape VALUE for Salesforce CLI command.
Handles quotes and special characters."
  (replace-regexp-in-string "'" "\\\\'" (format "%s" value)))

(provide 'ob-soql-update)

;;; ob-soql-update.el ends here
