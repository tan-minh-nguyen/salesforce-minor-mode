;;; salesforce-data.el --- Import/export data on org -*- lexical-binding: t -*-

;;; Commentary:
;; This package provides data import/export functionality for Salesforce,
;; including SOQL/SOSL queries, bulk operations, and org-mode table integration.

;;; Code:

(require 'salesforce-core)
(require 'salesforce-transient-menu)

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
    (salesforce--transient-menu:-o)
    (salesforce--transient-menu:--api-version)]]
  [""
   ("RET" "Execute SOQL" salesforce-data-query)
   ("M-RET" "Execute SOSL" salesforce-data-search)])

;;; Transient Menu Definitions - Import Menus

(transient-define-prefix salesforce-data--transient:import-bulk ()
  "Menu configuration import bulk."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (salesforce--transient-menu:-o)
    (salesforce--transient-menu:--api-version)
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
    (salesforce--transient-menu:-o)
    (salesforce--transient-menu:--api-version)
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
    (salesforce--transient-menu:-o)
    (salesforce--transient-menu:--api-version)
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
    (salesforce--transient-menu:-o)
    (salesforce--transient-menu:--api-version)
    (salesforce-data--transient:-q)]
   [""
    (salesforce-data--transient:-x)
    (salesforce-data--transient:-p)
    (salesforce--transient-menu:-d)]]
  [""
   ("RET" "Export tree" salesforce-data--export-tree)])

(transient-define-prefix salesforce-data--transient:export-resume ()
  "Menu configuration export resume."
  ["Arguments"
   [""
    (salesforce--transient-menu:-o)
    (salesforce--transient-menu:--api-version)
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
  :reader #'salesforce--transient-menu:read-file)

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
  :reader #'salesforce--transient-menu:read-file)

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
  (salesforce--transient-menu:read-string prompt initial-input history 
                                          "Please enter a SOQL."))

(defun salesforce-data--transient:-x-reader (prompt initial-input history)
  "Read a prefix string and return value.
PROMPT, INITIAL-INPUT, and HISTORY are standard minibuffer arguments."
  (salesforce--transient-menu:read-string prompt initial-input history 
                                          "Please enter a prefix files name."))

(defun salesforce-data--transient:-f-reader (prompt initial-input history)
  "Read a file string and return value.
PROMPT, INITIAL-INPUT, and HISTORY are standard minibuffer arguments."
  (salesforce--transient-menu:read-file prompt 
                                        (or initial-input salesforce-data--file) 
                                        history))

(defun salesforce-data--transient:--sobject-reader (prompt initial-input history)
  "Read a sobject string and return value.
PROMPT, INITIAL-INPUT, and HISTORY are standard minibuffer arguments."
  (salesforce--transient-menu:read-string prompt initial-input history 
                                          "Please enter a sobject."))

(defun salesforce-data--transient:--wait-reader (prompt initial-input history)
  "Read a wait time number and return value.
PROMPT, INITIAL-INPUT, and HISTORY are standard minibuffer arguments."
  (salesforce--transient-menu:read-number prompt 
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
   (when callback (funcall callback json-instance))))

;;; Data Operations - Export

(cl-defun salesforce-data--export-bulk (args &key callback)
  "Export bulk data from the current org.
ARGS: Parameters passed to the process.
CALLBACK: Optional function called after success."
  (interactive (list (transient-args 'salesforce-data--transient:export-bulk)))
  (salesforce-core--data-process
   :args `("export" "bulk" ,@args "--json")
   (when callback (funcall callback json-instance))))

(defun salesforce-data--export-tree (args)
  "Export tree data from the org.
ARGS is a list of parameters passed to the Salesforce CLI."
  (interactive (list (transient-args 'salesforce-data--transient:export-tree)))
  (salesforce-core--data-process
   :args `("export" "tree" ,@args "--json")
   (message "%s" json-instance)))

(defun salesforce-data-export-resume (args)
  "Resume a previously interrupted export.
ARGS is a list of parameters passed to the Salesforce CLI."
  (interactive (list (transient-args 'salesforce-data--transient:export-resume)))
  (salesforce-core--data-process
   :args `("export" "resume" ,@args "--json")
   (message "%s" json-instance)))

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
   (salesforce-core--alert (salesforce-data--format-import-status json-instance))
   :sync sync))

(defun salesforce-data-import-tree (args)
  "Import tree data into the org.
ARGS is a list of parameters passed to the Salesforce CLI."
  (interactive (list (transient-args 'salesforce-data--transient:import-tree)))
  (salesforce-core--data-process
   :args `("import" "tree" ,@args "--json")
   (salesforce-core--alert (salesforce-data--format-import-status json-instance))))

(defun salesforce-data-import-from-url (url sobject)
  "Import SOBJECT data from the specified URL."
  (interactive (list (read-string "URL: ")
                     (read-string "SObject: ")))
  (async-start
   `(lambda ()
      (let ((default-directory ,(projectile-project-root)))
        ,(async-inject-variables "\\`load-path\\'")
        (require 'async nil :no-error)
        (require 'process nil :no-error)
        (require 'request nil :no-error)
        (require 'salesforce-core nil :no-error)

        (let* ((file (make-temp-file "salesforce-import-data"))
               response-error)

          ;; Make the HTTP request
          (request ,url
            :parser 'buffer-string
            :sync t
            :success
            (cl-function
             (lambda (&key data &allow-other-keys)
               (when data
                 (write-region data nil file))))
            :error
            (cl-function
             (lambda (&key error-thrown &allow-other-keys)
               (setq response-error error-thrown))))

          ;; Handle request error
          (when response-error
            (error "Request failed with error: %s" response-error))

          ;; Execute the import command
          (let ((async-debug t)
                (proc (salesforce-core--data-process 
                       :args (list "import" "bulk"
                                   "-f" file
                                   "-o" ,salesforce-org-name
                                   "-s" ,sobject
                                   "--json")
                       :sync t)))
            (async-wait proc)
            (let ((data (salesforce-core-parse-buffer-json (process-buffer proc))))
              (if (eq (map-elt data "status") 1)
                  (salesforce-core--async-when-done proc)
                (map-nested-elt data '("result" "jobId"))))))))
   (lambda (jobid)
     (if jobid
         ;; Schedule periodic resume processing
         (let ((poll-id nil))
           (setq poll-id 
                 (run-at-time 
                  10 t
                  (lambda ()
                    (salesforce-core--data-process
                     :args `("export" "resume" "--json" "-i" ,jobid)
                     (salesforce-core--alert "Import process resumed successfully.")
                     (cancel-timer poll-id)))))
           (salesforce-core--alert "Import data is running."))
       ;; Handle import error
       (salesforce-core--alert "Data import failed")))))

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

(defun salesforce-data-search (search-string)
  "Execute SOSL statement with SEARCH-STRING."
  (interactive (list (or (transient-args 'salesforce-data--transient:data-search)
                     (salesforce-data--read-content))))
  (apply #'salesforce-data--dispatch-search 
         `("search" ,@(salesforce-data--build-query-args search-string))))

(defun salesforce-data--ensure-result-format (commands)
  "Ensure COMMANDS includes a result format argument."
  (unless (cl-some (lambda (arg)
                     (or (string-prefix-p "-r" arg)
                         (string-prefix-p "--result-format" arg)))
                   commands)
    (append commands '("--result-format=csv")))
  commands)

(defun salesforce-data--display-search-results (json-instance)
  "Display search results from JSON-INSTANCE in a CSV buffer."
  (let ((soql-buffer (generate-new-buffer "*search results*")))
    (with-current-buffer soql-buffer
      (insert (with-current-buffer json-instance (buffer-string)))
      (csv-mode))
    (pop-to-buffer soql-buffer)))

(cl-defun salesforce-data--dispatch-search
    (&rest args &key callback sync &allow-other-keys)
  "Search records on the connecting Salesforce org.
ARGS: Parameters used to build the command.
CALLBACK: Function to run after search succeeded.
SYNC: Run the process in sync."
  (let ((commands (seq-difference args (list :callback callback :sync sync))))
    (setq commands (salesforce-data--ensure-result-format commands))
    (salesforce-core--data-process
     :args commands
     :sync sync
     (if callback
         (funcall callback json-instance)
       (salesforce-data--display-search-results json-instance)))))

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
  (let ((salesforce-data--file (make-temp-file "export"))
        (salesforce-data--sobject-value (org-entry-get (point) "SALESFORCE_SOBJECT_NAME" t))
        (salesforce-org-name (org-entry-get (point) "SALESFORCE_ORG_NAME" t)))
    (org-table-export salesforce-data--file "orgtbl-to-csv")
    (salesforce-data--transient:import-bulk)))

;;; Test Result Handling
(provide 'salesforce-data)

;;; salesforce-data.el ends here
