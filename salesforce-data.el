;;; salesforce-data.el --- Import/export data on org -*- lexical-binding: t -*-

(require 'salesforce-soql)
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
(transient-define-prefix salesforce-data--transient:data-query ()
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
   ("RET" "Execute SOQL" salesforce-data--execute-query)])

;; Import data
(transient-define-prefix salesforce-data--transient:import-bulk ()
  "Menu configuration import bulk."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (salesforce--transient-menu:-o)
    (salesforce-core--transient-menu:--api-version)
    (salesforce-data--transient:--sobject)
    ;;(salesforce-data--transient:--async)
    (salesforce-data--transient:-f)]
   [""
    (salesforce-data--transient:-w)
    (salesforce-data--transient:--column-delimiter)
    (salesforce-data--transient:--line-ending)]]
  [""
   ("RET" "Import bulk" salesforce-data--import-bulk)])

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
   ("RET" "Import tree" salesforce-data--import-tree)])

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
   ("RET" "Export resume" salesforce-data--export-resume)])

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

(defun salesforce-data--export-bulk (args)
  "Export bulk data to org."
  (interactive (list (transient-args 'salesforce-data--transient:export-bulk)))
  (salesforce-core--data-process
   :cmd `("export" "bulk" ,@args "--json")
   (message "%s" json-instance)))

(defun salesforce-data--export-tree (args)
  "Export tree data to org."
  (interactive (list (transient-args 'salesforce-data--transient:export-tree)))
  (salesforce-core--data-process
   :cmd `("export" "tree" ,@args "--json")
   (message "%s" json-instance)))

(defun salesforce-data--export-resume (args)
  "Export tree data to org."
  (interactive (list (transient-args 'salesforce-data--transient:export-resume)))
  (salesforce-core--data-process
   :cmd `("export" "resume" ,@args "--json")
   (message "%s" json-instance)))

(defun salesforce-data--import-bulk (args)
  "Import bulk data to org."
  (interactive (list (transient-args 'salesforce-data--transient:import-bulk)))
  (salesforce-core--data-process
   :cmd `("import" "bulk" ,@args "--json")
   (alert (format "Import status:\nSuccessful Records:%s\nFailed Records:"
                  (or (salesforce-core--get-data-json "result.successfulRecords" json-instance) 0)
                  (or (salesforce-core--get-data-json "result.failedRecords" json-instance)) 0)
          :title "Salesforce alert")))

(defun salesforce-data--import-bulk (args)
  "Import tree data to org."
  (interactive (list (transient-args 'salesforce-data--transient:import-bulk)))
  (salesforce-core--data-process
   :cmd `("import" "bulk" ,@args "--json")
   (alert (format "Import status:\nSuccessful Records:%s\nFailed Records:"
                  (or (salesforce-core--get-data-json "result.successfulRecords" json-instance) 0)
                  (or (salesforce-core--get-data-json "result.failedRecords" json-instance)) 0)
          :title "Salesforce alert")))

(defun salesforce-data-link-import (url)
  "Import data from the specified URL."
  (interactive (list (read-string "URL: ")))
  (async-start `(lambda ()
                  (let ((default-directory ,(projectile-project-root)))
                    ;; Load required libraries
                    ,(async-inject-variables "\\`load-path\\'")
                    (require 'async nil t)
                    (require 'process nil t)
                    (require 'request nil t)

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
                      (let ((proc (apply #'salesforce-start-process nil
                                         `(
                                           ,salesforce-data-command-alias
                                           "import"
                                           "bulk"
                                           "--file"
                                           ,file
                                           "--target-org"
                                           ,salesforce-org-name
                                           "--json"))))
                        (async-wait proc)
                        (if (eq (process-exit-status proc) 1)
                            (list :status 1 :error (salesforce--async-when-done proc))
                          (list :status 0 :json-instance (salesforce-parse-buffer-json (process-buffer proc))))))))
               (lambda (result)
                 (if (eq (plist-get result :status) 0)
                     ;; Schedule periodic resume processing
                     (let ((poll-id (run-at-time 10 t
                                                 (lambda ()
                                                   (salesforce-core--data-process
                                                    :cmd `("export" "resume" "--json"
                                                           "-i" ,(salesforce-core--get-data-json "result.jobId" result))
                                                    (alert "Import process resumed successfully."
                                                           :title "SALESFORCE Alert")
                                                    ;; clear poll event
                                                    (cancel-timer poll-id))))))
                       (alert "Import data is running." :title "SALESFORCE Alert"))
                   ;; Handle import error
                   (alert (format "Data import failed: %s" (plist-get result :error)) :title "SALESFORCE Alert")))))

(cl-defun salesforce-data--execute-query (args &key callback sync)
  "Execute SOQL string/file in specific org."
  (salesforce-core--data-process
   :cmd (if (plistp args) args
          `("query" ,@(if (f-file-p args) `("-f" ,(expand-file-name args)) `("-q" ,args)) "-o" ,salesforce-org-name "--result-format=csv"))
   :sync sync
   ;; use for async  process only
   (if callback
       (funcall callback json-instance)
     (let ((soql-buffer (generate-new-buffer "*soql data results*")))
       (with-current-buffer soql-buffer
         (insert (with-current-buffer json-instance (buffer-string)))
         (csv-mode))
       (pop-to-buffer soql-buffer)))))

(defun salesforce-data-execute-query (query-string)
  "Execute SOQL statement."
  (interactive (list (or (transient-args 'salesforce-data--transient:data-query)
                      (salesforce-soql--read-content))))
  (let ((stream-query (replace-regexp-in-string "\/\/.+\n" "" query-string)))
    (salesforce-data--execute-query stream-query)))

;;;###autoload
(defun salesforce-data-org-table-import ()
  "Import data from org table."
  (interactive)
  (unless (org-at-table-p) (error "No table at point")) 
  (let ((salesforce-data-export-file-default (make-temp-file "export"))
        (salesforce-data--sobject-value (org-entry-get (point) "SALESFORCE_SOBJECT_NAME" t))
        (salesforce-org-name (org-entry-get (point) "SALESFORCE_ORG_NAME" t)))
    (org-table-export salesforce-data-export-file-default "orgtbl-to-csv")
    (salesforce-data--transient:import-bulk)))

(provide 'salesforce-data)
