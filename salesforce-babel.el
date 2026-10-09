;;; salesforce-babel.el --- Org babel integration -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(require 'org)

(defvar-local salesforce-babel-job-dict (make-hash-table :test #'eq)
  "Dictionary use for search job blocks.")

(defvar-local salesforce-babel-batch-dict (make-hash-table :test #'eq)
  "Dictionary use for search job blocks.")

(defclass salesforce-babel-batch ()
  ((id
    :initarg :id
    :initform nil
    :accessor salesforce-babel-batch-id
    :type (or null string)
    :documentation "Id of batch.")
   (jobs
    :initarg :jobs
    :initform nil
    :accessor salesforce-babel-batch-jobs
    :type (or null list)
    :documentation "List of source need to run.")
   (complete
    :initarg :complete
    :initform nil
    :accessor salesforce-babel-batch-complete
    :type (or null symbol function)
    :documentation "statement run on complete."))
  :documentation "Dispatch source of Salesforce code.")

(cl-defmethod salesforce-babel-batch-add-source ((obj salesforce-babel-batch) job)
  "Add source to Salesforce defined."
  (setf (salesforce-babel-batch-jobs obj)
        `(,@(salesforce-babel-batch-jobs obj)
          ,source)))

(cl-defmethod salesforce-babel-batch-dispatch (batch)
  "Dispatch Salesforce babel batch and show result on `org-mode'."
  (apply #'emacs-pp-jobs-sequence
         :complete (salesforce-babel-batch-complete batch)
         (salesforce-babel-batch-jobs batch)))

(defun salesforce-babel-batch-dictionary-put (batch)
  "Get batch from dictionary."
  (puthash (salesforce-babel-batch-id batch) batch salesforce-babel-batch-dict))

(defun salesforce-babel-batch-dictionary-get (batch-id)
  "Get batch from dictionary."
  (gethash batch-id salesforce-babel-batch-dict))

(cl-defun salesforce-babel-job-dictionary-put (job-id &key (batch-id (emacs-pp--gen-batch-id)))
  "Push job to batch dictionary."
  (declare (indent 1))
  (if-let ((batch (salesforce-babel-batch-dictionary-get batch-id)))
      (salesforce-babel-batch-add-source batch job-id)
    (salesforce-babel-batch-dictionary-put
     (make-instance 'salesforce-babel-batch
                    :id batch-id
                    :jobs (list job-id))))
  (puthash job-id batch-id salesforce-babel-job-dict))

(defun salesforce-babel-job-dictionary-get (job-id)
  "Get job in batch dictionary."
  (gethash job-id salesforce-babel-job-dict))

(defun emacs-pp--gen-batch-id ()
  "Generate unique pipeline ID from timestamp."
  (pcase-let* ((now (current-time))
               (`(_ _ ,usec) now)
               (decoded (decode-time now))
               (`(,second ,minute ,hour ,day ,month ,year . ,_) decoded))
    (format "salesforce-babel-batch-%04d%02d%02d-%02d%02d%02d-%06d"
            year month day hour minute second usec)))

(cl-defun salesforce-babel--expand-apex-vars (vars)
  "Expand apex BODY with variable in VARS."
  (cl-loop for var in vars
           as var-name = (car var)
           as expanded-var = (salesforce-babel--expand-apex-var var)
           concat expanded-var))

(defun salesforce-babel--get-apex-type (type)
  "Get Apex type string for TYPE."
  (pcase type
    ("string" "String")
    ("number" "Integer")
    ("boolean" "Boolean")
    (_ "Object")))

(defun salesforce-babel--expand-apex-var (pair)
  "Generate Apex variable declaration code from PAIR.
PAIR is a cons cell of (variable-name . value)."
  (format "Object %s = %s;" key value))

(defun salesforce-babel--infer-type (value)
  "Infer the type of VALUE for Apex variable declaration."
  (cond
   ((string-match-p "^'" value) "string")
   ((string-match-p "^[0-9]+\\(?:\\.[0-9]+\\)?$" value) "number")
   ((string-match-p "^\\(?:[Tt]rue\\|[Ff]alse\\)$" value) "boolean")
   (t "object")))

(defun salesforce-babel--format-value (type value)
  "Format VALUE based on its TYPE for Apex variable declaration."
  (pcase type
    ("string" (format "'%s'" (string-trim value "'" "'")))
    ("number" value)
    ("boolean" value)
    (_ (format "new %s()" value))))

(defun salesforce-babel-get-vars (params)
  "Get vars from source PARAMS."
  (org-babel--get-vars
   (org-babel-process-params params)))

(defun salesforce-babel-job-p (thing)
  "Return t if thing is `emacs-pp-job'"
  (string-prefix-p "emacs-pp-process" thing))

;; ── SOQL core process ──────────────────────────────────────────────────────

(defun salesforce-babel--soql-result-p (data)
  "Return non-nil if DATA is a SOQL tabular result (list of lists)."
  (and (listp data) (consp data) (listp (car data))))

(defun salesforce-babel--soql-result-to-apex-value (data &optional field)
  "Convert SOQL tabular DATA to an Apex List<String> literal.
FIELD is the column name to extract (default: first column)."
  (let* ((header (car data))
         (rows (cdr data))
         (col-idx (if field
                      (or (seq-position header field #'string-match-p) 0)
                    0))
         (values (mapcar (lambda (row)
                           (format "'%s'" (elt row col-idx)))
                         rows)))
    (concat "new List<String>{"
            (string-join values ",")
            "}")))

(defun salesforce-babel--soql-object-field (var)
  "Get field of VAR to bind, default use Id.
E.g., `ids.Id' → \"Id\"; `ids' → \"Id\"."
  (let* ((var (format "%s" var))
         (fields (cdr (split-string var "\\."))))
    (string-join (or fields (list "Id")) ".")))

(defun salesforce-babel--soql-format-resolved-value (data field)
  "Format already-resolved DATA as a SOQL value using FIELD column if tabular.
DATA is a resolved value (not a job-id): a SOQL result list, string, or number."
  (cond
   ((salesforce-babel--soql-result-p data)
    (let* ((header (car data))
           (rows (cdr data))
           (col-idx (or (seq-position header field #'string-match-p) 0))
           (values (mapcar (lambda (row) (format "'%s'" (elt row col-idx))) rows)))
      (concat "(" (string-join values ",") ")")))
   ((and (stringp data) (or (string-prefix-p "'" data) (string-prefix-p "\"" data)))
    (format "'%s'" (replace-regexp-in-string "'\\|\"" "" data)))
   ((numberp data) (format "%s" data))
   (t (format "'%s'" (or data "")))))

(defun salesforce-babel--bind-soql-vars (params job-results)
  "Resolve vars from PARAMS using JOB-RESULTS; format as SOQL values.
Separate from `salesforce-babel-bind-job-results' (Apex path) to avoid
Apex-formatted output in SOQL substitution."
  (cl-loop for (var-name . value) in (salesforce-babel-get-vars params)
           as data = (pcase value
                       ((pred salesforce-babel-job-p)
                        (gethash value job-results))
                       (_ value))
           as field = (salesforce-babel--soql-object-field var-name)
           as bare-name = (car (split-string (format "%s" var-name) "\\."))
           as soql-value = (salesforce-babel--soql-format-resolved-value data field)
           collect (cons bare-name soql-value)))

(defun salesforce-babel--expand-soql-vars (vars soql)
  "Replace :VAR placeholders in SOQL with pre-formatted values from VARS."
  (cl-loop for (var . value) in vars
           do (setq soql (string-replace (format ":%s" var) value soql))
           finally return soql))

(cl-defun salesforce-babel--sanitizer-value (value &optional field)
  "Transform VALUE to valid Apex input.
When VALUE is a SOQL tabular result, converts using FIELD column."
  (if (salesforce-babel--soql-result-p value)
      (salesforce-babel--soql-result-to-apex-value value field)
    (let* ((type (salesforce-babel--infer-type value)))
      (salesforce-babel--format-value type value))))

(defun salesforce-babel-bind-job-results (params job-results)
  "Expand source PARAMS with JOB-RESULT, extracting field from var name.
Supports `ids.Id' syntax: bare-name becomes the var, Id becomes the field."
  (cl-loop for (var-name . value) in (salesforce-babel-get-vars params)
           as data = (pcase value
                       ((pred salesforce-babel-job-p)
                        (gethash value job-results))
                       (_ value))
           as field = (salesforce-babel--soql-object-field var-name)
           as bare-name = (car (split-string (format "%s" var-name) "\\."))
           as sanitizer-value = (salesforce-babel--sanitizer-value data field)
           collect (cons bare-name sanitizer-value)))

(cl-defun salesforce-babel-expand-body (body params &key (type 'apex) job-results)
  "Expand BODY with binding PARAMS.
TYPE is `apex' (default) or `soql'.  JOB-RESULTS is the pipeline hash."
  (pcase type
    ('apex
     (let ((vars (salesforce-babel-bind-job-results params job-results)))
       (concat (salesforce-babel--expand-apex-vars vars) body)))
    ('soql
     (let ((vars (salesforce-babel--bind-soql-vars params job-results)))
       (salesforce-babel--expand-soql-vars vars body)))))

(defun salesforce-babel-make-job (&rest body)
  "Expand form BODY to sequence job."
  (apply #'emacs-pp-job
         :ready-p nil
         body))

(provide 'salesforce-babel)
;;; salesforce-babel.el ends here
