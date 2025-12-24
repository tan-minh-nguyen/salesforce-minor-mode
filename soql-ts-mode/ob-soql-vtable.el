;;; ob-soql-vtable.el --- VTable display with integrated actions for SOQL results -*- lexical-binding: t -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author     : Tan Nguyen <tan.nguyen@furucrm.com>
;; Maintainer : Tan Nguyen
;; Created    : December 2024
;; Keywords   : soql salesforce org-babel vtable
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
;; VTable display with integrated actions for SOQL results.
;; Replaces the old ob-soql-edit-mode approach with vtable's native action system.
;;
;; Actions are registered via vtable's :actions parameter and receive row context.
;; All state is managed through the metadata plist stored as buffer-local.
;;
;; Key bindings:
;;   RET - Open record in Salesforce
;;   e   - Edit field at point
;;   c   - Commit pending changes
;;   r   - Revert all changes
;;   p   - Preview pending changes
;;   g   - Refresh query results
;;   M   - Load field metadata
;;   ?   - Show help
;;   q   - Quit window

;;; Code:

(require 'ob-soql-core)

;;; ========================================
;;; VTable Display
;;; ========================================

(defun ob-soql--display-as-vtable (metadata)
  "Display results using vtable widget with actions.
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
      (ob-soql-core-buffer-modifications
       :buffer buffer

       ;; Store metadata with state management fields
       (setq-local ob-soql--query-metadata
                   (plist-put (plist-put (plist-put metadata
                                                    :pending-updates nil)
                                         :original-records (copy-tree records))
                              :field-metadata nil))

       ;; Create vtable
       ;; Note: We use ob-soql-results-mode-map for keybindings instead of vtable's :actions
       ;; because the shared action handlers work across all display formats
       (let ((table (make-vtable
                     :columns (mapcar (lambda (field)
                                        `(:name ,field
                                                :width ,(min ob-soql-display-max-column-width
                                                             (max 20 (length field)))))
                                      fields)
                     :objects records
                     :getter (lambda (record column-index vtable)
                               (let* ((column-name (vtable-column vtable column-index))
                                      (value (assoc-default column-name record #'string-equal-ignore-case "")))
                                 (ob-soql-core--truncate-string value
                                                                ob-soql-display-max-column-width)))
                     :actions (ob-soql-vtable--create-actions metadata)
                     :use-header-line nil)))
         (setq-local vtable-object table))

       (goto-char (point-min))
       (ob-soql-results-mode))

      (pop-to-buffer buffer)
      buffer)))

;;; ========================================
;;; Action System
;;; ========================================

(defun ob-soql-vtable--make-action (fn metadata)
  "Create vtable action closure.
FN is the action function receiving (row metadata).
METADATA is captured in closure.
Returns lambda suitable for vtable :actions."
  (lambda (row)
    (funcall fn row metadata)))

(defun ob-soql-vtable--create-actions (metadata)
  "Create complete action alist for vtable.
METADATA: Query metadata plist.
Returns alist: ((key . action-fn) ...)"
  (let ((editable (plist-get metadata :editable))
        (base-actions
         `("RET" ,(ob-soql-vtable--make-action #'ob-soql-vtable--open-record metadata)
           "g"   ,(ob-soql-vtable--make-action #'ob-soql-vtable--refresh metadata)
           "?"   ,(ob-soql-vtable--make-action #'ob-soql-vtable--show-help metadata)
           "q"   ,(ob-soql-vtable--make-action #'ob-soql-vtable--quit metadata))))

    (if editable
        ;; Add editing actions
        (append base-actions
                `("e" ,(ob-soql-vtable--make-action #'ob-soql-vtable--edit-field metadata)
                  "c" ,(ob-soql-vtable--make-action #'ob-soql-vtable--commit-changes metadata)
                  "r" ,(ob-soql-vtable--make-action #'ob-soql-vtable--revert-changes metadata)
                  "p" ,(ob-soql-vtable--make-action #'ob-soql-vtable--preview-changes metadata)
                  "M" ,(ob-soql-vtable--make-action #'ob-soql-vtable--load-metadata metadata)))
      ;; Read-only mode
      base-actions)))

;;; ========================================
;;; Action Handlers
;;; ========================================

(defun ob-soql-vtable--open-record (row metadata)
  "Open record in Salesforce browser.
ROW: Current record (alist)
METADATA: Query metadata plist"
  (let ((org-url (plist-get metadata :org-url))
        (id (assoc-default "Id" row (lambda (v1 v2)
                                      (string= (downcase v1)
                                               (downcase v2))))))
    (if id
        (browse-url (concat org-url "/" id))
      (message "Id field not found on record."))))

(defun ob-soql-vtable--edit-field (row metadata)
  "Edit field value at point.
ROW: Current record (alist)
METADATA: Query metadata plist"
  (require 'vtable)
  (let* ((record-id (assoc-default "Id" row (lambda (v1 v2)
                                              (string= (downcase v1) (downcase v2)))))
         (field (when (vtable-current-column)
                  (plist-get (nth (vtable-current-column) (vtable-columns vtable-object))
                             :name)))
         (current-value (assoc-default field row nil #'string=))
         (field-info (ob-soql-vtable--get-field-info field metadata)))

    (unless record-id
      (user-error "Cannot edit: record has no Id field"))
    (unless field
      (user-error "No field at point"))

    ;; Check if field is read-only
    (when (and field-info (not (plist-get field-info :updateable)))
      (user-error "Field '%s' is read-only" field))

    ;; Prompt for new value
    (let ((new-value (read-string (format "New value for %s: " field) current-value)))
      (ob-soql-vtable--track-change record-id field new-value current-value metadata)
      (ob-soql-vtable--update-record-in-metadata record-id field new-value metadata)
      (vtable-revert-command)
      (message "Field updated (not committed). Press 'c' to commit or 'r' to revert."))))

(defun ob-soql-vtable--commit-changes (row metadata)
  "Commit pending changes to Salesforce.
ROW: Current record (ignored)
METADATA: Query metadata plist"
  (let ((pending-updates (plist-get metadata :pending-updates)))
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

(defun ob-soql-vtable--revert-changes (row metadata)
  "Revert all pending changes.
ROW: Current record (ignored)
METADATA: Query metadata plist"
  (when (or (not ob-soql-confirm-before-commit)
            (yes-or-no-p "Revert all changes? "))
    (plist-put metadata :pending-updates nil)
    (plist-put metadata :records
               (copy-tree (plist-get metadata :original-records)))
    (require 'vtable)
    (vtable-revert-command)
    (message "All changes reverted")))

(defun ob-soql-vtable--preview-changes (row metadata)
  "Show pending changes preview.
ROW: Current record (ignored)
METADATA: Query metadata plist"
  (let ((pending-updates (plist-get metadata :pending-updates)))
    (if (null pending-updates)
        (message "No pending changes")
      (ob-soql-core--show-changes-preview pending-updates metadata))))

(defun ob-soql-vtable--refresh (row metadata)
  "Refresh query results.
ROW: Current record (ignored)
METADATA: Query metadata plist"
  (message "Refreshing query results...")
  ;; TODO: Re-execute query and update display
  (message "Refresh not yet implemented"))

(defun ob-soql-vtable--load-metadata (row metadata)
  "Load field metadata from Salesforce.
ROW: Current record (ignored)
METADATA: Query metadata plist"
  (let ((sobject (plist-get metadata :sobject))
        (org (plist-get metadata :org)))
    (if (and sobject org)
        (progn
          (message "Loading field metadata for %s..." sobject)
          (let ((field-metadata (ob-soql-core--get-sobject-metadata sobject org t)))
            (plist-put metadata :field-metadata field-metadata)
            (message "Field metadata loaded: %d fields" (length field-metadata))))
      (message "Cannot load metadata: sobject or org not specified"))))

(defun ob-soql-vtable--show-help (row metadata)
  "Show available actions.
ROW: Current record (ignored)
METADATA: Query metadata plist"
  (if (plist-get metadata :editable)
      (message "Actions: [RET]Open [e]dit [c]ommit [r]evert [p]review [g]refresh [M]etadata [?]help [q]uit")
    (message "Actions: [RET]Open [g]refresh [?]help [q]uit")))

(defun ob-soql-vtable--quit (row metadata)
  "Quit vtable window.
ROW: Current record (ignored)
METADATA: Query metadata plist"
  (quit-window))

;;; ========================================
;;; Helper Functions
;;; ========================================

(defun ob-soql-vtable--track-change (record-id field new-value old-value metadata)
  "Track a field change in metadata.
RECORD-ID: Salesforce record ID
FIELD: Field name
NEW-VALUE: New value
OLD-VALUE: Original value (unused - we check against :original-records instead)
METADATA: Query metadata plist"
  (let* ((pending-updates (plist-get metadata :pending-updates))
         (record-updates (assoc-default record-id pending-updates nil #'string=))
         (original-records (plist-get metadata :original-records))
         (original-record (cl-find-if (lambda (r)
                                        (string= (assoc-default "Id" r nil #'string=) record-id))
                                      original-records))
         (original-value (when original-record
                           (assoc-default field original-record nil #'string=))))

    ;; If new value equals original from database, remove the change
    (if (and original-value (string= new-value original-value))
        (setq record-updates (assoc-delete-all field record-updates))
      ;; Otherwise, add/update the change
      (setf (alist-get field record-updates nil nil #'string=) new-value))

    ;; Update pending updates in metadata
    (if record-updates
        (setf (alist-get record-id pending-updates nil nil #'string=) record-updates)
      ;; Remove record if no changes
      (setq pending-updates (assoc-delete-all record-id pending-updates)))

    (plist-put metadata :pending-updates pending-updates)))

(defun ob-soql-vtable--update-record-in-metadata (record-id field new-value metadata)
  "Update record field value in metadata records.
RECORD-ID: Salesforce record ID
FIELD: Field name
NEW-VALUE: New value
METADATA: Query metadata plist"
  (let ((records (plist-get metadata :records)))
    (dolist (record records)
      (when (string= (assoc-default "Id" record nil #'string=) record-id)
        (setf (alist-get field record nil nil #'string=) new-value)))))

(defun ob-soql-vtable--get-field-info (field metadata)
  "Get field metadata info.
FIELD: Field name
METADATA: Query metadata plist
Returns field info plist or nil"
  (let ((field-metadata (plist-get metadata :field-metadata)))
    (assoc-default field field-metadata nil #'string=)))

(provide 'ob-soql-vtable)
;;; ob-soql-vtable.el ends here
