;;; salesforce-apex.el --- Apex features -*- lexical-binding: t -*-

;;TODO: create a transient menu
(require 'salesforce-core)
(require 'alert)
(require 'salesforce-transient-menu)

;;TODO set default output-directory
(defvar-local salesforce-apex--test-coverage nil
  "Test coverage of apex class.")

(defvar-local salesforce-apex--transient:template ""
  "Default value for --template argument.")

(defvar-local salesforce-apex--trigger-events '("before insert")
  "Default value for trigger events.")

(defvar-local salesforce-apex--trigger-sobject "SObject"
  "Default value for sobject on trigger.")

(defvar-local salesforce-apex--lightning-organize "component"
  "Default value for organize lightning.")

(defvar-local salesforce-apex--lightning-type "lwc"
  "Default value for --type argument.")

(transient-define-prefix salesforce-apex--transient:generate-resource ()
  "Menu select resource to generate."
  ["Apex"
   ("a" "Apex" salesforce-apex--create-apex-menu)
   ("t" "Trigger" salesforce-apex--create-trigger-menu)]
  ["Lightning"
   ("l" "App" salesforce-apex--create-lightning-app-menu)
   ("c" "Component" salesforce-apex--create-lightning-component-menu)])

(transient-define-prefix salesforce-apex--transient:apex-resource ()
  "Menu select apex resource to generate."
  ["Arguments"
   (salesforce--transient-menu:-d)
   (salesforce-apex--transient:-t)
   (salesforce-apex--transient:-n)
   (salesforce--transient-menu:--api-version)]
  [""
   ("RET" "Generate class" salesforce-apex--generate-class)])

(transient-define-argument salesforce-apex--transient:-n ()
  :class 'transient-option
  :always-read nil 
  :description "Name file"
  :key "-n"
  :shortarg "-n"
  :argument "--name="
  :reader #'salesforce--transient-menu:read-string)

(transient-define-argument salesforce-apex--transient:-t ()
  :class 'transient-switches
  :always-read nil 
  :description "Template file"
  :key "-t"
  :shortarg "-t"
  :argument-format "--template=%s"
  :argument-regexp "\\(ApexException\\|ApexUnitTest\\|BasicUnitTest\\|DefaultApexClass\\|InboundEmailService\\)"
  :init-value #'salesforce-apex--transient:--template-handler
  :choices '("ApexException" "ApexUnitTest" "BasicUnitTest" "DefaultApexClass" "InboundEmailService"))

(transient-define-prefix salesforce-apex--transient:trigger-resource ()
  "Menu select apex trigger resource to generate."
  ["Arguments"
   [(salesforce--transient-menu:-d)
    (salesforce-apex--transient:-n)
    (salesforce--transient-menu:--api-version)]
   [(salesforce-apex--trigger-transient:-e)
    (salesforce-apex--trigger-transient:-s)
    (salesforce-apex--trigger-transient:-t)]]
  [""
   ("RET" "Generate trigger" salesforce-apex--generate-trigger)])

(transient-define-argument salesforce-apex--trigger-transient:-e ()
  :class 'transient-switches
  :always-read nil 
  :description "Trigger events"
  :key "-e"
  :shortarg "-e"
  :argument-format "--event=%s"
  :argument-regexp "\\(before insert\\|before update\\|before delete\\|after insert\\|after update\\|after delete\\)"
  :init-value #'salesforce-apex--trigger-transient:--event-handler
  :choices '("before insert" "before update" "before delete" "after insert" "after update" "after delete"))

(transient-define-argument salesforce-apex--trigger-transient:-s ()
  :class 'transient-option
  :always-read nil 
  :description "Trigger Sobject"
  :key "-s"
  :shortarg "-s"
  :argument "--sobject="
  :init-value #'salesforce-apex--trigger-transient:--sobject-handler
  :reader #'salesforce--transient-menu:read-string)

(transient-define-argument salesforce-apex--trigger-transient:-t ()
  :class 'transient-switches
  :always-read nil 
  :description "Template file"
  :key "-t"
  :shortarg "-t"
  :argument-format "--template=%s"
  :argument-regexp "\\(ApexException\\|ApexUnitTest\\|BasicUnitTest\\|DefaultApexClass\\|InboundEmailService\\)"
  :init-value #'salesforce-apex--transient:--template-handler
  :choices '("ApexException" "ApexUnitTest" "BasicUnitTest" "DefaultApexClass" "InboundEmailService"))

(transient-define-prefix salesforce-apex--transient:lightning-resource ()
  "Menu select lightning resource to generate."
  ["Arguments"
   (salesforce--transient-menu:-d)
   (salesforce-apex--lightning-cmp-transient:-t)
   (salesforce-apex--lightning-transient:--type)
   (salesforce-apex--transient:-n)
   (salesforce--transient-menu:--api-version)]
  [""
   ("RET" "Generate lightning component" salesforce-apex--generate-lightning-component)])

(transient-define-argument salesforce-apex--lightning-cmp-transient:-t ()
  :if (lambda () (string= salesforce-apex--lightning-organize "component"))
  :class 'transient-switches
  :always-read nil 
  :description "Template file"
  :key "-t"
  :shortarg "-t"
  :argument-format "--template=%s"
  :argument-regexp "\\(default\\|analyticsDashboard\\|analyticsDashboardWithStep\\)"
  :init-value #'salesforce-apex--transient:--template-handler
  :choices '("default" "analyticsDashboard" "analyticsDashboardWithStep"))

(transient-define-argument salesforce-apex--lightning-transient:--type ()
  :class 'transient-switches
  :always-read nil 
  :description "Type component"
  :key "-T"
  :shortarg "--type"
  :argument-format "--type=%s"
  :argument-regexp "\\(aura\\|lwc\\)"
  :init-value #'salesforce-apex--lightning-transient:--type-handler
  :choices '("aura" "lwc"))

(defun salesforce-apex--create-apex-menu ()
  "Open the transient menu for creating an Apex class."
  (interactive)
  (let ((salesforce-apex--transient:template "DefaultApexClass")
        (salesforce--transient-menu:output-dir salesforce-apex-dir))
    (salesforce-apex--transient:apex-resource)))

(defun salesforce-apex--create-trigger-menu ()
  "Open the transient menu for creating an Apex trigger."
  (interactive)
  (let ((salesforce-apex--transient:template "ApexTrigger")
        (salesforce--transient-menu:output-dir salesforce-trigger-dir))
    (salesforce-apex--transient:trigger-resource)))

(defun salesforce-apex--create-lightning-app-menu ()
  "Open the transient menu for generating a Lightning app."
  (interactive)
  (let ((salesforce-apex--lightning-organize "app")
        (salesforce--transient-menu:output-dir salesforce-lwc-dir))
    (salesforce-apex--transient:lightning-resource)))

(defun salesforce-apex--create-lightning-component-menu ()
  "Open the transient menu for generating a Lightning component."
  (interactive)
  (let ((salesforce-apex--lightning-organize "component")
        (salesforce-apex--transient:template "default")
        (salesforce--transient-menu:output-dir salesforce-lwc-dir))
    (salesforce-apex--transient:lightning-resource)))

(defun salesforce-apex-execute-code (content)
  "Execute the given Apex code from the buffer or region."
  (interactive (list (if (eq (point) (mark)) (buffer-string) (buffer-substring-no-properties (mark) (point)))))
  (let ((temp-file (make-temp-file "temp_code")))

    (write-region content nil temp-file)

    (salesforce-core--apex-process
     :args `("run" "-f" ,temp-file "-o" ,salesforce-org-name "--json")
     (with-current-buffer (get-buffer-create "*apex log*")
       (let ((buffer-read-only t)
             (inhibit-read-only t))
         (insert (salesforce-core--get-data-json "result.logs" json-instance))))
     (switch-to-buffer (get-buffer-create "*apex log*"))
     (salesforce-core--alert "Run apex code complete"))))

(defun salesforce-visualforce-generate-page ()
  "Generate a new Visualforce page."
  (interactive)
  (let* ((page-name (read-string "Visualforce page name: "))
         (page-label (read-string "Visualforce page label: "))
         (output-dir (salesforce-core--join-path salesforce-default-vf-path))
         (page-path (concat output-dir "/" page-name ".page")))

    (salesforce-core--visualforce-process
     :args `("generate" "page" "--json" "--name" ,page-name "--label" ,page-label "--output-dir" ,output-dir)
     (switch-to-buffer (find-file page-path))
     (salesforce-core--alert (format "Successfully created Visualforce page: %s" page-name)))))

(defun salesforce-visualforce-generate-component ()
  "Generate a new Visualforce component."
  (interactive)
  (let* ((component-name (read-string "Visualforce component name: "))
         (component-label (read-string "Visualforce component label: "))
         (output-dir (salesforce-core--join-path salesforce-vf-component-dir))
         (component-path (salesforce-core--join-path "/" component-name ".component")))

    (salesforce-core--visualforce-process
     :args `("generate" "component" "--json" "--name" ,component-name "--label" ,component-label "--output-dir" ,output-dir)
     (switch-to-buffer (find-file component-path))
     (salesforce-core--alert (format "Successfully created Visualforce component: %s" component-name)))))

(defun salesforce-apex--generate-trigger (args)
  "Generate an Apex trigger with the specified arguments."
  (interactive (list (transient-args 'salesforce-apex--transient:trigger-resource)))
  (salesforce-core--apex-process
   `("generate" "trigger" ,@args  "--json")
   (switch-to-buffer (find-file (salesforce-core--get-data-json "result.created.0" json-instance)))))

;; TODO: add feature can custom content in created class
;; Note: use yasnippet
(defun salesforce-apex--generate-class (args)
  "Generate an Apex class with the specified arguments."
  (interactive (list (transient-args 'salesforce-apex--transient:apex-resource)))
  (salesforce-core--apex-process
   :args `("generate" "class" ,@args "--json")
   (switch-to-buffer (find-file (salesforce-core--get-data-json "result.created.0" json-instance)))))

(defun salesforce-apex--generate-lightning-component (args)
  "Generate a Lightning Web Component (LWC) or Aura component with the specified arguments."
  (interactive (list (transient-args 'salesforce-apex--transient:lightning-resource)))
  (salesforce-core--lightning-process
   :args `("generate" "component" ,@args "--json")
   (salesforce-core--alert (format message-success component-name))))

;;TODO: use salesforce-apex--generate-class instead
(defun salesforce-apex-generate-test-class ()
  "Generate an Apex test class."
  (interactive)
  (let* ((class-name (read-string "Class name: "))
         (output-dir (salesforce-core--join-path salesforce-apex-dir))
         (class-path (salesforce-core--join-path "/" class-name ".cls")))

    (salesforce-core--apex-process
     :args `("generate" "class" "--name" ,class-name "-t" "ApexUnitTest" "--output-dir" ,output-dir "--json")
     (switch-to-buffer (find-file class-path))
     (salesforce-core--alert (format "Successfully created test class: %s" class-name)))))

(defun salesforce-apex--draw-table (header data)
  "Draw table from DATA and HEADER."
  (let ((header-construct (mapcar (lambda (col)
                                    `(,col . ,(length col)))
                                  header)))
    (cl-loop for row in data
             as line = (mapcar (lambda (col)
                                 (let ((header (pop header-construct)))
                                   (string-pad col (cdr header))
                                   (add-to-list header-construct header t))))
             concat (concat line "\n"))))

(defun salesforce-apex--get-result-test-job (job-id &optional poll-id)
  "Retrieve the result of an Apex test job by job ID."
  (let ((buffer (current-buffer)))
    (salesforce-core--apex-process
     :args `("get" "test" "-i" ,job-id "-o" ,salesforce-org-name "--code-coverage" "--json")
     ;; (salesforce-core--alert (format "Tests class run success with coverage"))
     (let* ((summary (salesforce-core--get-data-json "result.summary" json-instance))
            (alert-message (format "Unit Tests Run %s"
                                   (salesforce-core--get-data-json "outcome" summary))))
       ;; (salesforce-core--pop-box-table
       ;;  (cons "Ran" (salesforce-core--get-data-json "testsRan" summary))
       ;;  (cons "Passed" (salesforce-core--get-data-json "passing" summary))
       ;;  (cons "Failed" (salesforce-core--get-data-json "failing" summary)))
       
       (salesforce-core--alert alert-message))
     (with-current-buffer buffer
       (setq-local salesforce-apex--test-coverage
                   (salesforce-core--get-data-json "result.coverage" json-instance)))
     (and poll-id (cancel-timer poll-id)))))

(cl-defun salesforce-apex--execute-unit-test (&key test-cases test-level)
  "Execute specific unit tests with the given test cases and test level."
  (let ((file-name (file-name-base)))
    (salesforce-core--apex-process
     :args `("run" "test" "--tests" ,test-cases "--test-level" ,test-level "--detailed-coverage" "--code-coverage" "--json")

     (let* ((poll-id nil)
            (job-id (salesforce-core--get-data-json "result.testRunId" json-instance))
            ;; use closure function to reference poll-id and job-id when execute timer
            (callback (lambda (job)
                        (salesforce-apex--get-result-test-job job poll-id))))

       (if job-id
           (progn (salesforce-core--alert (format "%s class is running." file-name))
                  (setq poll-id (run-at-time 60 nil callback job-id)))
         (salesforce-core--alert (format "Tests class run success with coverage %s"
                                         (salesforce-core--get-data-json "result.summary.testRunCoverage" json-instance))))))))

;;;FIXME: get name
(defun salesforce-apex--retrieve-functions ()
  "Retrieve all function names in the current buffer."
  (cl-loop for (_ . node) in (treesit-query-capture (treesit-buffer-root-node)
                                                 '((method_declaration) @function))
           collect (treesit-node-text (treesit-node-child-by-field-name node "name") t)))

(defun salesforce-apex-execute-method-test (node)
  "Execute a single unit test for the method at the given node."
  (interactive
   (list (treesit-parent-until (treesit-node-at (point))
                            (lambda (node)
                              (string= (treesit-node-type node) "method_declaration")))))
  (when-let* ((func-name (treesit-node-text (treesit-node-child-by-field-name node "name")))
              (test-cases (format "%s.%s" (file-name-base) func-name)))
    (salesforce-apex--execute-unit-test :test-cases test-cases :test-level "RunSpecifiedTests")))

(defun salesforce-apex-execute-test-class (file)
  "Execute all unit tests in the specified file."
  (interactive (list (file-name-base)))
  (salesforce-apex--execute-unit-test :test-cases file :test-level "RunSpecifiedTests"))

(defun salesforce-apex-select-classes ()
  "Selection of classes in the project.")

;;TODO: choose class to run test, support multi-selection
(defun salesforce-apex-execute-selection-class (classes)
  "Run the selection unit test class."
  (interactive (list (completing-read-multiple ""))))

(defun salesforce-apex-execute-local-tests ()
  "Run all test classes except those in the org managed package."
  (interactive)
  (salesforce-core--apex-process
   :args '("run" "test" "--test-level" "RunLocalTests" "--json")
   (salesforce-apex--get-result-test-job :job-id (salesforce-core--get-data-json "result.testRunId" json-instance))))

(defun salesforce-lightning-local-lwc ()
  "Start the local server for Lightning Web Components (LWC)."
  (interactive)
  (salesforce-core--lightning-process
   :args '("lightning" "lwc" "start" "--json")
   (salesforce-core--alert "Start lwc local server success")))

(defun salesforce-apex-run-local-tests ()
  "Run all test classes except those in the org managed package."
  (interactive)
  (salesforce-core--apex-process
   :args '("run" "test" "--test-level" "RunLocalTests" "--json")
   (salesforce-apex-get-result-test-job (job-id (salesforce-core--get-data-json "result.testRunId" json-instance)))))

(defmacro salesforce-apex-prompt-log (&rest body)
  "Collect all logs and make prompt for select.

BODY: Forms execute after select candidate."
  `(salesforce-core--apex-process
    :args '("list" "log" "--json")
    (let* ((candidates (cl-loop for log-file across (salesforce-core--get-data-json "result" json-instance)
                                collect `(:app ,(salesforce-core--get-data-json "Application" log-file)
                                               :time ,(salesforce-core--get-data-json "StartTime" log-file)
                                               :operation ,(salesforce-core--get-data-json "Operation" log-file)
                                               :log-length ,(salesforce-core--get-data-json "LogLength" log-file)
                                               :status ,(salesforce-core--get-data-json "Status" log-file)
                                               :log-id ,(salesforce-core--get-data-json "Id" log-file))))
           (candidate (consult--read candidates
                                     :prompt "Log: "
                                     :category 'salesforce-log
                                     :require-match t
                                     :annotate #'salesforce-apex-consult--annotate)))
      ,@body)))

(defun salesforce-apex--time-format (format-string time-string)
  "Format TIME-STRING according to FORMAT-STRING."
  (format-time-string format-string
                      (encode-time (parse-time-string time-string))))

(defun salesforce-apex-consult--annotate (candidate)
  "Format a CANDIDATE string with properties for display."
  (pcase-let* ((`(:app ,app :time ,time operation ,op :log-length ,size :status ,status :log-id ,id) args)
               (len-text 10)
               (prop-time (propertize (salesforce-apex--time-format "%Y-%m-%d %H:%M:%S" time) 'face 'org-time-grid))
               (prop-op (propertize (string-pad op len-text) 'face 'font-lock-doc-markup-face))
               (prop-size (propertize (string-pad (format "%s" (/ size 1000)) len-text) 'face 'font-lock-keyword-face))
               (prop-status (propertize (string-pad status len-text) 'face 'font-lock-keyword-face))
               (prefix (nerd-icons-octicon "nf-oct-log"))
               (suffix (concat (propertize (string-pad op len-text) 'face (if (string= status "success") 'font-lock-builtin-face 'font-lock-string-face))
                               prop-size
                               status 
                               prop-time)))
    
    `(,id
      ,prefix
      ,suffix)))

(defun salesforce-apex-soql-string-p (soql-string)
  "Check query string is soql."
  (let ((soql-re (concat "^SELECT [A-Za-z]+ FROM ([A-Za-z0-9_]+) ")))
    (string-match-p soql-re soql-string)))

(defun salesforce-apex--transient:--template-handler (obj)
  "Set the default value for the --template parameter."
  (transient-infix-set obj (format "--template=%s" salesforce-apex--transient:template)))

(defun salesforce-apex--lightning-transient:--type-handler (obj)
  "Set the default value for the --type parameter."
  (transient-infix-set obj (format "%s" salesforce-apex--lightning-type)))

(defun salesforce-apex--trigger-transient:--event-handler (obj)
  "Set the default value for the --event parameter."
  (transient-infix-set obj (format "%s" (string-join salesforce-apex--trigger-events ","))))

(defun salesforce-apex--trigger-transient:--sobject-handler (obj)
  "Set the default value for the --sobject parameter."
  (transient-infix-set obj (format "%s" salesforce-apex--trigger-sobject)))

(provide 'salesforce-apex)
