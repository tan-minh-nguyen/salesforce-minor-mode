;;; dx-data.el --- Import/export data on org -*- lexical-binding: t -*-

(require 'dx-soql)
(require 'dx-core)
(require 'dx-transient-menu)

(defcustom dx-data-wait-value 10
  "Default value for --await argument."
  :type 'number
  :group 'dx-data)

(defcustom dx-data-export-file-default ""
  "Default file use in -f argument."
  :type 'string
  :group 'dx-data)

(defvar-local dx-data--sobject-value ""
  "Default value use in --sobject argument.")

;;;###autoload
(transient-define-prefix dx-data--transient:data ()
  "Menu configuration sf data export bulk command."
  ["Export"
   ("b" "Bulk" dx-data--transient:export-bulk)
   ("t" "Tree" dx-data--transient:export-tree)
   ("r" "Resume" dx-data--transient:export-resume)]
  ["Import"
   ("B" "Bulk" dx-data--transient:import-bulk)])

;; Import data
(transient-define-prefix dx-data--transient:import-bulk ()
  "Menu configuration import bulk."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (dx--transient-menu:-o)
    (dx--transient-menu:--api-version)
    (dx-data--transient:--sobject)
    ;;(dx-data--transient:--async)
    (dx-data--transient:-f)]
   [""
    (dx-data--transient:-w)
    (dx-data--transient:--column-delimiter)
    (dx-data--transient:--line-ending)]]
  [""
   ("RET" "Import bulk" dx-data--import-bulk)])

(transient-define-prefix dx-data--transient:import-tree ()
  "Menu configuration export tree."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (dx--transient-menu:-o)
    (dx--transient-menu:--api-version)
    (dx-data--transient:-p)
    (dx-data--transient:-f)]]
  [""
   ("RET" "Import tree" dx-data--import-tree)])

(transient-define-prefix dx-data--transient:import-resume ()
  "Menu configuration export resume."
  :incompatible '(("--wait" "--async"))
  ["Arguments"
   [""
    (dx-data--transient:-i)
    (dx--transient-menu:--api-version)
    (dx-data--transient:--use-most-recent)
    (dx-data--transient:-w)]]
  [""
   ("RET" "Import resume" dx-data--import-resume)])

;; Export data
(transient-define-prefix dx-data--transient:export-bulk ()
  "Menu configuration export bulk."
  :incompatible '(("--wait" "--async") ("--query-file" "--query"))
  ["Arguments"
   [""
    (dx--transient-menu:-o)
    (dx--transient-menu:--api-version)
    (dx-data--transient:--query-file)
    (dx-data--transient:-q)
    (dx-data--transient:--async)
    (dx-data--transient:--output-file)]
   [""
    (dx-data--transient:--column-delimiter)
    (dx-data--transient:--line-ending)
    (dx-data--transient:--all-rows)]]
  [""
   ("RET" "Export bulk" dx-data--export-bulk)])
 
(transient-define-prefix dx-data--transient:export-tree ()
  "Menu configuration export tree."
  ["Arguments"
   [""
    (dx--transient-menu:-o)
    (dx--transient-menu:--api-version)
    (dx-data--transient:-q)]
   [""
    (dx-data--transient:-x)
    (dx-data--transient:-p)
    (dx--transient-menu:-d)]]
  [""
   ("RET" "Export tree" dx-data--export-tree)])

(transient-define-prefix dx-data--transient:export-resume ()
  "Menu configuration export resume."
  ["Arguments"
   [""
    (dx--transient-menu:-o)
    (dx--transient-menu:--api-version)
    (dx-data--transient:-i)
    (dx-data--transient:--use-most-recent)]]
  [""
   ("RET" "Export resume" dx-data--export-resume)])

(transient-define-argument dx-data--transient:-f ()
  :class 'transient-option
  :always-read nil 
  :description "File path"
  :key "-f"
  :shortarg "-f"
  :argument "--file="
  :reader #'dx-data--transient:-f-reader
  :init-value #'dx-data--export-file-handler)

(transient-define-argument dx-data--transient:--sobject ()
  :class 'transient-option
  :description "SObject type"
  :key "-s"
  :shortarg "-s"
  :argument "--sobject="
  :reader #'dx-data--transient:--sobject-reader
  :init-value #'dx-data--sobject-handler)

(transient-define-argument dx-data--transient:-w ()
  :class 'transient-option
  :description "Wait time"
  :key "-w"
  :shortarg "-w"
  :argument "--wait="
  :init-value #'dx-data--wait-handler)

(transient-define-argument dx-data--transient:-i ()
  :class 'transient-option
  :description "job id"
  :key "-i"
  :shortarg "-i"
  :argument "--job-id="
  :reader #'dx--transient-menu:read-file)

(transient-define-argument dx-data--transient:--use-most-recent ()
  :description "Use job id that was most recently run"
  :key "-r"
  :shortarg "-r"
  :argument "--use-most-recent")

(transient-define-argument dx-data--transient:--query-file ()
  :class 'transient-option
  :description "File contains SOQL"
  :key "-f"
  :shortarg "--query-file"
  :argument "--query-file=%s"
  :reader #'dx-data--transient:read-file)

(transient-define-argument dx-data--transient:-q ()
  :class 'transient-option
  :description "source export"
  :key "-q"
  :shortarg "-q"
  :argument "--query="
  :reader #'dx-data--transient:-q-reader)

(transient-define-argument dx-data--transient:-p ()
  :description "generate plan definition file"
  :key "-p"
  :shortarg "-p"
  :argument "--plan")

(transient-define-argument dx-data--transient:-x ()
  :class 'transient-option
  :description "prefix of generate files"
  :key "-x"
  :shortarg "-x"
  :argument "--prefix="
  :reader #'dx-data--transient:-x-reader)

(transient-define-argument dx-data--transient:--async ()
  :description "run async job"
  :shortarg "--async"
  :argument "--async")

(transient-define-argument dx-data--transient:--output-file ()
  :class 'transient-option
  :description "file save export result"
  :key "-F"
  :shortarg "--output-file"
  :argument "--output-file="
  :reader #'dx--transient-menu:read-file)

(transient-define-argument dx-data--transient:-r ()
  :class 'transient-switches
  :description "export format"
  :key "-r"
  :argument-format "--result-format=%s"
  :argument-regexp "\\(csv\\|json\\)"
  :choices '("csv" "json"))

(transient-define-argument dx-data--transient:--column-delimiter ()
  :class 'transient-switches
  :description "column delimiter export"
  :key "-d"
  :argument-format "--column-dilimiter=%s"
  :argument-regexp "\\(backquote\\|caret\\|comma\\|pipe\\|semicolon\\|tab\\)"
  :choices '("backquote" "caret" "comma" "pipe" "semicolon" "tab"))

(transient-define-argument dx-data--transient:--line-ending ()
  :class 'transient-switches
  :description "line ending export"
  :key "-l"
  :argument-format "--line-ending=%s"
  :argument-regexp "\\(lf\\|crlf\\)"
  :choices '("lf" "crlf"))

(transient-define-argument dx-data--transient:--all-rows ()
  :description "all rows"
  :key "-a"
  :shortarg "--all-rows"
  :argument "--all-rows")

(defun dx-data--export-file-handler (obj)
  "Set default value for export --file param."
  (transient-infix-set obj (format "%s" dx-data-export-file-default)))

(defun dx-data--wait-handler (obj)
  "Set default value for --wait param."
  (transient-infix-set obj (format "%s" dx-data-wait-value)))

(defun dx-data--sobject-handler (obj)
  "Set default value for --sobject param."
  (transient-infix-set obj (format "%s" dx-data--sobject-value)))

(defun dx-data--transient:-q-reader (prompt initial-input history)
  "Read a SOQL string return value."
  (dx--transient-menu:read-string prompt initial-input history "Please enter a SOQL."))

(defun dx-data--transient:-x-reader (prompt initial-input history)
  "Read a prefix string return value."
  (dx--transient-menu:read-string prompt initial-input history "Please enter a prefix files name."))

(defun dx-data--transient:-f-reader (prompt initial-input history)
  "Read a file string return value."
  (dx--transient-menu:read-file prompt (or initial-input dx-data--default-file) history))

(defun dx-data--transient:--sobject-reader (prompt initial-input history)
  "Read a sobject string return value."
  (dx--transient-menu:read-string prompt initial-input history "Please enter a sobject."))

(defun dx-data--export-bulk (args)
  "Export bulk data to org."
  (interactive (list (transient-args 'dx-data--transient:export-bulk)))
  (dx-core--data-process
   :cmd `("export" "bulk" ,@args "--json")
   (message "%s" json-instance)))

(defun dx-data--export-tree (args)
  "Export tree data to org."
  (interactive (list (transient-args 'dx-data--transient:export-tree)))
  (dx-core--data-process
   :cmd `("export" "tree" ,@args "--json")
   (message "%s" json-instance)))

(defun dx-data--export-resume (args)
  "Export tree data to org."
  (interactive (list (transient-args 'dx-data--transient:export-resume)))
  (dx-core--data-process
   :cmd `("export" "resume" ,@args "--json")
   (message "%s" json-instance)))

(defun dx-data--import-bulk (args)
  "Import bulk data to org."
  (interactive (list (transient-args 'dx-data--transient:import-bulk)))
  (dx-core--data-process
   :cmd `("import" "bulk" ,@args "--json")
   (alert (format "Import status:\nSuccessful Records:%s\nFailed Records:"
                  (or (dx-core--get-data-json "result.successfulRecords" json-instance) 0)
                  (or (dx-core--get-data-json "result.failedRecords" json-instance)) 0)
          :title "Salesforce alert")))

(defun dx-data--import-bulk (args)
  "Import tree data to org."
  (interactive (list (transient-args 'dx-data--transient:import-bulk)))
  (dx-core--data-process
   :cmd `("import" "bulk" ,@args "--json")
   (alert (format "Import status:\nSuccessful Records:%s\nFailed Records:"
                  (or (dx-core--get-data-json "result.successfulRecords" json-instance) 0)
                  (or (dx-core--get-data-json "result.failedRecords" json-instance)) 0)
          :title "Salesforce alert")))

(defun dx-data-link-import (url)
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
                    (let* ((file (make-temp-file "dx-import-data"))
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
                      (let ((proc (apply #'dx-start-process nil
                                         `(,dx-data-command-alias "import" "bulk" "--file" ,file "--target-org" ,dx-org-name "--json"))))
                        (async-wait proc)
                        (if (eq (process-exit-status proc) 1)
                            (list :status 1 :error (dx--async-when-done proc))
                          (list :status 0 :json-instance (dx-parse-buffer-json (process-buffer proc))))))))
               (lambda (result)
                 (if (eq (plist-get result :status) 0)
                     ;; Schedule periodic resume processing
                     (let ((poll-id (run-at-time 10 t
                                                 (lambda ()
                                                   (dx-core--data-process
                                                    :cmd `("export" "resume" "--json"
                                                           "-i" ,(dx-core--get-data-json "result.jobId" result))
                                                    (alert "Import process resumed successfully."
                                                           :title "DX Alert")
                                                    ;; clear poll event
                                                    (cancel-timer poll-id))))))
                       (alert "Import data is running." :title "DX Alert"))
                   ;; Handle import error
                   (alert (format "Data import failed: %s" (plist-get result :error)) :title "DX Alert")))))

(defun dx-data--soql-query (args &optional callback sync)
  "Execute SOQL string/file in specific org."
  (interactive (list (or ;;(transient-args 'dx-data--transient:data-query)
                   (dx-soql--read-content))))
  
  (dx-core--data-process
   :cmd (if (plistp args) args
          `("query" ,@(if (f-file-p args) `("-f" ,(expand-file-name args)) `("-q" ,args)) "--result-format=csv"))
   (when sync
     (if callback
         (funcall callback json-instance)
       (let ((buffer (generate-new-buffer "*soql data results*")))
         (with-current-buffer buffer
           (insert (with-current-buffer json-instance (buffer-string)))
           (csv-mode))
         (pop-to-buffer buffer))))))

;;;###autoload
(defun dx-data-org-table-import ()
  "Import data from org table."
  (interactive)
  (unless (org-at-table-p) (error "No table at point")) 
  (let ((dx-data-export-file-default (make-temp-file "export"))
        (dx-data--sobject-value (org-entry-get (point) "DX_SOBJECT_NAME" t))
        (dx-org-name (org-entry-get (point) "DX_ORG_NAME" t)))
    (org-table-export dx-data-export-file-default "orgtbl-to-csv")
    (dx-data--transient:import-bulk)))

(provide 'dx-data)
