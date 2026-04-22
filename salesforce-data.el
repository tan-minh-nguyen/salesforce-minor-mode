;;; salesforce-data.el --- Import/export data on org -*- lexical-binding: t -*-

;;; Commentary:
;; This package provides data import/export functionality for Salesforce,
;; including SOQL/SOSL queries, bulk operations, and org-mode table integration.

;;; Code:

(require 'salesforce-core)
(require 'salesforce-menu)

;;; Customization

(defcustom salesforce-data-wait-value 10
  "Default value for --await argument."
  :type 'number
  :group 'salesforce-data)

;;; Variables

(defvar-local salesforce-data--file ""
  "Default file use in -f argument.")

(defvar-local salesforce-data--sobject-value ""
  "Default value use in --sobject argument.")

;;; Transient Menu Definitions - Main Menus

;;;###autoload
(transient-define-prefix salesforce-data--transient:data ()
  "Menu configuration sf data export bulk command."
  ["Export"
   ("b" "Bulk" salesforce-data--transient:export-bulk)
   ("t" "Tree" salesforce-data--transient:export-tree)
   ("r" "Resume" salesforce-data--transient:export-resume)]
  ["Import"
   ("B" "Bulk" salesforce-data--transient:import-bulk)])

(transient-define-prefix salesforce-data--transient:data-search ()
  "Menu configuration sf data query command."
  ["Arguments"
   [""
    (salesforce-data--transient:-f)
    (salesforce-data--transient:-q)
    (salesforce-data--transient:--async)
    (salesforce-data--transient:--all-rows)]
   [""
    (salesforce-data--transient:-r)
    (salesforce-data--transient:--use-tooling-api)
    (salesforce--menu:-o)
    (salesforce--menu:--api-version)]]
  [""
   ("RET" "Execute SOQL" salesforce-data-query)])

;;; Transient Menu Definitions - Import Menus

(transient-define-prefix salesforce-data--transient:import-bulk ()
  "Menu configuration import bulk."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (salesforce--menu:-o)
    (salesforce--menu:--api-version)
    (salesforce-data--transient:--sobject)
    (salesforce-data--transient:-f)]
   [""
    (salesforce-data--transient:-w)
    (salesforce-data--transient:--column-delimiter)
    (salesforce-data--transient:--line-ending)]]
  [""
   ("RET" "Import bulk" salesforce-data-import-bulk)])

(transient-define-prefix salesforce-data--transient:import-tree ()
  "Menu configuration import tree."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (salesforce--menu:-o)
    (salesforce--menu:--api-version)
    (salesforce-data--transient:-p)
    (salesforce-data--transient:-f)]]
  [""
   ("RET" "Import tree" salesforce-data-import-tree)])

(transient-define-prefix salesforce-data--transient:import-resume ()
  "Menu configuration import resume."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (salesforce-data--transient:-i)
    (salesforce--transient-menu:--api-version)
    (salesforce-data--transient:--use-most-recent)
    (salesforce-data--transient:-w)]]
  [""
   ("RET" "Import resume" salesforce-data--import-resume)])

;;; Transient Menu Definitions - Export Menus

(transient-define-prefix salesforce-data--transient:export-bulk ()
  "Menu configuration export bulk."
  :incompatible '(("--wait" "--async") ("--query-file" "--query"))
  ["Arguments"
   [""
    (salesforce--menu:-o)
    (salesforce--menu:--api-version)
    (salesforce-data--transient:--query-file)
    (salesforce-data--transient:-q)
    (salesforce-data--transient:--async)
    (salesforce-data--transient:--output-file)]
   [""
    (salesforce-data--transient:--column-delimiter)
    (salesforce-data--transient:--line-ending)
    (salesforce-data--transient:--all-rows)]]
  [""
   ("RET" "Export bulk" salesforce-data--export-bulk)])

(transient-define-prefix salesforce-data--transient:export-tree ()
  "Menu configuration export tree."
  ["Arguments"
   [""
    (salesforce--menu:-o)
    (salesforce--menu:--api-version)
    (salesforce-data--transient:-q)]
   [""
    (salesforce-data--transient:-x)
    (salesforce-data--transient:-p)
    (salesforce--menu:-d)]]
  [""
   ("RET" "Export tree" salesforce-data--export-tree)])

(transient-define-prefix salesforce-data--transient:export-resume ()
  "Menu configuration export resume."
  ["Arguments"
   [""
    (salesforce--menu:-o)
    (salesforce--menu:--api-version)
    (salesforce-data--transient:-i)
    (salesforce-data--transient:--use-most-recent)]]
  [""
   ("RET" "Export resume" salesforce-data-export-resume)])

;;; Transient Menu Definitions - Arguments

(transient-define-argument salesforce-data--transient:-f ()
  :class 'transient-option
  :always-read t
  :description "File path"
  :key "-f"
  :shortarg "-f"
  :argument "--file="
  :reader #'salesforce-data--transient:-f-reader
  :init-value #'salesforce-data--export-file-handler)

(transient-define-argument salesforce-data--transient:--sobject ()
  :class 'transient-option
  :always-read t
  :description "SObject type"
  :key "-s"
  :shortarg "-s"
  :argument "--sobject="
  :reader #'salesforce-data--transient:--sobject-reader
  :init-value #'salesforce-data--sobject-handler)

(transient-define-argument salesforce-data--transient:-w ()
  :class 'transient-option
  :always-read t
  :description "Wait time"
  :key "-w"
  :shortarg "-w"
  :argument "--wait="
  :reader #'salesforce-data--transient:--wait-reader
  :init-value #'salesforce-data--wait-handler)

(transient-define-argument salesforce-data--transient:-i ()
  :class 'transient-option
  :description "Job ID"
  :key "-i"
  :shortarg "-i"
  :argument "--job-id="
  :reader #'salesforce--menu:read-file)

(transient-define-argument salesforce-data--transient:--use-most-recent ()
  :description "Use job id that was most recently run"
  :key "-r"
  :shortarg "-r"
  :argument "--use-most-recent")

(transient-define-argument salesforce-data--transient:--query-file ()
  :class 'transient-option
  :description "File contains SOQL"
  :key "-f"
  :shortarg "--query-file"
  :argument "--query-file=%s"
  :reader #'salesforce-data--transient:read-file)

(transient-define-argument salesforce-data--transient:-q ()
  :class 'transient-option
  :description "SOQL string"
  :key "-q"
  :shortarg "-q"
  :argument "--query="
  :reader #'salesforce-data--transient:-q-reader)

(transient-define-argument salesforce-data--transient:-p ()
  :description "Generate plan definition file"
  :key "-p"
  :shortarg "-p"
  :argument "--plan")

(transient-define-argument salesforce-data--transient:-x ()
  :class 'transient-option
  :description "Prefix of generated files"
  :key "-x"
  :shortarg "-x"
  :argument "--prefix="
  :reader #'salesforce-data--transient:-x-reader)

(transient-define-argument salesforce-data--transient:--use-tooling-api ()
  :description "Use tooling API"
  :shortarg "--use-tooling-api"
  :argument "--use-tooling-api")

(transient-define-argument salesforce-data--transient:--async ()
  :description "Run async job"
  :shortarg "--async"
  :argument "--async")

(transient-define-argument salesforce-data--transient:--output-file ()
  :class 'transient-option
  :description "File to save export result"
  :key "-F"
  :shortarg "--output-file"
  :argument "--output-file="
  :reader #'salesforce--menu:read-file)

(transient-define-argument salesforce-data--transient:-r ()
  :class 'transient-switches
  :description "Export format"
  :key "-r"
  :argument-format "--result-format=%s"
  :argument-regexp "\\(csv\\|json\\)"
  :choices '("csv" "json"))

(transient-define-argument salesforce-data--transient:--column-delimiter ()
  :class 'transient-switches
  :description "Column delimiter export"
  :key "-d"
  :argument-format "--column-delimiter=%s"
  :argument-regexp "\\(backquote\\|caret\\|comma\\|pipe\\|semicolon\\|tab\\)"
  :choices '("backquote" "caret" "comma" "pipe" "semicolon" "tab"))

(transient-define-argument salesforce-data--transient:--line-ending ()
  :class 'transient-switches
  :description "Line ending export"
  :key "-l"
  :argument-format "--line-ending=%s"
  :argument-regexp "\\(lf\\|crlf\\)"
  :choices '("lf" "crlf"))

(transient-define-argument salesforce-data--transient:--all-rows ()
  :description "All rows"
  :key "-a"
  :shortarg "--all-rows"
  :argument "--all-rows")

;;; Transient Menu Handlers

(defun salesforce-data--export-file-handler (obj)
  "Set default value for export --file parameter in OBJ."
  (transient-infix-set obj (format "%s" salesforce-data--file)))

(defun salesforce-data--wait-handler (obj)
  "Set default value for --wait parameter in OBJ."
  (transient-infix-set obj (format "%s" salesforce-data-wait-value)))

(defun salesforce-data--sobject-handler (obj)
  "Set default value for --sobject parameter in OBJ."
  (transient-infix-set obj (format "%s" salesforce-data--sobject-value)))

;;; Transient Menu Readers

(defun salesforce-data--transient:-q-reader (prompt initial-input history)
  "Read a SOQL string and return value.
PROMPT, INITIAL-INPUT, and HISTORY are standard minibuffer arguments."
  (salesforce--menu:read-string prompt initial-input history 
                                "Please enter a SOQL."))

(defun salesforce-data--transient:-x-reader (prompt initial-input history)
  "Read a prefix string and return value.
PROMPT, INITIAL-INPUT, and HISTORY are standard minibuffer arguments."
  (salesforce--menu:read-string prompt initial-input history 
                                "Please enter a prefix files name."))

(defun salesforce-data--transient:-f-reader (prompt initial-input history)
  "Read a file string and return value.
PROMPT, INITIAL-INPUT, and HISTORY are standard minibuffer arguments."
  (salesforce--menu:read-file prompt 
                              (or initial-input salesforce-data--file) 
                              history))

(defun salesforce-data--transient:--sobject-reader (prompt initial-input history)
  "Read a sobject string and return value.
PROMPT, INITIAL-INPUT, and HISTORY are standard minibuffer arguments."
  (salesforce--menu:read-string prompt initial-input history 
                                "Please enter a sobject."))

(defun salesforce-data--transient:--wait-reader (prompt initial-input history)
  "Read a wait time number and return value.
PROMPT, INITIAL-INPUT, and HISTORY are standard minibuffer arguments."
  (salesforce--menu:read-number prompt 
                                (or initial-input salesforce-data-wait-value) 
                                history 
                                "Please enter a number."))

;;; Data Operations - Delete

(cl-defun salesforce-data--delete-bulk (args &key callback)
  "Delete records in bulk from a file.
ARGS: Parameters passed to the process.
CALLBACK: Optional function called after success."
  (salesforce-core--data-process
   :args `("delete" "bulk" ,@args "--json")
   :callback callback))

;;; Data Operations - Export

(cl-defun salesforce-data--export-bulk (args &key callback)
  "Export bulk data from the current org.
ARGS: Parameters passed to the process.
CALLBACK: Optional function called after success."
  (interactive (list (transient-args 'salesforce-data--transient:export-bulk)))
  (salesforce-core--data-process
   :args `("export" "bulk" ,@args "--json")
   :callback callback))

(defun salesforce-data--export-tree (args)
  "Export tree data from the org.
ARGS is a list of parameters passed to the Salesforce CLI."
  (interactive (list (transient-args 'salesforce-data--transient:export-tree)))
  (salesforce-core--data-process
   :args `("export" "tree" ,@args "--json")
   :callback (lambda (json-instance)
               (message "%s" json-instance))))

(defun salesforce-data-export-resume (args)
  "Resume a previously interrupted export.
ARGS is a list of parameters passed to the Salesforce CLI."
  (interactive (list (transient-args 'salesforce-data--transient:export-resume)))
  (salesforce-core--data-process
   :args `("export" "resume" ,@args "--json")
   :callback (lambda (json-instance)
               (message "%s" json-instance))))

;;; Data Operations - Import

(defun salesforce-data--format-import-status (json-instance)
  "Format import status message from JSON-INSTANCE."
  (format "Import status:\nSuccessful Records: %s\nFailed Records: %s"
          (or (map-nested-elt json-instance '("result" "successfulRecords")) 0)
          (or (map-nested-elt json-instance '("result" "failedRecords")) 0)))

(defun salesforce-data-import-bulk (args &optional sync)
  "Import bulk data into the org.
ARGS is a list of parameters passed to the Salesforce CLI.
SYNC run process as sync."
  (interactive (list (transient-args 'salesforce-data--transient:import-bulk)))
  (salesforce-core--data-process
   :args `("import" "bulk" ,@args "--json")
   :sync sync
   :callback (lambda (json-instance)
               (salesforce-core--alert (salesforce-data--format-import-status json-instance)))))

(defun salesforce-data-import-tree (args)
  "Import tree data into the org.
ARGS is a list of parameters passed to the Salesforce CLI."
  (interactive (list (transient-args 'salesforce-data--transient:import-tree)))
  (salesforce-core--data-process
   :args `("import" "tree" ,@args "--json")
   :callback (lambda (json-instance)
               (salesforce-core--alert (salesforce-data--format-import-status json-instance)))))

(defun salesforce-data-import-from-url (url sobject)
  "Import SOBJECT data from the specified URL."
  (interactive (list (read-string "URL: ")
                     (read-string "SObject: ")))
  (let ((file (make-temp-file "salesforce-import-data"))
        (org-name (salesforce-project-org salesforce-project-session)))
    ;; Step 1: Download data from URL
    (request url
      :parser 'buffer-string
      :success
      (cl-function
       (lambda (&key data &allow-other-keys)
         (when data
           (write-region data nil file)
           ;; Step 2: Import the downloaded data
           (salesforce-core--data-process
            :args (list "import" "bulk"
                        "-f" file
                        "-o" org-name
                        "-s" sobject
                        "--json")
            :callback
            (lambda (json-instance)
              (let ((jobid (map-nested-elt json-instance '("result" "jobId"))))
                (if jobid
                    ;; Schedule periodic resume processing
                    (let ((poll-id nil))
                      (setq poll-id
                            (run-at-time
                             10 t
                             (lambda ()
                               (salesforce-core--data-process
                                :args `("export" "resume" "--json" "-i" ,jobid)
                                :callback
                                (lambda (_)
                                  (salesforce-core--alert "Import process resumed successfully.")
                                  (cancel-timer poll-id))))))
                      (salesforce-core--alert "Import data is running."))
                  (salesforce-core--alert "Data import failed"))))))))
      :error
      (cl-function
       (lambda (&key error-thrown &allow-other-keys)
         (salesforce-core--alert (format "Request failed: %s" error-thrown)
                                 :severity 'urgent))))))

;;; Query and Search Operations

(defun salesforce-data--read-content ()
  "Read content that sf support for SOQL."
  (cond ((use-region-p)
         (replace-regexp-in-string 
          "//.*\n" "" 
          (buffer-substring-no-properties (use-region-beginning)
                                          (use-region-end))))
        (t (minibuffer-with-setup-hook 
               (apply-partially #'soql-ts-mode-minibuffer)
             (read-from-minibuffer "Query: ")))))

(defun salesforce-data--build-query-args (input)
  "Build query arguments from INPUT.
INPUT can be either a file path or a query string."
  (if (f-file-p input)
      `("-f" ,(expand-file-name input))
    `("-q" ,input)))

(defun salesforce-data-query (args)
  "Execute SOQL statement.
ARGS: Parameters are passed to the search record process."
  (interactive (list (or (transient-args 'salesforce-data--transient:data-search)
                     (salesforce-data--read-content))))

  (apply #'salesforce-data--dispatch-search
         `("query" ,@(salesforce-data--build-query-args args))))

(cl-defun salesforce-data--search-build (pattern &key (sobjects '("Account")) (fields '("Name")))
  "Build search PATTERN."
  (declare (indent 1))
  ;;TODO: add set default fields and object
  (format "FIND {%s} IN %s Fields RETURNING %s"
          pattern
          (string-join fields ",")
          (string-join sobjects ",")))

(defun salesforce-data--consult-input-transform (input)
  "Transform INPUT to (text . opts) to easy retrieve.
opts use format (:key . value)"
  (let* ((input-split (consult--command-split input))
         (str (car input-split)))

    (cons str
          (cl-loop for (flag value) on (cdr input-split) by #'cddr
                   with opts = nil
                   as key = (intern (replace-regexp-in-string "^[-]+" ":" flag))
                   as save-opt = (alist-get key opts)
                   if save-opt
                   do (setf (alist-get key opts) `(,@save-opt ,value))
                   else do (push (cons key (list value)) opts)
                   finally return opts))))

(defun salesforce-data--consult-async-search ()
  "Async search function use SOSL to find records.

Can pass parameters to search input:
-fields use for searching field.
-sobject use for searching sobject."
  (lambda (sink)
    (lambda (action)
      (pcase action
        ((pred stringp)
         (pcase-let* ((`(,search . ,args) (salesforce-data--consult-input-transform action))
                      (search-fields (assoc-default :fields args))
                      (org (or (car (assoc-default :org args))
                              (salesforce-project-org salesforce-project-session)))
                      (search-sobjects (assoc-default :sobject args)))
           (emacs-pp-job
            (lambda ()
              (let ((search-clause
                     (apply #'salesforce-data--search-build search
                            `(,@(when search-fields (list :fields search-fields))
                              ,@(when search-sobjects (list :sobjects search-sobjects)))))
                    (temp-file (make-temp-file "sosl")))

                (write-region search-clause nil temp-file)

                (apply #'salesforce-data--dispatch-search
                       (list "search" "-f" temp-file "--result-format=json" "-o" org))))
            (lambda (data)
              (let ((items (cl-loop for item across (map-nested-elt data '("searchRecords"))
                                    collect (propertize (gethash "Id" item) 'data item))))
                (funcall sink items)))))
         nil)
        ((or 'cancel 'destroy)
         ;;TODO: add feat abort pipeline
         )
        (_ (funcall sink action))))))

(cl-defun salesforce-data-search ()
  "Execute SOSL statement with SEARCH-STRING."
  (interactive)

  (consult--read (consult--async-pipeline
                  (consult--async-min-input 3)
                  (consult--async-throttle nil 0.5)
                  (salesforce-data--consult-async-search))
                 :prompt "Pattern: "
                 :annotate
                 (lambda (cand)
                   (let ((data (get-text-property 0 'data cand)))
                     (list cand "" (concat "\t" (propertize (map-nested-elt data '("attributes" "type")) 'face 'font-lock-keyword-face)))))
                 :category 'salesforce-search
                 :history 'salesforce-data-track-records))

(defun salesforce-data--ensure-result-format (commands)
  "Ensure COMMANDS includes a result format argument."
  (unless (cl-some (lambda (arg)
                     (or (string-prefix-p "-r" arg)
                        (string-prefix-p "--result-format" arg)))
                   commands)
    (append commands '("--result-format=csv")))
  commands)

(cl-defun salesforce-data--dispatch-search
    (&rest args &key (parser #'salesforce-core--parse-json) callback &allow-other-keys)
  "Search records on the connecting Salesforce org.
ARGS: Parameters used to build the command.
CALLBACK: Function to run after search succeeded.
SYNC: Run the process in sync."
  (let ((args (seq-difference args (list :callback callback :parser parser))))
    (salesforce-core--data-process
     :args (salesforce-data--ensure-result-format args)
     :parser parser
     :callback callback)))

;;; Entity Search

(defun salesforce-data-search-entity ()
  "Search entity definition on org."
  (interactive)
  (consult--read
   (consult--async-dynamic
    (lambda (input &rest args)
      (let* ((query (format "SELECT Id, Label, DeveloperName, IsApexTriggerable, IsWorkflowEnabled, IsProcessEnabled FROM EntityDefinition WHERE DeveloperName LIKE '%%%s%%'" 
                            input)))
        (salesforce-data--dispatch-search
         "query" "-q" query "--json"
         :callback
         (lambda (json-instance)
           (let* ((collection (map-nested-elt json-instance '("result" "records")))
                  (candidates (mapcar 
                               (lambda (item)
                                 (cons (map-elt item "Id")
                                       `("label" ,(map-elt item "Label")
                                         "name" ,(map-elt item "DeveloperName")
                                         "enabled-trigger" ,(map-elt item "IsApexTriggerable")
                                         "enabled-workflow" ,(map-elt item "IsWorkflowEnabled")
                                         "enabled-process" ,(map-elt item "IsProcessEnabled"))))
                               collection)))
             (funcall (plist-get args :callback) candidates)))))))
   :prompt "Entity: "
   :require-match t
   :category 'salesforce-records
   :annotate (lambda (candidate)
               (let* ((data (cdr candidate))
                      (label (map-elt data "label"))
                      (name (map-elt data "name"))
                      (trigger (map-elt data "enabled-trigger"))
                      (flow (map-elt data "enabled-workflow"))
                      (process (map-elt data "enabled-process"))
                      (prefix (nerd-icons-octicon "nf-oct-tools"))
                      (suffix (propertize name 'face 'font-lock-keyword-face)))
                 `(,label ,prefix ,suffix)))
   :lookup (lambda (candidate)
             (car candidate))))

;;; Query Builder
(cl-defstruct salesforce-data-soql-builder
  "SOQL builder."
  (select :type list :documentation "name for select fields.")
  (from :type string :documentation "sobject name.")
  (where :type string :documentation "filter conditions.")
  (order-by :type string :documentation "sort order.") group-by having)

;;; Org-mode Integration

;;;###autoload
(defun salesforce-data-org-table-export (file export-format)
  "Export data from org table to FILE using EXPORT-FORMAT."
  (interactive (list (org-entry-get (point) "TABLE_EXPORT_FILE" t)
                  (org-entry-get (point) "TABLE_EXPORT_FORMAT" t)))
  (unless (org-at-table-p) 
    (error "No table at point"))
  (unless file 
    (error "Missing file name"))
  (unless export-format 
    (error "Missing file format"))
  (org-table-export file export-format))

;;;###autoload
(defun salesforce-data-org-table-import (&optional sobject-name org-name)
  "Import data from org table.
Optional SOBJECT-NAME and ORG-NAME can be provided."
  (interactive)
  (unless (org-at-table-p)
    (error "No table at point"))
  (let* ((salesforce-data--file (make-temp-file "export"))
         (salesforce-data--sobject-value (org-entry-get (point) "SALESFORCE_SOBJECT_NAME" t))
         (property-org-name (org-entry-get (point) "SALESFORCE_ORG_NAME" t)))
    ;; Use org property if specified, otherwise use session org
    (when (and property-org-name salesforce-project-session)
      (setf (salesforce-project-org salesforce-project-session) property-org-name))
    (org-table-export salesforce-data--file "orgtbl-to-csv")
    (salesforce-data--transient:import-bulk)))

;;; Test Result Handling
(provide 'salesforce-data)

;;; salesforce-data.el ends here
