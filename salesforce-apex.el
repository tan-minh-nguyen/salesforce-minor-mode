;;; salesforce-apex.el --- Apex features -*- lexical-binding: t -*-

;;TODO: create a transient menu
(require 'salesforce-core)
(require 'alert)
(require 'salesforce-transient-menu)

;;TODO set default output-directory

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
  "Open create Apex class transient menu."
  (interactive)
  (let ((salesforce-apex--transient:template "DefaultApexClass")
        (salesforce--transient-menu:output-dir (salesforce-core--metadata-path salesforce-apex-dir)))
    (salesforce-apex--transient:apex-resource)))

(defun salesforce-apex--create-trigger-menu ()
  "Open create Apex class transient menu."
  (interactive)
  (let ((salesforce-apex--transient:template "ApexTrigger")
        (salesforce--transient-menu:output-dir (salesforce-core--metadata-path salesforce-trigger-dir)))
    (salesforce-apex--transient:trigger-resource)))

(defun salesforce-apex--create-lightning-app-menu ()
  "Generate lightning app transient menu."
  (interactive)
  (let ((salesforce-apex--lightning-organize "app")
        (salesforce--transient-menu:output-dir (salesforce-core--metadata-path salesforce-lwc-dir)))
    (salesforce-apex--transient:lightning-resource)))

(defun salesforce-apex--create-lightning-component-menu ()
  "Generate lightning component transient menu."
  (interactive)
  (let ((salesforce-apex--lightning-organize "component")
        (salesforce-apex--transient:template "default")
        (salesforce--transient-menu:output-dir (salesforce-core--build-path salesforce-lwc-dir)))
    (salesforce-apex--transient:lightning-resource)))

(defun salesforce-apex-execute-code (content)
  "Execute apex code buffer/region."
  (interactive (list (if (eq (point) (mark)) (buffer-string) (buffer-substring-no-properties (mark) (point)))))
  (let ((temp-file (make-temp-file "temp_code")))

    (write-region content nil temp-file)

    (salesforce-core--apex-process
     :cmd `("run" "-f" ,temp-file "-o" ,salesforce-org-name "--json")
     (with-current-buffer (get-buffer-create "*apex log*")
       (let ((buffer-read-only t)
             (inhibit-read-only t))
         (insert (salesforce-core--get-data-json "result.logs" json-instance))))
     (switch-to-buffer (get-buffer-create "*apex log*"))
     (alert "Run apex code complete"
            :title "Salesforce Alert"))))

(defun salesforce-visualforce-generate-page ()
  "Generate visualforce page."
  (interactive)
  (let* ((page-name (read-string "page name: "))
         (page-label (read-string "page label: ")))

    (salesforce-core--visualforce-process
     :cmd `("generate" "page" "--json" "--name" ,page-name "--label" ,page-label "--output-dir" ,(salesforce-core--build-path salesforce-default-vf-path))
     ;; Swtich new page
     (switch-to-buffer (find-file (concat (salesforce-core--build-path salesforce-default-vf-path) "/" page-name ".page")))

     (alert (format "Create visualforce page" page-name)
            :title "Salesforce Alert"))))

(defun salesforce-visualforce-generate-component ()
  "Generate visualforce page."
  (interactive)
  (let* ((page-name (read-string "page name: "))
         (page-label (read-string "page label: "))
         (command))

    (salesforce-core--visualforce-process
     :cmd `("generate" "component" "--json" "--name" ,page-name "--label" ,page-label "--output-dir" ,(salesforce-core--build-path salesforce-vf-component-dir))
     (alert (format "Create visualforce page" page-name)
            :title "Salesforce Alert"))))

(defun salesforce-apex--generate-trigger (args)
  "Generate apex class"
  (interactive (list (transient-args 'salesforce-apex--transient:trigger-resource)))
  (salesforce-core--apex-process
   `("generate" "trigger" ,@args  "--json")
   (switch-to-buffer (find-file (salesforce-core--get-data-json "result.created.0" json-instance)))))

;; TODO: add feature can custom content in created class
;; Note: use yasnippet
(defun salesforce-apex--generate-class (args)
  "Generate apex class"
  (interactive (list (transient-args 'salesforce-apex--transient:apex-resource)))
  (salesforce-core--apex-process
   :cmd `("generate" "class" ,@args "--json")
   (switch-to-buffer (find-file (salesforce-core--get-data-json "result.created.0" json-instance)))))

(defun salesforce-apex--generate-lightning-component (args)
  "Generate lwc/aura component."
  (interactive (list (transient-args 'salesforce-apex--transient:lightning-resource)))
  (salesforce-core--lightning-process
   :cmd `("generate" "component" ,@args "--json")
   (alert (format message-success component-name)
          :title "Salesforce Alert")))

;;TODO: use salesforce-apex--generate-class instead
(defun salesforce-apex-generate-test-class ()
  "Generate apex test class"
  (interactive)
  (let* ((class-name (read-string "class name: ")))

    (salesforce-core--apex-process
     :cmd `("generate"
            "class"
            "--name" ,class-name
            "--output-dir" ,(salesforce-core--build-path salesforce-apex-dir)
            "--json")
     (switch-to-buffer (find-file (salesforce-core--build-path salesforce-apex-dir
                                                       (concat class-name ".cls")))
                       (beginning-of-buffer)
                       (insert "@isTest\n")
                       (save-buffer)
                       (current-buffer)))))

(defun salesforce-apex-generate-test-method ()
  "Generate apex test method"
  (interactive)
  (let ((method-name (read-string "method name: ")))

    (end-of-buffer)
    (forward-line -1)
    (insert (format "\n%s\nprivate static void %s () {\n}"
                    "@isTest"
                    method-name))))

(defun salesforce-apex-get-all-log ()
  "Get log apex"
  (interactive)

  (salesforce-core--apex-process
   :cmd '("list" "log" "--json")
   (let* ((records-list (salesforce-core--get-data-json "result" json-instance))
          (header-columns '("No" "Id" "Browser" "Operation"))
          (data (salesforce-table--make-data-table-from-vector
                 :header-columns header-columns
                 :data records-list)))

     (pop-to-buffer
      (salesforce-table--create-table
       :model
       (salesforce-table--make-table-mode
        :column-header
        (cl-loop for key in header-columns
                 collect `(:align ,'left :title ,key `:max-width ,'50))
        :data data)
       :buffer salesforce-dedicated-window-right
       :open t)))))

(cl-defun salesforce-apex--get-log (&key log-id number org post-log-handle)
  "Get log apex"
  (salesforce-core--apex-process
   :cmd `("get" "log" "--json"
          ,(and org ,@("-o" org))
          ,(unless (string-empty-p log-id) ,@("--log-id" ,log-id))
          ,(unless (null number) ,@("--number" ,number)))

   (funcall post-log-handle (salesforce-core--get-data-json "result.0.log" json-instance))))

(defun salesforce-apex-log-track (buffer)
  "Trace apex log on org."
  (interactive (list (generate-new-buffer "*salesforce-trace-log*")))
  (make-process :name "salesforce-trace-log"
                :buffer buffer
                :stderr "*salesforce-trace-log:error*"
                :command '("sf" "apex" "log" "tail"))
  ;;TODO: enable apex log major mode
  (with-current-buffer buffer)
  (pop-to-buffer buffer))

(defun salesforce-apex--get-result-test-job (job-id &optional poll-id)
  "Get apex test result."
  (salesforce-core--apex-process
   :cmd `("get" "test" "-i" ,job-id "-o" ,salesforce-org-name "--code-coverage" "--json")
   (alert (format "Tests class run success with coverage")
                  ;; (salesforce-core--get-data-json "result.summary.testRunCoverage" json-instance)
                  
          :title "SALESFORCE Alert")
   (and poll-id (cancel-timer poll-id))))

(cl-defun salesforce-apex--execute-unit-test (&key test-cases test-level)
  "Execute specific unit tests."
  (let ((file-name (file-name-base)))
    (salesforce-core--apex-process
     :cmd `("run" "test" "--tests" ,test-cases "--test-level" ,test-level "--detailed-coverage" "--code-coverage" "--json")

     (let* ((poll-id nil)
            (job-id (salesforce-core--get-data-json "result.testRunId" json-instance))
            ;; use closure function to reference poll-id and job-id when execute timer
            (callback (lambda (job)
                        (salesforce-apex--get-result-test-job job poll-id))))

       (if job-id
           (progn (alert (format "%s class is running." file-name)
                         :title "SALESFORCE Alert")
                  (setq poll-id (run-at-time 60 nil callback job-id)))
         (alert (format "Tests class run success with coverage %s"
                        (salesforce-core--get-data-json "result.summary.testRunCoverage" json-instance))
                :title "SALESFORCE Alert"))))))

;;;FIXME: get name
(defun salesforce-apex--retrieve-functions ()
  "Retrieve all fuctions in buffer."
  (cl-loop for (_ . node) in (treesit-query-capture (treesit-buffer-root-node)
                                                    '((method_declaration) @function))
           collect (treesit-node-text (treesit-node-child-by-field-name node "name") t)))

(defun salesforce-apex-execute-method-test (node)
  "Execute single unit test."
  (interactive
   (list (treesit-parent-until (treesit-node-at (point))
                               (lambda (node)
                                 (string= (treesit-node-type node) "method_declaration")))))
  (when-let* ((func-name (treesit-node-text (treesit-node-child-by-field-name node "name")))
              (test-cases (format "%s.%s" (file-name-base) func-name)))
    (salesforce-apex--execute-unit-test :test-cases test-cases :test-level "RunSpecifiedTests")))

(defun salesforce-apex-execute-test-class (file)
  "Execute all unit tests on FILE."
  (interactive (list (file-name-base)))
  (salesforce-apex--execute-unit-test :test-cases file :test-level "RunSpecifiedTests"))

(defun salesforce-apex-execute-local-tests ()
  "Run all tests class expect tests class in org managed package"
  (interactive)
  (salesforce-core--apex-process
   :cmd '("run" "test" "--test-level" "RunLocalTests" "--json")
   (salesforce-apex--get-result-test-job :job-id (salesforce-core--get-data-json "result.testRunId" json-instance))))

(defun salesforce-lightning-local-lwc ()
  "Start lwc server on local."
  (interactive)
  (salesforce-make-async-process
   :cmd (salesforce-generate-command (list salesforce-legacy-alias "lightning" "lwc" "start" "--json"))
   (alert "Start lwc local server success"
          :title "Salesforce Alert")))

(defun salesforce-apex--transient:--template-handler (obj)
  "Set default value for --template param."
  (transient-infix-set obj (format "--template=%s" salesforce-apex--transient:template)))

(defun salesforce-apex--lightning-transient:--type-handler (obj)
  "Set default value for --event param."
  (transient-infix-set obj (format "%s" salesforce-apex--lightning-type)))

(defun salesforce-apex--trigger-transient:--event-handler (obj)
  "Set default value for --type param."
  (transient-infix-set obj (format "%s" (string-join salesforce-apex--trigger-events ","))))

(defun salesforce-apex--trigger-transient:--sobject-handler (obj)
  "Set default value for --type param."
  (transient-infix-set obj (format "%s" salesforce-apex--trigger-sobject)))

(provide 'salesforce-apex)
