;;; salesforce-data.el --- Import/export data on org -*- lexical-binding: t -*-

(require 'salesforce-core)
(require 'salesforce-transient-menu)

(defcustom salesforce-data-wait-value 10
  "Default value for --await argument."
  :type 'number
  :group 'salesforce-data)

(defcustom salesforce-data-export-file-default ""
  "Default file use in -f argument."
  :type 'string
  :group 'salesforce-data)

(defvar-local salesforce-data--sobject-value ""
  "Default value use in --sobject argument.")

;;;###autoload
(transient-define-prefix salesforce-data--transient:data ()
  "Menu configuration sf data export bulk command."
  ["Export"
   ("b" "Bulk" salesforce-data--transient:export-bulk)
   ("t" "Tree" salesforce-data--transient:export-tree)
   ("r" "Resume" salesforce-data--transient:export-resume)]
  ["Import"
   ("B" "Bulk" salesforce-data--transient:import-bulk)])

;; Query data
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

;; Import data
(transient-define-prefix salesforce-data--transient:import-bulk ()
  "Menu configuration import bulk."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (salesforce--transient-menu:-o)
    (salesforce--transient-menu:--api-version)
    (salesforce-data--transient:--sobject)
    ;;(salesforce-data--transient:--async)
    (salesforce-data--transient:-f)]
   [""
    (salesforce-data--transient:-w)
    (salesforce-data--transient:--column-delimiter)
    (salesforce-data--transient:--line-ending)]]
  [""
   ("RET" "Import bulk" salesforce-data-import-bulk)])

(transient-define-prefix salesforce-data--transient:import-tree ()
  "Menu configuration export tree."
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
  "Menu configuration export resume."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (salesforce-data--transient:-i)
    (salesforce--transient-menu:--api-version)
    (salesforce-data--transient:--use-most-recent)
    (salesforce-data--transient:-w)]]
  [""
   ("RET" "Import resume" salesforce-data--import-resume)])

;; Export data
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

(transient-define-argument salesforce-data--transient:-f ()
  :class 'transient-option
  :always-read nil 
  :description "File path"
  :key "-f"
  :shortarg "-f"
  :argument "--file="
  :reader #'salesforce-data--transient:-f-reader
  :init-value #'salesforce-data--export-file-handler)

(transient-define-argument salesforce-data--transient:--sobject ()
  :class 'transient-option
  :description "SObject type"
  :key "-s"
  :shortarg "-s"
  :argument "--sobject="
  :reader #'salesforce-data--transient:--sobject-reader
  :init-value #'salesforce-data--sobject-handler)

(transient-define-argument salesforce-data--transient:-w ()
  :class 'transient-option
  :description "Wait time"
  :key "-w"
  :shortarg "-w"
  :argument "--wait="
  :init-value #'salesforce-data--wait-handler)

(transient-define-argument salesforce-data--transient:-i ()
  :class 'transient-option
  :description "job id"
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
  :description "generate plan definition file"
  :key "-p"
  :shortarg "-p"
  :argument "--plan")

(transient-define-argument salesforce-data--transient:-x ()
  :class 'transient-option
  :description "prefix of generate files"
  :key "-x"
  :shortarg "-x"
  :argument "--prefix="
  :reader #'salesforce-data--transient:-x-reader)

(transient-define-argument salesforce-data--transient:--use-tooling-api ()
  :description "use tooling API"
  :shortarg "--use-tooling-api"
  :argument "--use-tooling-api")

(transient-define-argument salesforce-data--transient:--async ()
  :description "run async job"
  :shortarg "--async"
  :argument "--async")

(transient-define-argument salesforce-data--transient:--output-file ()
  :class 'transient-option
  :description "file save export result"
  :key "-F"
  :shortarg "--output-file"
  :argument "--output-file="
  :reader #'salesforce--transient-menu:read-file)

(transient-define-argument salesforce-data--transient:-r ()
  :class 'transient-switches
  :description "export format"
  :key "-r"
  :argument-format "--result-format=%s"
  :argument-regexp "\\(csv\\|json\\)"
  :choices '("csv" "json"))

(transient-define-argument salesforce-data--transient:--column-delimiter ()
  :class 'transient-switches
  :description "column delimiter export"
  :key "-d"
  :argument-format "--column-dilimiter=%s"
  :argument-regexp "\\(backquote\\|caret\\|comma\\|pipe\\|semicolon\\|tab\\)"
  :choices '("backquote" "caret" "comma" "pipe" "semicolon" "tab"))

(transient-define-argument salesforce-data--transient:--line-ending ()
  :class 'transient-switches
  :description "line ending export"
  :key "-l"
  :argument-format "--line-ending=%s"
  :argument-regexp "\\(lf\\|crlf\\)"
  :choices '("lf" "crlf"))

(transient-define-argument salesforce-data--transient:--all-rows ()
  :description "all rows"
  :key "-a"
  :shortarg "--all-rows"
  :argument "--all-rows")

(defun salesforce-data--export-file-handler (obj)
  "Set default value for export --file param."
  (transient-infix-set obj (format "%s" salesforce-data-export-file-default)))

(defun salesforce-data--wait-handler (obj)
  "Set default value for --wait param."
  (transient-infix-set obj (format "%s" salesforce-data-wait-value)))

(defun salesforce-data--sobject-handler (obj)
  "Set default value for --sobject param."
  (transient-infix-set obj (format "%s" salesforce-data--sobject-value)))

(defun salesforce-data--transient:-q-reader (prompt initial-input history)
  "Read a SOQL string return value."
  (salesforce--transient-menu:read-string prompt initial-input history "Please enter a SOQL."))

(defun salesforce-data--transient:-x-reader (prompt initial-input history)
  "Read a prefix string return value."
  (salesforce--transient-menu:read-string prompt initial-input history "Please enter a prefix files name."))

(defun salesforce-data--transient:-f-reader (prompt initial-input history)
  "Read a file string return value."
  (salesforce--transient-menu:read-file prompt (or initial-input salesforce-data--default-file) history))

(defun salesforce-data--transient:--sobject-reader (prompt initial-input history)
  "Read a sobject string return value."
  (salesforce--transient-menu:read-string prompt initial-input history "Please enter a sobject."))

(cl-defun salesforce-data--delete-bulk (args &key callback)
  "Delete records in bulk from a file.

- ARGS: Parameters passed to the process.
- CALLBACK: Optional function called after success."
  (salesforce-core--data-process
   :args `("delete" "bulk" ,@args "--json")
   (and callback (funcall callback json-instance))))

(cl-defun salesforce-data--export-bulk (args &key callback)
  "Export bulk data to the current org.

- ARGS: Parameters passed to the process.
- CALLBACK: Optional function called after success."
  (interactive (list (transient-args 'salesforce-data--transient:export-bulk)))
  (salesforce-core--data-process
   :args `("export" "bulk" ,@args "--json")
   (and callback (funcall callback json-instance))))

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

(defun salesforce-data-import-bulk (args)
  "Import bulk data into the org.

ARGS is a list of parameters passed to the Salesforce CLI."
  (interactive (list (transient-args 'salesforce-data--transient:import-bulk)))
  (salesforce-core--data-process
   :args `("import" "bulk" ,@args "--json")
   (salesforce-core--alert
    (format "Import status:\nSuccessful Records: %s\nFailed Records: %s"
            (or (salesforce-core--get-data-json "result.successfulRecords" json-instance) 0)
            (or (salesforce-core--get-data-json "result.failedRecords" json-instance) 0)))))

(defun salesforce-data-import-tree (args)
  "Import tree data into the org.

ARGS is a list of parameters passed to the Salesforce CLI."
  (interactive (list (transient-args 'salesforce-data--transient:import-bulk)))
  (salesforce-core--data-process
   :args `("import" "tree" ,@args "--json")
   (salesforce-core--alert
    (format "Import status:\nSuccessful Records: %s\nFailed Records: %s"
            (or (salesforce-core--get-data-json "result.successfulRecords" json-instance) 0)
            (or (salesforce-core--get-data-json "result.failedRecords" json-instance) 0)))))

(defun salesforce-data--read-content ()
  "Read content that sf support for SOQL."
  (cond ((use-region-p)
         (replace-regexp-in-string "\/\/.+\n" "" (buffer-substring-no-properties (use-region-beginning)
                                                                                 (use-region-end))))
        (t (minibuffer-with-setup-hook (apply-partially #'soql-ts-mode-minibuffer)
             (read-from-minibuffer "Query: ")))))

(defun salesforce-data-query (args)
  "Execute SOQL statement.

ARGS: Parameters are passed to the search record process."
  (interactive (list (or (transient-args 'salesforce-data--transient:data-search)
                     (salesforce-data--read-content))))
  (apply #'salesforce-data--dispatch-search
         `("query" ,@(if (f-file-p args)
                         `("-f" ,(expand-file-name args))
                       `("-q" ,args)))))

(defun salesforce-data-search (search-string)
  "Execute SOSL statement with SEARCH-STRING."
  (interactive (list (or (transient-args 'salesforce-data--transient:data-search)
                     (salesforce-data--read-content))))
  (apply #'salesforce-data--dispatch-search 
         `("search" ,@(if (f-file-p args)
                          `("-f" ,(expand-file-name args))
                        `("-q" ,args)))))

(cl-defun salesforce-data--dispatch-search
    (&rest args &key callback sync &allow-other-keys)
  "Search records on the connecting Salesforce org.

- ARGS: parameters use for build the command.
- CALLBACK: function run after search succeeded.
- SYNC: Run the process in sync."
  (let ((commands (seq-difference args (list :callback callback :sync sync))))
    (unless (member-if (lambda (arg)
                         (or (string-prefix-p "-r" arg)
                            (string-prefix-p "--result-format" arg)))
                       commands)
      (add-to-list commands "--result-format=csv" t))
    (salesforce-core--data-process
     :args commands
     :sync sync
     ;; use for async  process only
     (if callback
         (funcall callback json-instance)
       (let ((soql-buffer (generate-new-buffer "*search results*")))
         (with-current-buffer soql-buffer
           (insert (with-current-buffer json-instance (buffer-string)))
           (csv-mode))
         (pop-to-buffer soql-buffer))))))

(cl-defmacro salesforce-apex-get-result-test-job (&rest body &key job-id &allow-other-keys)
  "Get result tests"
  `(salesforce-core--apex-process
    :args '("get" "test" "-i" ,job-id "--json")
    (let ((result-tests
           (mapconcat (lambda (result-test)
                        (let ((stack-trace (gethash "StackTrace" result-test))
                              (outcome (gethash "Outcome" result-test))
                              (error-message (gethash "Message" result-test))
                              (method-name (gethash "MethodName" result-test))
                              (class-name-test (salesforce-core--get-data-json "ApexClass.Name" result-test)))

                          (format "Class: %s\nMethod: %s\nResult: %s\n%s"
                                  class-name-test
                                  method-name
                                  (cond ((equal error-message ':null)
                                         outcome)
                                        (error-message
                                         error-message))
                                  (cond ((equal stack-trace ':null)
                                         "")
                                        (stack-trace
                                         stack-trace)))))

                      (salesforce-core--get-data-json "result.tests" json-instance)
                      "\n")))
      (salesforce-core-alert result-tests)
      (and body ,@body))))

(defun salesforce-data-search-entity ()
  "Search entity definition on org."
  (consult--read
   (consult--async-dynamic
    (cl-function
     (lambda (input &rest args &key callback &allow-other-keys)
       (let ((query (format "SELECT Id, Label, DeveloperName, IsApexTriggerable, IsWorkflowEnabled, IsProcessEnabled FROM EntityDefinition WHERE DeveloperName LIKE '%%%s%%'" input))
             (opts (seq-difference args (:callback callback))))

         (salesforce-data--dispatch-search
          "query" "-q" ,query "--json"
          :callback
          (lambda (json-instace)
            (let* ((collection (salesforce-core--get-data-json "result.records"))
                   (candidates (mapcar (lambda (item)
                                         (cons (salesforce-core--get-data-json "Id")
                                               `(:label ,(salesforce-core--get-data-json "Label")
                                                        :name ,(salesforce-core--get-data-json "DeveloperName")
                                                        :enabled-trigger ,(salesforce-core--get-data-json "IsApexTriggerable")
                                                        :enabled-workflow ,(salesforce-core--get-data-json "IsWorkflowEnabled")
                                                        :enabled-process ,(salesforce-core--get-data-json "IsProcessEnabled "))))
                                       collection)))

              (callback candidates))))))))
   :prompt "Entity: "
   :required-match t
   :category 'salesforce-records
   :anonate (lambda (candidate)
              (pcase-let* ((`(:label ,label :name ,name :enabled-trigger ,trigger :enabled-worflow ,flow :enabled-process ,process) (cdr candidate))
                           (prefix (nerd-icons-octicon "nf-oct-tools"))
                           (suffix (propertize name 'face font-lock-keyword-face)))
                `(label
                  prefix
                  suffix)))
   :lookup (lambda (candidate)
             (car candidate))))

(defun salesforce-data-link-import (url)
  "Import data from the specified URL."
  (interactive (list (read-string "URL: ")))
  (async-start
   `(lambda ()
      (let ((default-directory ,(projectile-project-root)))
        ;; Load required libraries
        ,(async-inject-variables "\\`load-path\\'")
        (require 'async nil t)
        (require 'process nil t)
        (require 'request nil t)
        (require 'salesforce-core nil t)

        ;; Create temporary file for the imported data
        (let* ((file (make-temp-file "salesforce-import-data"))
               (request-done nil)
               (response-error nil))

          ;; Make the asynchronous HTTP request
          (request ,url
            :parser 'buffer-string
            :async t
            :success (cl-function
                      (lambda (&key data &allow-other-keys)
                        (when data
                          (write-region data nil file)
                          (setq request-done t))))
            :error (cl-function
                    (lambda (&key error-thrown &allow-other-keys)
                      (setq response-error error-thrown))))

          ;; Handle request error
          (when response-error
            (error "Request failed with error: %s" response-error))

          ;; Execute the import command
          (let ((proc (apply #'salesforce-core--data-process 
                             :args `("import"
                                     "bulk"
                                     "--file"
                                     ,file
                                     "--target-org"
                                     ,salesforce-org-name
                                     "--json")
                             :sync t)))
            (async-wait proc)
            (if (eq (process-exit-status proc) 1)
                (list :status 1 :error (salesforce--async-when-done proc))
              (list :status 0 :json-instance (salesforce-core-parse-buffer-json (process-buffer proc))))))))
   (lambda (result)
     (if (eq (plist-get result :status) 0)
         ;; Schedule periodic resume processing
         (let ((poll-id (run-at-time 10 t
                                     (lambda ()
                                       (salesforce-core--data-process
                                        :args `("export" "resume" "--json"
                                                "-i" ,(salesforce-core--get-data-json "result.jobId" result))
                                        (salesforce-core-alert "Import process resumed successfully.")
                                        ;; clear poll event
                                        (cancel-timer poll-id))))))
           (salesforce-core--alert "Import data is running."))
       ;; Handle import error
       (salesforce-core--alert (format "Data import failed: %s" (plist-get result :error)))))))


;;;###autoload
(defun salesforce-data-org-table-export (file export-format)
  "Import data from org table."
  (interactive (list (org-entry-get (point) "TABLE_EXPORT_FILE" t)
                  (org-entry-get (point) "TABLE_EXPORT_FORMAT" t)))
  (unless (org-at-table-p) (error "No table at point")) 
  (unless file (error "Missing file name"))
  (unless export-format (error "Missing file format"))
  (org-table-export file export-format))

;;;###autoload
(defun salesforce-data-org-table-import (&optional sobject-name org-name)
  "Import data from org table."
  (interactive)
  (unless (org-at-table-p) (error "No table at point")) 
  (let ((salesforce-data-export-file-default (make-temp-file "export"))
        (salesforce-data--sobject-value (org-entry-get (point) "SALESFORCE_SOBJECT_NAME" t))
        (salesforce-org-name (org-entry-get (point) "SALESFORCE_ORG_NAME" t)))
    (org-table-export salesforce-data-export-file-default "orgtbl-to-csv")
    (salesforce-data--transient:import-bulk)))

(provide 'salesforce-data)
