;;; ob-soql-core-test.el --- Tests for ob-soql-core.el -*- lexical-binding: t -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;; Author: Tan Nguyen <tan.nguyen@furucrm.com>
;; Keywords: test

;;; Commentary:
;;
;; Tests for ob-soql-core.el - Core SOQL functionality
;;

;;; Code:

(require 'ert)
(require 'ob-soql-core)

;;; Test Data

(defvar ob-soql-core-test-query
  "SELECT Id, Name, Email FROM Account LIMIT 10"
  "Test SOQL query.")

(defvar ob-soql-core-test-csv
  "Id,Name,Email\n001xxx,Acme Corp,acme@test.com\n001yyy,Wayne Inc,wayne@test.com"
  "Test CSV data.")

(defvar ob-soql-core-test-records
  '((("Id" . "001xxx") ("Name" . "Acme Corp") ("Email" . "acme@test.com"))
    (("Id" . "001yyy") ("Name" . "Wayne Inc") ("Email" . "wayne@test.com")))
  "Test record data.")

;;; Tests for SObject Extraction

(ert-deftest ob-soql-core-test-extract-sobject-simple ()
  "Test extracting SObject from simple query."
  (should (equal (ob-soql-core--extract-sobject "SELECT Id FROM Account")
                 "Account")))

(ert-deftest ob-soql-core-test-extract-sobject-custom ()
  "Test extracting custom SObject."
  (should (equal (ob-soql-core--extract-sobject "SELECT Id FROM CustomObject__c")
                 "CustomObject__c")))

(ert-deftest ob-soql-core-test-extract-sobject-multiline ()
  "Test extracting SObject from multiline query."
  (should (equal (ob-soql-core--extract-sobject 
                  "SELECT Id, Name\nFROM   Account\nWHERE Status = 'Active'")
                 "Account")))

(ert-deftest ob-soql-core-test-extract-sobject-lowercase ()
  "Test extracting SObject with lowercase FROM."
  (should (equal (ob-soql-core--extract-sobject "SELECT Id from Account")
                 "Account")))

(ert-deftest ob-soql-core-test-extract-sobject-none ()
  "Test extracting SObject when no FROM clause."
  (should-not (ob-soql-core--extract-sobject "SELECT COUNT() FROM")))

;;; Tests for CSV Parsing

(ert-deftest ob-soql-core-test-parse-csv-simple ()
  "Test parsing simple CSV data."
  (let* ((csv "Id,Name\n001,Test\n002,Demo")
         (result (ob-soql-core--parse-csv csv)))
    (should (equal (plist-get result :fields) '("Id" "Name")))
    (should (= (length (plist-get result :records)) 2))
    (let ((first-record (car (plist-get result :records))))
      (should (equal (assoc-default "Id" first-record nil #'string=) "001"))
      (should (equal (assoc-default "Name" first-record nil #'string=) "Test")))))

(ert-deftest ob-soql-core-test-parse-csv-empty ()
  "Test parsing empty CSV."
  (let ((result (ob-soql-core--parse-csv "")))
    (should (equal (plist-get result :fields) nil))
    (should (equal (plist-get result :records) nil))))

(ert-deftest ob-soql-core-test-parse-csv-header-only ()
  "Test parsing CSV with only header."
  (let ((result (ob-soql-core--parse-csv "Id,Name,Email")))
    (should (equal (plist-get result :fields) '("Id" "Name" "Email")))
    (should (equal (plist-get result :records) nil))))

(ert-deftest ob-soql-core-test-parse-csv-with-empty-values ()
  "Test parsing CSV with empty values."
  (let* ((csv "Id,Name,Email\n001,Test,\n002,,test@example.com")
         (result (ob-soql-core--parse-csv csv))
         (records (plist-get result :records)))
    (should (= (length records) 2))
    ;; First record has empty email
    (should (equal (assoc-default "Email" (car records) nil #'string=) ""))
    ;; Second record has empty name
    (should (equal (assoc-default "Name" (cadr records) nil #'string=) ""))))

;;; Tests for Org URL

(ert-deftest ob-soql-core-test-org-url ()
  "Test getting org URL from salesforce-project."
  (let ((salesforce-project--get-user-data-result "https://test.salesforce.com"))
    ;; Mock salesforce-project--get-user-data
    (cl-letf (((symbol-function 'salesforce-project--get-user-data)
               (lambda (org key)
                 (should (equal org "test-org"))
                 (should (equal key "instanceUrl"))
                 salesforce-project--get-user-data-result)))
      
      (should (equal (ob-soql-core--org-url "test-org")
                     "https://test.salesforce.com")))))

;;; Tests for CSV Modification (ID to Hyperlink)

(ert-deftest ob-soql-core-test-modify-csv-with-id ()
  "Test converting Id field to hyperlink."
  (let* ((csv "Id,Name\n001xxx,Test\n002yyy,Demo")
         (org-url "https://test.salesforce.com")
         (result (ob-soql-core--modify-csv csv org-url)))
    ;; Should contain org-mode links
    (should (string-match-p "\\[\\[https://test.salesforce.com/001xxx\\]\\[001xxx\\]\\]" result))
    (should (string-match-p "\\[\\[https://test.salesforce.com/002yyy\\]\\[002yyy\\]\\]" result))))

(ert-deftest ob-soql-core-test-modify-csv-case-insensitive-id ()
  "Test that Id field is matched case-insensitively."
  (let* ((csv "id,Name\n001xxx,Test")  ; lowercase 'id'
         (org-url "https://test.salesforce.com")
         (result (ob-soql-core--modify-csv csv org-url)))
    ;; Should still convert to hyperlink
    (should (string-match-p "\\[\\[https://test.salesforce.com/001xxx\\]\\[001xxx\\]\\]" result))))

(ert-deftest ob-soql-core-test-modify-csv-no-id-field ()
  "Test CSV without Id field is unchanged."
  (let* ((csv "Name,Email\nTest,test@example.com")
         (org-url "https://test.salesforce.com")
         (result (ob-soql-core--modify-csv csv org-url)))
    ;; Should be unchanged
    (should (equal result csv))))

(ert-deftest ob-soql-core-test-modify-csv-empty ()
  "Test modifying empty CSV."
  (let* ((csv "")
         (org-url "https://test.salesforce.com")
         (result (ob-soql-core--modify-csv csv org-url)))
    (should (equal result csv))))

;;; Tests for Convert ID to Hyperlink

(ert-deftest ob-soql-core-test-convert-id-to-hyperlink ()
  "Test converting Salesforce ID to org-mode hyperlink."
  (let ((result (ob-soql-core--convert-id-to-hyperlink 
                 "001xxx123"
                 "https://test.salesforce.com")))
    (should (equal result "[[https://test.salesforce.com/001xxx123][001xxx123]]"))))

;;; Tests for String Truncation

(ert-deftest ob-soql-core-test-truncate-string-short ()
  "Test that short strings are not truncated."
  (should (equal (ob-soql-core--truncate-string "Short" 50)
                 "Short")))

(ert-deftest ob-soql-core-test-truncate-string-long ()
  "Test that long strings are truncated."
  (let ((long-string (make-string 100 ?a)))
    (should (equal (ob-soql-core--truncate-string long-string 50)
                   (concat (make-string 47 ?a) "...")))))

(ert-deftest ob-soql-core-test-truncate-string-exact ()
  "Test that strings exactly at max width are not truncated."
  (let ((string (make-string 50 ?a)))
    (should (equal (ob-soql-core--truncate-string string 50)
                   string))))

(ert-deftest ob-soql-core-test-truncate-string-disabled ()
  "Test truncation when ob-soql-display-truncate-strings is nil."
  (let ((ob-soql-display-truncate-strings nil)
        (long-string (make-string 100 ?a)))
    (should (equal (ob-soql-core--truncate-string long-string 50)
                   long-string))))

;;; Tests for Metadata Building

(ert-deftest ob-soql-core-test-build-metadata ()
  "Test building metadata from query and CSV."
  (let* ((query "SELECT Id, Name FROM Account")
         (org "test-org")
         (org-url "https://test.salesforce.com")
         (csv "Id,Name\n001xxx,Acme\n001yyy,Wayne")
         (sobject "Account")
         (metadata (ob-soql--build-metadata query org org-url csv sobject)))
    
    ;; Check all metadata fields
    (should (equal (plist-get metadata :query) query))
    (should (equal (plist-get metadata :org) org))
    (should (equal (plist-get metadata :org-url) org-url))
    (should (equal (plist-get metadata :sobject) sobject))
    (should (equal (plist-get metadata :fields) '("Id" "Name")))
    (should (= (length (plist-get metadata :records)) 2))
    
    ;; Check first record
    (let ((first-record (car (plist-get metadata :records))))
      (should (equal (assoc-default "Id" first-record nil #'string=) "001xxx"))
      (should (equal (assoc-default "Name" first-record nil #'string=) "Acme")))))

(ert-deftest ob-soql-core-test-build-metadata-auto-sobject ()
  "Test building metadata with auto-detected SObject."
  (let* ((query "SELECT Id FROM Contact")
         (metadata (ob-soql--build-metadata query "org" "url" "Id\n001" nil)))
    
    ;; SObject should be auto-detected as Contact
    (should (equal (plist-get metadata :sobject) "Contact"))))

;;; Tests for Pending Updates Structure

(ert-deftest ob-soql-core-test-pending-updates-structure ()
  "Test the structure of pending updates."
  (let ((pending-updates '(("001xxx" . (("Name" . "New Name") ("Email" . "new@test.com")))
                           ("001yyy" . (("Status" . "Active"))))))
    
    ;; Test getting record updates
    (let ((record-updates (assoc-default "001xxx" pending-updates nil #'string=)))
      (should (equal (assoc-default "Name" record-updates nil #'string=) "New Name"))
      (should (equal (assoc-default "Email" record-updates nil #'string=) "new@test.com")))
    
    ;; Test getting single field update
    (let ((record-updates (assoc-default "001yyy" pending-updates nil #'string=)))
      (should (equal (assoc-default "Status" record-updates nil #'string=) "Active")))))

;;; Tests for Temp Buffer Macro

(ert-deftest ob-soql-core-test-with-temp-buffer ()
  "Test ob-soql-core--with-temp-buffer macro."
  (let ((result (ob-soql-core--with-temp-buffer
                 (insert "Test content")
                 (buffer-string))))
    (should (equal result "Test content"))))

(ert-deftest ob-soql-core-test-with-temp-buffer-cleanup ()
  "Test that temp buffer is cleaned up."
  (let ((buffer-count-before (length (buffer-list))))
    (ob-soql-core--with-temp-buffer
     (insert "test"))
    ;; Buffer count should be the same (buffer was cleaned up)
    (should (= (length (buffer-list)) buffer-count-before))))

;;; Tests for Buffer Modifications Macro

(ert-deftest ob-soql-core-test-buffer-modifications ()
  "Test ob-soql-core-buffer-modifications macro."
  (let ((test-buffer (generate-new-buffer "*test*")))
    (unwind-protect
        (progn
          (ob-soql-core-buffer-modifications
           :buffer test-buffer
           (insert "Test content"))
          
          (with-current-buffer test-buffer
            (should (equal (buffer-string) "Test content"))))
      (kill-buffer test-buffer))))

;;; Integration Tests

(ert-deftest ob-soql-core-test-full-workflow ()
  "Test complete workflow from CSV to metadata."
  (let* ((query "SELECT Id, Name, Email FROM Account LIMIT 2")
         (org "production")
         (org-url "https://prod.salesforce.com")
         (csv "Id,Name,Email\n001xxx,Acme Corp,acme@test.com\n001yyy,Wayne Inc,wayne@test.com")
         (metadata (ob-soql--build-metadata query org org-url csv nil)))
    
    ;; Verify complete metadata structure
    (should (plist-get metadata :query))
    (should (plist-get metadata :org))
    (should (plist-get metadata :org-url))
    (should (plist-get metadata :sobject))
    (should (plist-get metadata :fields))
    (should (plist-get metadata :records))
    
    ;; Verify SObject was extracted
    (should (equal (plist-get metadata :sobject) "Account"))
    
    ;; Verify fields
    (should (equal (plist-get metadata :fields) '("Id" "Name" "Email")))
    
    ;; Verify records
    (should (= (length (plist-get metadata :records)) 2))
    
    ;; Verify first record structure
    (let ((record (car (plist-get metadata :records))))
      (should (assoc-default "Id" record nil #'string=))
      (should (assoc-default "Name" record nil #'string=))
      (should (assoc-default "Email" record nil #'string=)))))

(provide 'ob-soql-core-test)
;;; ob-soql-core-test.el ends here
