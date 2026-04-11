;;; salesforce-table.el --- Table display for Salesforce data -*- lexical-binding: t -*-

;;; Commentary:
;; This package provides tablist-plus based table display components
;; for Salesforce data including test results and log files.

;;; Code:

(require 'tablist-plus)

;;; Test Result Table

(defclass salesforce-table-test-table (tablist-plus-table)
  ((class-covers
    :initarg :class-covers
    :initform nil
    :type (or sequence null)
    :documentation "List of class covered.")
   (unit-test-covers
    :initarg :unit-test-covers
    :initform nil
    :type (or hash-table null)
    :documentation "Hashtable of unit-test covered."))
  :documentation "Table list results of ran tests.")

(defclass salesforce-table-test-result (tablist-plus-data)
  ((unit-test
    :initarg :unit-test
    :initform ""
    :type string
    :documentation "Name of the test method.")
   (status
    :initarg :status
    :initform ""
    :type string
    :documentation "Test outcome status (Pass/Fail/Skip).")
   (class
    :initarg :class
    :initform ""
    :type string
    :documentation "Name of the Apex test class.")
   (stack-trace
    :initarg :stack-trace
    :initform nil
    :type (or string null)
    :documentation "Stack trace for failed tests.")
   (message
    :initarg :message
    :initform nil
    :type (or string null)
    :documentation "Error or assertion message."))
  "Represents a single Apex unit test result.

This class holds the outcome of running an Apex test method,
including pass/fail status and any error information.")

(cl-defmethod tablist-plus-data-to-entry ((result salesforce-table-test-result) key)
  "Transform RESULT to tabulated-list entry format with KEY as identifier."
  (list key
     (vector (slot-value result 'unit-test)
             (slot-value result 'status)
             (or (slot-value result 'message) "")
             (or (slot-value result 'stack-trace) ""))))

(defun salesforce-table-convert-test-result (test-result)
  "Convert TEST-RESULT JSON object to `salesforce-table-test-result' instance.

Returns a cons cell (ID . instance) for use with tablist-plus hash tables."
  (let ((id (map-nested-elt test-result '("Id")))
        (class (map-nested-elt test-result '("ApexClass" "Name")))
        (unit-test (map-nested-elt test-result '("MethodName")))
        (stack (map-nested-elt test-result '("StackTrace")))
        (message (map-nested-elt test-result '("Message")))
        (status (map-nested-elt test-result '("Outcome"))))
    (cons id
          (make-instance 'salesforce-table-test-result
                         :unit-test unit-test
                         :class class
                         :stack-trace stack
                         :message message
                         :status status))))

(defun salesforce-table-create-test-result (columns &rest args &key (buffer (generate-new-buffer "*salesforce-ran-tests*")) &allow-other-keys)
  "Create table for test results.

COLUMNS: table columns.
BUFFER: buffer name of table.
ARGS: optional args for tablist-table."
  (declare (indent 1))
  (let ((args (seq-difference args (list :buffer buffer))))
    (apply #'make-instance 'salesforce-table-test-table
           :columns columns
           :buffer buffer
           args)))

(defun salesforce-table-convert-test-results (test-results)
  "Convert TEST-RESULTS vector to list of `salesforce-table-test-result' instances."
  (cl-loop for test-result across test-results
           collect (salesforce-table-convert-test-result test-result)))

(defun salesforce-table--test-group-class ()
  "Return a grouping function for test entries by class name.

Used with tablist-plus to group test results by their parent Apex class."
  (lambda (table)
    (let ((data (tablist-plus-table-data table)))
      (seq-group-by
       (pcase-lambda (`(,key ,_))
         (slot-value (gethash key data) 'class))
       tabulated-list-entries))))

(defclass salesforce-table-coverage-result (tablist-plus-data)
  ((class
    :initarg :class
    :initform ""
    :type string
    :documentation "Name of the Apex class.")
   (lines
    :initarg :class
    :initform nil
    :type (or hash-table nil)
    :documentation "Lines of covered.")
   (total-lines
    :initarg :total-covered
    :initform 0
    :type number
    :documentation "Total lines of class.")
   (total-covered
    :initarg :total-covered
    :initform 0
    :type number
    :documentation "Total lines covered.")
   (percents
    :initarg :percents
    :initform 0
    :type number
    :documentation "Percent covered."))
  "Represent of covered class.")

(cl-defmethod tablist-plus-data-to-entry ((result salesforce-table-coverage-result) key)
  "Transform RESULT to tabulated-list entry format with KEY as identifier."
  (list key
     (vector (slot-value result 'class)
             (format "%s/%s"
                     (slot-value result 'total-covered)
                     (slot-value result 'total-lines))
             (slot-value result 'percents))))

(defun salesforce-table-convert-test-result (coverage-result)
  "Convert COVERAGE-RESULT JSON object to `salesforce-table-test-result' instance.

Returns a cons cell (ID . instance) for use with tablist-plus hash tables."
  (let ((id (map-nested-elt test-result '("Id")))
        (class (map-nested-elt test-result '("Name")))
        (lines (map-nested-elt test-result '("lines")))
        (total-covered (map-nested-elt test-result '("totalCovered")))
        (percents (map-nested-elt test-result '("coveredPercent"))))

    (cons id
          (make-instance 'salesforce-table-test-result
                         :class class
                         :lines lines
                         :total-covered total-covered
                         :percents percents))))

(defun salesforce-table-convert-coverage-results (coverage-results)
  "Convert COVERAGE-RESULTS vector to list of `salesforce-table-test-result' instances."
  (cl-loop for coverage-result across coverage-results
           collect (salesforce-table-convert-test-result coverage-result)))

(defun salesforce-table-create-coverage-result (columns &rest args &key (buffer (generate-new-buffer "*salesforce-coverage-tests*")) &allow-other-keys)
  "Create table for test results.

COLUMNS: table columns.
BUFFER: buffer name of table.
ARGS: optional args for tablist-table."
  (declare (indent 1))
  (let ((args (seq-difference args (list :buffer buffer))))
    (apply #'tablist-plus-create-table columns
           :buffer buffer
           args)))

;;; Log File Table

(defclass salesforce-table-log (tablist-plus-data)
  ((id
    :initarg :id
    :initform nil
    :type (or string null)
    :documentation "Unique identifier of the log file.")
   (app
    :initarg :app
    :initform nil
    :type (or string null)
    :documentation "Application that generated the log.")
   (time
    :initarg :time
    :initform nil
    :type (or string null)
    :documentation "Timestamp when the log was created.")
   (size
    :initarg :size
    :initform 0
    :type number
    :documentation "Size of the log file in bytes.")
   (status
    :initarg :status
    :initform nil
    :type (or string null)
    :documentation "Status of the log operation.")
   (operation
    :initarg :operation
    :initform nil
    :type (or string null)
    :documentation "Type of operation that generated the log."))
  "Represents an Apex debug log file entry.

This class holds metadata about a debug log stored in Salesforce,
used for displaying logs in a tabulated list.")

(cl-defmethod tablist-plus-data-to-entry ((log-file salesforce-table-log) key)
  "Transform LOG-FILE to tabulated-list entry format with KEY as identifier."
  (list key
     (vector (or (slot-value log-file 'app) "")
             (format "%d" (slot-value log-file 'size))
             (or (slot-value log-file 'status) "")
             (or (slot-value log-file 'operation) "")
             (if-let ((time-str (slot-value log-file 'time)))
                 (format-time-string display-time-string
                                     (parse-iso8601-time-string time-str))
               ""))))

(defun salesforce-table-convert-log-file (log-file)
  "Convert LOG-FILE JSON object to `salesforce-table-log' instance.

Returns a cons cell (ID . instance) for use with tablist-plus hash tables."
  (let ((id (map-nested-elt log-file '("Id")))
        (app (map-nested-elt log-file '("Application")))
        (time (map-nested-elt log-file '("StartTime")))
        (operation (map-nested-elt log-file '("Operation")))
        (status (map-nested-elt log-file '("Status")))
        (size (or (map-nested-elt log-file '("LogLength")) 0)))
    (cons id
          (make-instance 'salesforce-table-log
                         :id id
                         :app app
                         :size size
                         :time time
                         :status status
                         :operation operation))))

(provide 'salesforce-table)
;;; salesforce-table.el ends here
