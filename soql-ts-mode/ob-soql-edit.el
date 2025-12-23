;;; ob-soql-edit.el --- Edit functionality for SOQL results -*- lexical-binding: t -*-

;; Copyright (C) 2025

;; Author: tan.nguyen@furucrm.com
;; Keywords: salesforce, soql, org-babel
;; Version: 1.0

;;; Commentary:
;; This module provides editing capabilities for SOQL query results.
;; Users can edit field values, track changes, preview before commit,
;; and push updates back to Salesforce.

;;; Code:

(require 'ob-soql-display)
(require 'csv-mode nil t)

;; Forward declare to avoid circular dependency
(declare-function ob-soql-commit-changes "ob-soql-update")
(declare-function ob-soql--update-mode-line "ob-soql-edit")
(declare-function ob-soql--load-field-metadata "ob-soql-update")

;;; Customization

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

;;; Variables

(defvar-local ob-soql--pending-updates nil
  "List of pending record updates.
Each entry: (record-id . ((field . new-value) ...)).")

(defvar-local ob-soql--original-records nil
  "Original record data before any edits.
Used for reverting changes.")

(defvar-local ob-soql--field-metadata nil
  "Cached SObject field metadata.
Alist of (field-name . properties).")

;;; Edit Mode

(defvar ob-soql-edit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "e") #'ob-soql-edit-field)
    (define-key map (kbd "m") #'ob-soql-mark-record)
    (define-key map (kbd "c") (lambda () (interactive) 
                                (require 'ob-soql-update)
                                (ob-soql-commit-changes)))
    (define-key map (kbd "r") #'ob-soql-revert-changes)
    (define-key map (kbd "p") #'ob-soql-preview-changes)
    (define-key map (kbd "g") #'ob-soql-refresh-results)
    (define-key map (kbd "?") #'ob-soql-edit-help)
    (define-key map (kbd "M") (lambda () (interactive)
                                (require 'ob-soql-update)
                                (ob-soql--load-field-metadata)))
    map)
  "Keymap for `ob-soql-edit-mode'.")

(define-minor-mode ob-soql-edit-mode
  "Minor mode for editing SOQL query results.

\\{ob-soql-edit-mode-map}"
  :lighter " SOQL-Edit"
  :keymap ob-soql-edit-mode-map
  (if ob-soql-edit-mode
      (progn
        ;; Store original records for revert
        (unless ob-soql--original-records
          (setq ob-soql--original-records
                (copy-tree (plist-get ob-soql--query-metadata :records))))
        ;; Initialize field metadata
        (ob-soql--initialize-field-metadata)
        ;; Update mode line
        (ob-soql--update-mode-line)
        (message "SOQL Edit mode enabled. Press ? for help."))
    ;; Cleanup on disable
    (setq ob-soql--pending-updates nil)))

(defun ob-soql-edit-help ()
  "Show help for SOQL edit mode."
  (interactive)
  (message "SOQL Edit: [e]dit field [m]ark record [c]ommit [r]evert [p]review [g]refresh [M]oad metadata [?]help"))

;;; Field Editing

(defun ob-soql-edit-field ()
  "Edit field value at point."
  (interactive)
  (unless ob-soql--query-metadata
    (user-error "No SOQL query metadata available"))
  
  (let* ((record (ob-soql--get-record-at-point))
         (field (ob-soql--get-field-at-point))
         (record-id (alist-get "Id" record nil nil #'string=))
         (current-value (alist-get field record nil nil #'string=))
         (field-info (ob-soql--get-field-info field)))
    
    (unless record-id
      (user-error "Cannot edit: record has no Id field"))
    
    (unless field
      (user-error "No field at point"))
    
    ;; Check if field is read-only
    (when (and field-info (not (plist-get field-info :updateable)))
      (user-error "Field '%s' is read-only" field))
    
    ;; Prompt for new value
    (let ((new-value (read-string (format "New value for %s: " field) current-value)))
      (ob-soql--track-change record-id field new-value current-value)
      (ob-soql--update-display-value field new-value)
      (ob-soql--update-mode-line)
      (message "Field updated (not committed). Press 'c' to commit or 'r' to revert."))))

(defun ob-soql--get-record-at-point ()
  "Get the record at point based on display mode."
  (let ((records (plist-get ob-soql--query-metadata :records)))
    (cond
     ;; vtable
     ((and (boundp 'vtable-object) vtable-object)
      (require 'vtable)
      (when-let ((obj (vtable-current-object)))
        obj))
     
     ;; tabulated-list-mode
     ((derived-mode-p 'tabulated-list-mode)
      (when-let ((id (tabulated-list-get-id)))
        (nth (1- id) records)))
     
     ;; csv-mode - parse current line
     ((derived-mode-p 'csv-mode)
      (save-excursion
        (beginning-of-line)
        (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
               (values (split-string line ","))
               (fields (plist-get ob-soql--query-metadata :fields)))
          (cl-mapcar #'cons fields values))))
     
     (t (user-error "Unknown display mode")))))

(defun ob-soql--get-field-at-point ()
  "Get the field name at point based on display mode."
  (cond
   ;; vtable
   ((and (boundp 'vtable-object) vtable-object)
    (require 'vtable)
    (when-let ((col (vtable-current-column)))
      (plist-get (nth col (vtable-columns vtable-object)) :name)))
   
   ;; tabulated-list-mode
   ((derived-mode-p 'tabulated-list-mode)
    (let* ((col (current-column))
           (formats tabulated-list-format)
           (total 0)
           (field-idx 0))
      (while (and (< field-idx (length formats))
                  (< total col))
        (setq total (+ total (cadr (aref formats field-idx)) 1))
        (setq field-idx (1+ field-idx)))
      (when (< field-idx (length formats))
        (car (aref formats field-idx)))))
   
   ;; csv-mode
   ((derived-mode-p 'csv-mode)
    (let* ((fields (plist-get ob-soql--query-metadata :fields))
           (field-idx (csv-current-field)))
      (nth field-idx fields)))
   
   (t nil)))

(defun ob-soql--update-display-value (field new-value)
  "Update display to show NEW-VALUE for FIELD at point."
  (cond
   ;; vtable - requires refresh
   ((and (boundp 'vtable-object) vtable-object)
    (let* ((record (ob-soql--get-record-at-point))
           (record-id (alist-get "Id" record nil nil #'string=))
           (records (plist-get ob-soql--query-metadata :records)))
      ;; Update the record in metadata
      (dolist (rec records)
        (when (string= (alist-get "Id" rec nil nil #'string=) record-id)
          (setf (alist-get field rec nil nil #'string=) new-value)))
      ;; Refresh vtable
      (require 'vtable)
      (vtable-revert-command)))
   
   ;; tabulated-list-mode - update entry
   ((derived-mode-p 'tabulated-list-mode)
    (let* ((id (tabulated-list-get-id))
           (entry (nth (1- id) tabulated-list-entries))
           (fields (plist-get ob-soql--query-metadata :fields))
           (field-idx (cl-position field fields :test #'string=))
           (values (cadr entry)))
      (when field-idx
        (aset values field-idx new-value)
        (tabulated-list-print t))))
   
   ;; csv-mode - update current field
   ((derived-mode-p 'csv-mode)
    (csv-kill-field nil)
    (insert new-value))))

(defun ob-soql-mark-record ()
  "Mark current record for bulk editing."
  (interactive)
  (message "Record marking not yet implemented"))

;;; Change Tracking

(defun ob-soql--track-change (record-id field new-value old-value)
  "Track a field change for RECORD-ID.
FIELD: Field name
NEW-VALUE: New field value
OLD-VALUE: Original field value"
  (let ((record-updates (alist-get record-id ob-soql--pending-updates 
                                   nil nil #'string=)))
    ;; If new value equals original, remove the change
    (if (string= new-value old-value)
        (setq record-updates (assoc-delete-all field record-updates))
      ;; Otherwise, add/update the change
      (setf (alist-get field record-updates nil nil #'string=) new-value))
    
    ;; Update pending updates
    (if record-updates
        (setf (alist-get record-id ob-soql--pending-updates nil nil #'string=)
              record-updates)
      ;; Remove record if no changes
      (setq ob-soql--pending-updates
            (assoc-delete-all record-id ob-soql--pending-updates)))))

(defun ob-soql-revert-changes ()
  "Discard all pending changes."
  (interactive)
  (when (or (not ob-soql-confirm-before-commit)
            (yes-or-no-p "Revert all changes? "))
    (setq ob-soql--pending-updates nil)
    ;; Restore original records in metadata
    (plist-put ob-soql--query-metadata :records
               (copy-tree ob-soql--original-records))
    ;; Refresh display
    (ob-soql--refresh-display)
    (ob-soql--update-mode-line)
    (message "All changes reverted")))

(defun ob-soql--refresh-display ()
  "Refresh the display with current data."
  (cond
   ((and (boundp 'vtable-object) vtable-object)
    (require 'vtable)
    (vtable-revert-command))
   
   ((derived-mode-p 'tabulated-list-mode)
    (let* ((records (plist-get ob-soql--query-metadata :records))
           (fields (plist-get ob-soql--query-metadata :fields))
           (id 0))
      (setq tabulated-list-entries
            (mapcar (lambda (record)
                      (setq id (1+ id))
                      (list id
                            (apply #'vector
                                   (mapcar (lambda (field)
                                             (or (alist-get field record nil nil #'string=) ""))
                                           fields))))
                    records))
      (tabulated-list-print t)))
   
   ((derived-mode-p 'csv-mode)
    (let* ((csv-data (plist-get ob-soql--query-metadata :csv-data)))
      (erase-buffer)
      (insert csv-data)))))

;;; Preview Changes

(defun ob-soql-preview-changes ()
  "Show pending changes before committing."
  (interactive)
  (if (null ob-soql--pending-updates)
      (message "No pending changes")
    (let ((count (length ob-soql--pending-updates))
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
        (dolist (update ob-soql--pending-updates)
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
      
      (pop-to-buffer preview-buf))))

;;; Mode Line

(defun ob-soql--update-mode-line ()
  "Update mode line to show pending changes count."
  (let ((count (length ob-soql--pending-updates)))
    (setq mode-line-buffer-identification
          (list (format "SOQL Results [%d change%s]"
                        count
                        (if (= count 1) "" "s"))))))

;;; Field Metadata

(defun ob-soql--get-field-info (field)
  "Get metadata for FIELD.
Returns plist with :updateable, :type, etc."
  (alist-get field ob-soql--field-metadata nil nil #'string=))

(defun ob-soql--initialize-field-metadata ()
  "Initialize field metadata with basic system field info.
This is a fallback when full metadata is not available."
  (let ((system-fields '("Id" "CreatedDate" "CreatedById" "LastModifiedDate" 
                         "LastModifiedById" "SystemModstamp" "IsDeleted")))
    (setq ob-soql--field-metadata
          (mapcar (lambda (field)
                    (cons field
                          (list :updateable (not (member field system-fields))
                                :type "String")))
                  (plist-get ob-soql--query-metadata :fields)))))

(provide 'ob-soql-edit)

;;; ob-soql-edit.el ends here
