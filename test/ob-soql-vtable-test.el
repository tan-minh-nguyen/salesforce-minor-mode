;;; ob-soql-vtable-test.el --- Tests for ob-soql-vtable.el -*- lexical-binding: t -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author: Tan Nguyen <tan.nguyen@furucrm.com>
;; Keywords: test

;;; Commentary:
;;
;; Tests for ob-soql-vtable.el - VTable actions implementation
;;

;;; Code:

(require 'ert)

;; Mock dependencies to avoid requiring external packages
(unless (featurep 'alert)
  (provide 'alert))

(unless (featurep 'salesforce-core)
  (defvar salesforce-process-idle-time 30)
  (defvar salesforce-process-error-handler nil)
  (defmacro salesforce-with-process (&rest body) `(progn ,@body))
  (provide 'salesforce-core))

(unless (featurep 'salesforce-project)
  (defun salesforce-project--get-user-data (org key) 
    "Mock function."
    "https://test.salesforce.com")
  (provide 'salesforce-project))

(require 'ob-soql-core)
(require 'ob-soql-vtable)

;;; Test Data

(defvar ob-soql-test-metadata
  '(:query "SELECT Id, Name, Email FROM Account"
           :org "test-org"
           :org-url "https://test.salesforce.com"
           :sobject "Account"
           :fields ("Id" "Name" "Email")
           :records (
                     (("Id" . "001xxx") ("Name" . "Acme Corp") ("Email" . "acme@test.com"))
                     (("Id" . "001yyy") ("Name" . "Wayne Inc") ("Email" . "wayne@test.com"))
                     )
           :pending-updates nil
           :original-records (
                              (("Id" . "001xxx") ("Name" . "Acme Corp") ("Email" . "acme@test.com"))
                              (("Id" . "001yyy") ("Name" . "Wayne Inc") ("Email" . "wayne@test.com"))
                              )
           :field-metadata (
                            ("Id" . (:updateable nil :type "id"))
                            ("Name" . (:updateable t :type "string"))
                            ("Email" . (:updateable t :type "email"))
                            )
           :editable t)
  "Test metadata for SOQL query results.")

(defvar ob-soql-test-metadata-readonly
  (plist-put (copy-tree ob-soql-test-metadata) :editable nil)
  "Read-only test metadata.")

;;; Helper Functions

(defun ob-soql-test--with-temp-buffer (metadata body-fn)
  "Execute BODY-FN in a temporary buffer with METADATA.
Sets up buffer-local ob-soql--query-metadata."
  (with-temp-buffer
    (setq-local ob-soql--query-metadata (copy-tree metadata))
    (funcall body-fn)))

;;; Tests for ob-soql-vtable--make-action

(ert-deftest ob-soql-vtable-test-make-action ()
  "Test that ob-soql-vtable--make-action creates proper closures."
  (let* ((test-metadata ob-soql-test-metadata)
         (called-with nil)
         (test-fn (lambda (row metadata)
                    (setq called-with (list row metadata))))
         (action (ob-soql-vtable--make-action test-fn test-metadata))
         (test-row '(("Id" . "001xxx") ("Name" . "Test"))))
    
    ;; Action should be a function
    (should (functionp action))
    
    ;; Call the action with a row
    (funcall action test-row)
    
    ;; Verify it was called with correct arguments
    (should (equal (car called-with) test-row))
    (should (equal (cadr called-with) test-metadata))))

;;; Tests for ob-soql-vtable--create-actions

(ert-deftest ob-soql-vtable-test-create-actions-editable ()
  "Test that create-actions returns full action list when editable."
  (let* ((metadata (plist-put (copy-tree ob-soql-test-metadata) :editable t))
         (actions (ob-soql-vtable--create-actions metadata)))
    
    ;; Should be an alist
    (should (listp actions))
    
    ;; Should have all action keys for editable mode
    (should (assoc "RET" actions))
    (should (assoc "e" actions))
    (should (assoc "c" actions))
    (should (assoc "r" actions))
    (should (assoc "p" actions))
    (should (assoc "g" actions))
    (should (assoc "M" actions))
    (should (assoc "?" actions))
    (should (assoc "q" actions))
    
    ;; All values should be functions
    (dolist (action actions)
      (should (functionp (cdr action))))))

(ert-deftest ob-soql-vtable-test-create-actions-readonly ()
  "Test that create-actions returns limited actions when read-only."
  (let* ((metadata (plist-put (copy-tree ob-soql-test-metadata) :editable nil))
         (actions (ob-soql-vtable--create-actions metadata)))
    
    ;; Should have base actions
    (should (assoc "RET" actions))
    (should (assoc "g" actions))
    (should (assoc "?" actions))
    (should (assoc "q" actions))
    
    ;; Should NOT have edit actions
    (should-not (assoc "e" actions))
    (should-not (assoc "c" actions))
    (should-not (assoc "r" actions))
    (should-not (assoc "p" actions))
    (should-not (assoc "M" actions))))

;;; Tests for ob-soql-vtable--open-record

(ert-deftest ob-soql-vtable-test-open-record ()
  "Test opening a record in browser."
  (let* ((row '(("Id" . "001xxx123") ("Name" . "Test")))
         (metadata ob-soql-test-metadata)
         (browse-url-called nil)
         (browse-url-arg nil))
    
    ;; Mock browse-url
    (cl-letf (((symbol-function 'browse-url)
               (lambda (url)
                 (setq browse-url-called t
                       browse-url-arg url))))
      
      (ob-soql-vtable--open-record row metadata)
      
      ;; Should call browse-url with correct URL
      (should browse-url-called)
      (should (string= browse-url-arg "https://test.salesforce.com/001xxx123")))))

(ert-deftest ob-soql-vtable-test-open-record-no-id ()
  "Test opening a record without Id field."
  (let* ((row '(("Name" . "Test")))  ; No Id field
         (metadata ob-soql-test-metadata)
         (message-called nil)
         (message-text nil))
    
    ;; Mock message
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (setq message-called t
                       message-text (apply #'format fmt args)))))
      
      (ob-soql-vtable--open-record row metadata)
      
      ;; Should show error message
      (should message-called)
      (should (string-match-p "Id field not found" message-text)))))

;;; Tests for ob-soql-vtable--track-change

(ert-deftest ob-soql-vtable-test-track-change-new ()
  "Test tracking a new change."
  (let ((metadata (copy-tree ob-soql-test-metadata)))
    ;; Track a change
    (ob-soql-vtable--track-change "001xxx" "Name" "New Name" "Acme Corp" metadata)
    
    ;; Verify pending-updates was updated
    (let ((pending (plist-get metadata :pending-updates)))
      (should pending)
      (should (equal (assoc-default "001xxx" pending nil #'string=)
                     '(("Name" . "New Name")))))))

(ert-deftest ob-soql-vtable-test-track-change-revert-to-original ()
  "Test that reverting to original value removes the change."
  (let ((metadata (copy-tree ob-soql-test-metadata)))
    ;; Track a change
    (ob-soql-vtable--track-change "001xxx" "Name" "New Name" "Acme Corp" metadata)
    
    ;; Verify change is tracked
    (should (plist-get metadata :pending-updates))
    
    ;; Revert to original value
    (ob-soql-vtable--track-change "001xxx" "Name" "Acme Corp" "New Name" metadata)
    
    ;; Verify pending-updates is empty
    (should-not (plist-get metadata :pending-updates))))

(ert-deftest ob-soql-vtable-test-track-change-multiple-fields ()
  "Test tracking changes to multiple fields on same record."
  (let ((metadata (copy-tree ob-soql-test-metadata)))
    ;; Track changes to two fields
    (ob-soql-vtable--track-change "001xxx" "Name" "New Name" "Acme Corp" metadata)
    (ob-soql-vtable--track-change "001xxx" "Email" "new@test.com" "acme@test.com" metadata)
    
    ;; Verify both changes are tracked
    (let ((record-updates (assoc-default "001xxx" (plist-get metadata :pending-updates) nil #'string=)))
      (should (equal (assoc-default "Name" record-updates nil #'string=) "New Name"))
      (should (equal (assoc-default "Email" record-updates nil #'string=) "new@test.com")))))

;;; Tests for ob-soql-vtable--update-record-in-metadata

(ert-deftest ob-soql-vtable-test-update-record-in-metadata ()
  "Test updating a record's field value in metadata."
  (let ((metadata (copy-tree ob-soql-test-metadata)))
    ;; Update a field
    (ob-soql-vtable--update-record-in-metadata "001xxx" "Name" "Updated Name" metadata)
    
    ;; Verify the record was updated
    (let ((records (plist-get metadata :records)))
      (should (equal (assoc-default "Name" (car records) nil #'string=)
                     "Updated Name")))))

(ert-deftest ob-soql-vtable-test-update-record-in-metadata-wrong-id ()
  "Test updating a record that doesn't exist."
  (let ((metadata (copy-tree ob-soql-test-metadata)))
    ;; Try to update non-existent record
    (ob-soql-vtable--update-record-in-metadata "999zzz" "Name" "Test" metadata)
    
    ;; Verify no records were changed
    (let ((records (plist-get metadata :records)))
      (should (equal (assoc-default "Name" (car records) nil #'string=)
                     "Acme Corp")))))

;;; Tests for ob-soql-vtable--get-field-info

(ert-deftest ob-soql-vtable-test-get-field-info ()
  "Test getting field metadata info."
  (let ((metadata ob-soql-test-metadata))
    ;; Get updateable field
    (let ((name-info (ob-soql-vtable--get-field-info "Name" metadata)))
      (should name-info)
      (should (plist-get name-info :updateable))
      (should (equal (plist-get name-info :type) "string")))
    
    ;; Get read-only field
    (let ((id-info (ob-soql-vtable--get-field-info "Id" metadata)))
      (should id-info)
      (should-not (plist-get id-info :updateable))
      (should (equal (plist-get id-info :type) "id")))
    
    ;; Get non-existent field
    (should-not (ob-soql-vtable--get-field-info "NonExistent" metadata))))

;;; Tests for ob-soql-vtable--show-help

(ert-deftest ob-soql-vtable-test-show-help-editable ()
  "Test help message for editable mode."
  (let ((metadata (plist-put (copy-tree ob-soql-test-metadata) :editable t))
        (message-text nil))
    
    ;; Mock message
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (setq message-text (apply #'format fmt args)))))
      
      (ob-soql-vtable--show-help nil metadata)
      
      ;; Should show all actions
      (should (string-match-p "\\[RET\\]Open" message-text))
      (should (string-match-p "\\[e\\]dit" message-text))
      (should (string-match-p "\\[c\\]ommit" message-text))
      (should (string-match-p "\\[r\\]evert" message-text))
      (should (string-match-p "\\[p\\]review" message-text))
      (should (string-match-p "\\[g\\]refresh" message-text))
      (should (string-match-p "\\[M\\]etadata" message-text))
      (should (string-match-p "\\[\\?\\]help" message-text))
      (should (string-match-p "\\[q\\]uit" message-text)))))

(ert-deftest ob-soql-vtable-test-show-help-readonly ()
  "Test help message for read-only mode."
  (let ((metadata (plist-put (copy-tree ob-soql-test-metadata) :editable nil))
        (message-text nil))
    
    ;; Mock message
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (setq message-text (apply #'format fmt args)))))
      
      (ob-soql-vtable--show-help nil metadata)
      
      ;; Should only show read-only actions
      (should (string-match-p "\\[RET\\]Open" message-text))
      (should (string-match-p "\\[g\\]refresh" message-text))
      (should (string-match-p "\\[\\?\\]help" message-text))
      (should (string-match-p "\\[q\\]uit" message-text))
      
      ;; Should NOT show edit actions
      (should-not (string-match-p "\\[e\\]dit" message-text))
      (should-not (string-match-p "\\[c\\]ommit" message-text)))))

;;; Integration Tests

(ert-deftest ob-soql-vtable-test-edit-workflow ()
  "Test complete edit workflow: edit -> commit -> revert."
  (let ((metadata (copy-tree ob-soql-test-metadata)))
    ;; Step 1: Edit a field
    (ob-soql-vtable--track-change "001xxx" "Name" "New Name" "Acme Corp" metadata)
    (ob-soql-vtable--update-record-in-metadata "001xxx" "Name" "New Name" metadata)
    
    ;; Verify change is pending
    (should (plist-get metadata :pending-updates))
    (let ((records (plist-get metadata :records)))
      (should (equal (assoc-default "Name" (car records) nil #'string=)
                     "New Name")))
    
    ;; Step 2: Simulate commit (just clear pending updates)
    (plist-put metadata :pending-updates nil)
    (plist-put metadata :original-records (copy-tree (plist-get metadata :records)))
    
    ;; Verify no pending updates
    (should-not (plist-get metadata :pending-updates))
    
    ;; Step 3: Make another edit
    (ob-soql-vtable--track-change "001xxx" "Email" "new@test.com" "acme@test.com" metadata)
    
    ;; Verify new change is tracked
    (should (plist-get metadata :pending-updates))
    
    ;; Step 4: Revert
    (plist-put metadata :pending-updates nil)
    (plist-put metadata :records (copy-tree (plist-get metadata :original-records)))
    
    ;; Verify reverted to committed state
    (let ((records (plist-get metadata :records)))
      (should (equal (assoc-default "Name" (car records) nil #'string=)
                     "New Name"))  ; This was committed
      (should (equal (assoc-default "Email" (car records) nil #'string=)
                     "acme@test.com")))))  ; This was reverted

(provide 'ob-soql-vtable-test)
;;; ob-soql-vtable-test.el ends here
