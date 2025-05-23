;;; dx-apex.el --- Apex features -*- lexical-binding: t -*-

;;TODO: create a transient menu
(require 'dx-core)
(require 'dx-transient-menu)

;;TODO set default output-directory

(defvar-local dx-apex--transient:template ""
  "Default value for --template argument.")

(defvar-local dx-apex--trigger-events '("before insert")
  "Default value for trigger events.")

(defvar-local dx-apex--trigger-sobject "SObject"
  "Default value for sobject on trigger.")

(defvar-local dx-apex--lightning-organize "component"
  "Default value for organize lightning.")

(defvar-local dx-apex--lightning-type "lwc"
  "Default value for --type argument.")

(transient-define-prefix dx-apex--transient:generate-resource ()
  "Menu select resource to generate."
  ["Apex"
   ("a" "Apex" dx-apex--create-apex-menu)
   ("t" "Trigger" dx-apex--create-trigger-menu)]
  ["Lightning"
   ("l" "App" dx-apex--create-lightning-app-menu)
   ("c" "Component" dx-apex--create-lightning-component-menu)])

(transient-define-prefix dx-apex--transient:apex-resource ()
  "Menu select apex resource to generate."
  ["Arguments"
   (dx--transient-menu:-d)
   (dx-apex--transient:-t)
   (dx-apex--transient:-n)
   (dx--transient-menu:--api-version)]
  [""
   ("RET" "Generate class" dx-apex--generate-class)])

(transient-define-argument dx-apex--transient:-n ()
  :class 'transient-option
  :always-read nil 
  :description "Name file"
  :key "-n"
  :shortarg "-n"
  :argument "--name="
  :reader #'dx--transient-menu:read-string)

(transient-define-argument dx-apex--transient:-t ()
  :class 'transient-switches
  :always-read nil 
  :description "Template file"
  :key "-t"
  :shortarg "-t"
  :argument-format "--template=%s"
  :argument-regexp "\\(ApexException\\|ApexUnitTest\\|BasicUnitTest\\|DefaultApexClass\\|InboundEmailService\\)"
  :init-value #'dx-apex--transient:--template-handler
  :choices '("ApexException" "ApexUnitTest" "BasicUnitTest" "DefaultApexClass" "InboundEmailService"))

(transient-define-prefix dx-apex--transient:trigger-resource ()
  "Menu select apex trigger resource to generate."
  ["Arguments"
   [(dx--transient-menu:-d)
    (dx-apex--transient:-n)
    (dx--transient-menu:--api-version)]
   [(dx-apex--trigger-transient:-e)
    (dx-apex--trigger-transient:-s)
    (dx-apex--trigger-transient:-t)]]
  [""
   ("RET" "Generate trigger" dx-apex--generate-trigger)])

(transient-define-argument dx-apex--trigger-transient:-e ()
  :class 'transient-switches
  :always-read nil 
  :description "Trigger events"
  :key "-e"
  :shortarg "-e"
  :argument-format "--event=%s"
  :argument-regexp "\\(before insert\\|before update\\|before delete\\|after insert\\|after update\\|after delete\\)"
  :init-value #'dx-apex--trigger-transient:--event-handler
  :choices '("before insert" "before update" "before delete" "after insert" "after update" "after delete"))

(transient-define-argument dx-apex--trigger-transient:-s ()
  :class 'transient-option
  :always-read nil 
  :description "Trigger Sobject"
  :key "-s"
  :shortarg "-s"
  :argument "--sobject="
  :init-value #'dx-apex--trigger-transient:--sobject-handler
  :reader #'dx--transient-menu:read-string)

(transient-define-argument dx-apex--trigger-transient:-t ()
  :class 'transient-switches
  :always-read nil 
  :description "Template file"
  :key "-t"
  :shortarg "-t"
  :argument-format "--template=%s"
  :argument-regexp "\\(ApexException\\|ApexUnitTest\\|BasicUnitTest\\|DefaultApexClass\\|InboundEmailService\\)"
  :init-value #'dx-apex--transient:--template-handler
  :choices '("ApexException" "ApexUnitTest" "BasicUnitTest" "DefaultApexClass" "InboundEmailService"))

(transient-define-prefix dx-apex--transient:lightning-resource ()
  "Menu select lightning resource to generate."
  ["Arguments"
   (dx--transient-menu:-d)
   (dx-apex--lightning-cmp-transient:-t)
   (dx-apex--lightning-transient:--type)
   (dx-apex--transient:-n)
   (dx--transient-menu:--api-version)]
  [""
   ("RET" "Generate lightning component" dx-apex--generate-lightning-component)])

(transient-define-argument dx-apex--lightning-cmp-transient:-t ()
  :if (lambda () (string= dx-apex--lightning-organize "component"))
  :class 'transient-switches
  :always-read nil 
  :description "Template file"
  :key "-t"
  :shortarg "-t"
  :argument-format "--template=%s"
  :argument-regexp "\\(default\\|analyticsDashboard\\|analyticsDashboardWithStep\\)"
  :init-value #'dx-apex--transient:--template-handler
  :choices '("default" "analyticsDashboard" "analyticsDashboardWithStep"))

(transient-define-argument dx-apex--lightning-transient:--type ()
  :class 'transient-switches
  :always-read nil 
  :description "Type component"
  :key "-T"
  :shortarg "--type"
  :argument-format "--type=%s"
  :argument-regexp "\\(aura\\|lwc\\)"
  :init-value #'dx-apex--lightning-transient:--type-handler
  :choices '("aura" "lwc"))

(defun dx-apex--create-apex-menu ()
  "Open create Apex class transient menu."
  (interactive)
  (let ((dx-apex--transient:template "DefaultApexClass")
        (dx--transient-menu:output-dir (dx-core--metadata-path dx-apex-dir)))
    (dx-apex--transient:apex-resource)))

(defun dx-apex--create-trigger-menu ()
  "Open create Apex class transient menu."
  (interactive)
  (let ((dx-apex--transient:template "ApexTrigger")
        (dx--transient-menu:output-dir (dx-core--metadata-path dx-trigger-dir)))
    (dx-apex--transient:trigger-resource)))

(defun dx-apex--create-lightning-app-menu ()
  "Generate lightning app transient menu."
  (interactive)
  (let ((dx-apex--lightning-organize "app")
        (dx--transient-menu:output-dir (dx-core--metadata-path dx-lwc-dir)))
    (dx-apex--transient:lightning-resource)))

(defun dx-apex--create-lightning-component-menu ()
  "Generate lightning component transient menu."
  (interactive)
  (let ((dx-apex--lightning-organize "component")
        (dx-apex--transient:template "default")
        (dx--transient-menu:output-dir (dx-core--build-path dx-lwc-dir)))
    (dx-apex--transient:lightning-resource)))

(defun dx-apex-execute-code (content)
  "Execute apex code buffer/region."
  (interactive (list (if (eq (point) (mark)) (buffer-string) (buffer-substring-no-properties (mark) (point)))))
  (let ((temp-file (make-temp-file "temp_code")))

    (write-region content nil temp-file)

    (dx-core--apex-process
     :cmd `("run" "-f" ,temp-file "-o" ,dx-org-name "--json")
     (with-current-buffer (get-buffer-create "*apex log*")
       (let ((buffer-read-only t)
             (inhibit-read-only t))
         (insert (dx-core--get-data-json "result.logs" json-instance))))
     (switch-to-buffer (get-buffer-create "*apex log*"))
     (alert "Run apex code complete"
            :title "Salesforce Alert"))))

(defun dx-visualforce-generate-page ()
  "Generate visualforce page."
  (interactive)
  (let* ((page-name (read-string "page name: "))
         (page-label (read-string "page label: ")))

    (dx-core--visualforce-process
     :cmd `("generate" "page" "--json" "--name" ,page-name "--label" ,page-label "--output-dir" ,(dx-core--build-path dx-default-vf-path))
     ;; Swtich new page
     (switch-to-buffer (find-file (concat (dx-core--build-path dx-default-vf-path) "/" page-name ".page")))

     (alert (format "Create visualforce page" page-name)
            :title "Salesforce Alert"))))

(defun dx-visualforce-generate-component ()
  "Generate visualforce page."
  (interactive)
  (let* ((page-name (read-string "page name: "))
         (page-label (read-string "page label: "))
         (command ))

    (dx-core--visualforce-process
     :cmd `("generate" "component" "--json" "--name" ,page-name "--label" ,page-label "--output-dir" ,(dx-core--build-path dx-vf-component-dir))
     (alert (format "Create visualforce page" page-name)
            :title "Salesforce Alert"))))

(defun dx-apex--generate-trigger (args)
  "Generate apex class"
  (interactive (list (transient-args 'dx-apex--transient:trigger-resource)))
  (dx-core--apex-process
   `("generate" "trigger" ,@args  "--json")
   (switch-to-buffer (find-file (dx-core--get-data-json "result.created.0" json-instance)))))

;; TODO: add feature can custom content in created class
(defun dx-apex--generate-class (args)
  "Generate apex class"
  (interactive (list (transient-args 'dx-apex--transient:apex-resource)))
  (dx-core--apex-process
   :cmd `("generate" "class" ,@args "--json")
   (switch-to-buffer (find-file (dx-core--get-data-json "result.created.0" json-instance)))))

(defun dx-apex--generate-lightning-component (args)
  "Generate lwc/aura component."
  (interactive (list (transient-args 'dx-apex--transient:lightning-resource)))
  (dx-core--lightning-process
   :cmd `("generate" "component" ,@args "--json")
   (alert (format message-success component-name)
          :title "Salesforce Alert")))

;;TODO: use dx-apex--generate-class instead
(defun dx-apex-generate-test-class ()
  "Generate apex test class"
  (interactive)
  (let* ((class-name (read-string "class name: ")))

    (dx-core--apex-process
     :cmd `("generate"
            "class"
            "--name" ,class-name
            "--output-dir" ,(dx-core--build-path dx-apex-dir)
            "--json")
     (switch-to-buffer (find-file (dx-core--build-path dx-apex-dir
                                                       (concat class-name ".cls")))
                       (beginning-of-buffer)
                       (insert "@isTest\n")
                       (save-buffer)
                       (current-buffer)))))

(defun dx-apex-generate-test-method ()
  "Generate apex test method"
  (interactive)
  (let ((method-name (read-string "method name: ")))

    (end-of-buffer)
    (forward-line -1)
    (insert (format "\n%s\nprivate static void %s () {\n}"
                    "@isTest"
                    method-name))))

(defun dx-apex-get-all-log ()
  "Get log apex"
  (interactive)

  (dx-core--apex-process
   :cmd '("list" "log" "--json")
   (let* ((records-list (dx-core--get-data-json "result" json-instance))
          (header-columns '("No" "Id" "Browser" "Operation"))
          (data (dx-table--make-data-table-from-vector
                 :header-columns header-columns
                 :data records-list)))

     (pop-to-buffer
      (dx-table--create-table
       :model
       (dx-table--make-table-mode
        :column-header
        (cl-loop for key in header-columns
                 collect `(:align ,'left :title ,key `:max-width ,'50))
        :data data)
       :buffer dx-dedicated-window-right
       :open t)))))

(cl-defun dx-apex--get-log (&key log-id number org post-log-handle)
  "Get log apex"
  (dx-core--apex-process
   :cmd `("get" "log" "--json"
          ,(and org ,@("-o" org))
          ,(unless (string-empty-p log-id) ,@("--log-id" ,log-id))
          ,(unless (null number) ,@("--number" ,number)))

   (funcall post-log-handle (dx-core--get-data-json "result.0.log" json-instance))))

(defun dx-apex-log-track (buffer)
  "Trace apex log on org."
  (interactive (list (generate-new-buffer "*dx-trace-log*")))
  (make-process :name "dx-trace-log"
                :buffer buffer
                :stderr "*dx-trace-log:error*"
                :command '("sf" "apex" "log" "tail"))
  ;;TODO: enable apex log major mode
  (with-current-buffer buffer)
  (pop-to-buffer buffer))

(defun dx-apex--get-result-test-job (job-id &optional poll-id)
  "Get apex test result."
  (dx-core--apex-process
   :cmd `("get" "test" "-i" ,job-id "-o" ,dx-org-name "--code-coverage" "--json")
   (alert (format "Tests class run success with coverage"
                  ;; (dx-core--get-data-json "result.summary.testRunCoverage" json-instance)
                  )
          :title "DX Alert")
   (and poll-id (cancel-timer poll-id))))

(cl-defun dx-apex--execute-unit-test (&key test-cases test-level)
  "Execute specific unit tests."
  (let ((file-name (file-name-base)))
    (dx-core--apex-process
     :cmd `("run" "test" "--tests" ,test-cases "--test-level" ,test-level "--detailed-coverage" "--code-coverage" "--json")

     (let* ((poll-id nil)
            (job-id (dx-core--get-data-json "result.testRunId" json-instance))
            ;; use closure function to reference poll-id and job-id when execute timer
            (callback (lambda (job)
                        (dx-apex--get-result-test-job job poll-id))))

       (if job-id
           (progn (alert (format "%s class is running." file-name)
                         :title "DX Alert")
                  (setq poll-id (run-at-time 60 nil callback job-id)))
         (alert (format "Tests class run success with coverage %s"
                        (dx-core--get-data-json "result.summary.testRunCoverage" json-instance))
                :title "DX Alert"))))))

(defun dx-apex-execute-method-test (node)
  "Execute single unit test."
  (interactive
   (list (treesit-parent-until (treesit-node-at (point))
                               (lambda (node)
                                 (string= (treesit-node-type node) "method_declaration")))))
  (when-let* ((func-name (treesit-node-text (treesit-node-child-by-field-name node "name")))
              (test-cases (format "%s.%s" (file-name-base) func-name)))
    (dx-apex--execute-unit-test :test-cases test-cases :test-level "RunSpecifiedTests")))

(defun dx-apex-execute-test-class (file)
  "Execute all unit tests on FILE."
  (interactive (list (file-name-base)))
  (dx-apex--execute-unit-test :test-cases file :test-level "RunSpecifiedTests"))

(defun dx-apex-execute-local-tests ()
  "Run all tests class expect tests class in org managed package"
  (interactive)
  (dx-core--apex-process
   :cmd '("run" "test" "--test-level" "RunLocalTests" "--json")
   (dx-apex--get-result-test-job :job-id (dx-core--get-data-json "result.testRunId" json-instance))))

(defun dx-lightning-local-lwc ()
  "Start lwc server on local."
  (interactive)
  (dx-make-async-process
   :cmd (dx-generate-command (list dx-legacy-alias "lightning" "lwc" "start" "--json"))
   (alert "Start lwc local server success"
          :title "Salesforce Alert")))

(defun dx-apex--transient:--template-handler (obj)
  "Set default value for --template param."
  (transient-infix-set obj (format "--template=%s" dx-apex--transient:template)))

(defun dx-apex--lightning-transient:--type-handler (obj)
  "Set default value for --type param."
  (transient-infix-set obj (format "%s" dx-apex--lightning-type)))

(defun dx-apex--trigger-transient:--event-handler (obj)
  "Set default value for --type param."
  (transient-infix-set obj (format "%s" (string-join dx-apex--trigger-events ","))))

(defun dx-apex--trigger-transient:--sobject-handler (obj)
  "Set default value for --type param."
  (transient-infix-set obj (format "%s" dx-apex--trigger-sobject)))

(provide 'dx-apex)
