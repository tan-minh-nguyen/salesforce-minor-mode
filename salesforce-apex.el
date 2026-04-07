;;; salesforce-apex.el --- Apex features -*- lexical-binding: t -*-

;;; Commentary:
;; This package provides Apex-related functionality for Salesforce development,
;; including class generation, test execution, and Lightning component creation.

;;; Code:

(require 'salesforce-core)
(require 'alert)
(require 'salesforce-menu)

;;; Variables

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

;;; Transient Menu Definitions - Main Menus

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
   (salesforce--menu:-d)
   (salesforce-apex--transient:-t)
   (salesforce-apex--transient:-n)
   (salesforce--menu:--api-version)]
  [""
   ("RET" "Generate class" salesforce-apex--generate-class)])

(transient-define-prefix salesforce-apex--transient:trigger-resource ()
  "Menu select apex trigger resource to generate."
  ["Arguments"
   [(salesforce--menu:-d)
    (salesforce-apex--transient:-n)
    (salesforce--menu:--api-version)]
   [(salesforce-apex--trigger-transient:-e)
    (salesforce-apex--trigger-transient:-s)
    (salesforce-apex--trigger-transient:-t)]]
  [""
   ("RET" "Generate trigger" salesforce-apex--generate-trigger)])

(transient-define-prefix salesforce-apex--transient:lightning-resource ()
  "Menu select lightning resource to generate."
  ["Arguments"
   (salesforce--menu:-d)
   (salesforce-apex--lightning-cmp-transient:-t)
   (salesforce-apex--lightning-transient:--type)
   (salesforce-apex--transient:-n)
   (salesforce--menu:--api-version)]
  [""
   ("RET" "Generate lightning component" salesforce-apex--generate-lightning-component)])

;;; Transient Menu Definitions - Arguments

(transient-define-argument salesforce-apex--transient:-n ()
  :class 'transient-option
  :always-read nil 
  :description "Name file"
  :key "-n"
  :shortarg "-n"
  :argument "--name="
  :reader #'salesforce--menu:read-string)

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
  :reader #'salesforce--menu:read-string)

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

;;; Transient Menu Handlers

(defun salesforce-apex--transient:--template-handler (obj)
  "Set the default value for the --template parameter in OBJ."
  (transient-infix-set obj (format "--template=%s" salesforce-apex--transient:template)))

(defun salesforce-apex--lightning-transient:--type-handler (obj)
  "Set the default value for the --type parameter in OBJ."
  (transient-infix-set obj (format "%s" salesforce-apex--lightning-type)))

(defun salesforce-apex--trigger-transient:--event-handler (obj)
  "Set the default value for the --event parameter in OBJ."
  (transient-infix-set obj (format "%s" (string-join salesforce-apex--trigger-events ","))))

(defun salesforce-apex--trigger-transient:--sobject-handler (obj)
  "Set the default value for the --sobject parameter in OBJ."
  (transient-infix-set obj (format "%s" salesforce-apex--trigger-sobject)))

;;; Menu Entry Points

(defun salesforce-apex--create-apex-menu ()
  "Open the transient menu for creating an Apex class."
  (interactive)
  (let ((salesforce-apex--transient:template "DefaultApexClass")
        (salesforce--menu:output-dir
         (salesforce-project-metadata-path salesforce-project-session 'class)))
    (salesforce-apex--transient:apex-resource)))

(defun salesforce-apex--create-trigger-menu ()
  "Open the transient menu for creating an Apex trigger."
  (interactive)
  (let ((salesforce-apex--transient:template "ApexTrigger")
        (salesforce--menu:output-dir
         (salesforce-project-metadata-path salesforce-project-session 'trigger)))
    (salesforce-apex--transient:trigger-resource)))

(defun salesforce-apex--create-lightning-app-menu ()
  "Open the transient menu for generating a Lightning app."
  (interactive)
  (let ((salesforce-apex--lightning-organize "app")
        (salesforce--menu:output-dir
         (salesforce-project-metadata-path salesforce-project-session 'lwc)))
    (salesforce-apex--transient:lightning-resource)))

(defun salesforce-apex--create-lightning-component-menu ()
  "Open the transient menu for generating a Lightning component."
  (interactive)
  (let ((salesforce-apex--lightning-organize "component")
        (salesforce-apex--transient:template "default")
        (salesforce--menu:output-dir
         (salesforce-project-metadata-path salesforce-project-session 'lwc)))
    (salesforce-apex--transient:lightning-resource)))

;;; Code Execution

(defun salesforce-apex-execute-code (content)
  "Execute the given Apex code CONTENT from the buffer or region."
  (interactive (list (if (eq (point) (mark))
                         (buffer-string)
                       (buffer-substring-no-properties (mark) (point)))))
  (let ((temp-file (make-temp-file "temp_code"))
        (org-name (salesforce-project-org salesforce-project-session)))
    (write-region content nil temp-file)
    (salesforce-core--apex-process
     :args `("run" "-f" ,temp-file "-o" ,org-name "--json")
     :callback (lambda (json-instance)
                 (with-current-buffer (get-buffer-create "*apex log*")
                   (let ((buffer-read-only t)
                         (inhibit-read-only t))
                     (insert (map-nested-elt json-instance '("result" "logs")))))
                 (switch-to-buffer (get-buffer-create "*apex log*"))
                 (salesforce-core--alert "Run apex code complete")))))

;;; Resource Generation

(defun salesforce-apex--generate-resource (type args result-path-keys)
  "Generate a Salesforce resource of TYPE with ARGS.
Open the created file using RESULT-PATH-KEYS to extract from JSON response."
  (salesforce-core--apex-process
   :args `("generate" ,type ,@args "--json")
   :callback (lambda (json-instance)
               (switch-to-buffer (find-file (map-nested-elt json-instance result-path-keys))))))

(defun salesforce-apex--generate-trigger (args)
  "Generate an Apex trigger with the specified ARGS."
  (interactive (list (transient-args 'salesforce-apex--transient:trigger-resource)))
  (salesforce-apex--generate-resource "trigger" args '("result" "created" 0)))

(defun salesforce-apex--generate-class (args)
  "Generate an Apex class with the specified ARGS."
  (interactive (list (transient-args 'salesforce-apex--transient:apex-resource)))
  (salesforce-apex--generate-resource "class" args '("result" "created" 0)))

(defun salesforce-apex--generate-lightning-component (args)
  "Generate a Lightning Web Component (LWC) or Aura component with ARGS."
  (interactive (list (transient-args 'salesforce-apex--transient:lightning-resource)))
  (salesforce-core--lightning-process
   :args `("generate" "component" ,@args "--json")
   :callback (lambda (_)
               (salesforce-core--alert "Successfully created component"))))

(defun salesforce-apex-generate-test-class ()
  "Generate an Apex test class.
TODO: Replace with salesforce-apex--generate-class for consistency."
  (interactive)
  (let* ((class-name (read-string "Class name: "))
         (output-dir (salesforce-project-metadata-path salesforce-project-session 'class))
         (class-path (expand-file-name (concat class-name ".cls") output-dir)))
    (salesforce-core--apex-process
     :args `("generate" "class" "--name" ,class-name "-t" "ApexUnitTest"
             "--output-dir" ,output-dir "--json")
     :callback (lambda (_)
                 (switch-to-buffer (find-file class-path))
                 (salesforce-core--alert (format "Successfully created test class: %s" class-name))))))

;;; Visualforce Generation

(defun salesforce-visualforce--generate-resource (type name label output-dir extension)
  "Generate a Visualforce resource of TYPE with NAME, LABEL, OUTPUT-DIR, and EXTENSION."
  (let ((resource-path (concat output-dir "/" name extension)))
    (salesforce-core--visualforce-process
     :args `("generate" ,type "--json" "--name" ,name "--label" ,label
             "--output-dir" ,output-dir)
     :callback (lambda (_)
                 (switch-to-buffer (find-file resource-path))
                 (salesforce-core--alert (format "Successfully created Visualforce %s: %s"
                                                 type name))))))

(defun salesforce-visualforce-generate-page ()
  "Generate a new Visualforce page."
  (interactive)
  (let ((page-name (read-string "Visualforce page name: "))
        (page-label (read-string "Visualforce page label: "))
        (output-dir (salesforce-project-metadata-path salesforce-project-session 'page)))
    (salesforce-visualforce--generate-resource "page" page-name page-label
                                               output-dir ".page")))

(defun salesforce-visualforce-generate-component ()
  "Generate a new Visualforce component."
  (interactive)
  (let ((component-name (read-string "Visualforce component name: "))
        (component-label (read-string "Visualforce component label: "))
        (output-dir (salesforce-project-metadata-path salesforce-project-session 'component)))
    (salesforce-visualforce--generate-resource "component" component-name
                                               component-label output-dir
                                               ".component")))

;;; Test Execution

(defun salesforce-apex--get-result-test-job (job-id &optional poll-id)
  "Retrieve the result of an Apex test job by JOB-ID.
Optionally cancel POLL-ID timer when complete."
  (let ((buffer (current-buffer))
        (org-name (salesforce-project-org salesforce-project-session)))
    (salesforce-core--apex-process
     :args `("get" "test" "-i" ,job-id "-o" ,org-name
             "--code-coverage" "--json")
     :callback (lambda (json-instance)
                 (let* ((summary (map-nested-elt json-instance '("result" "summary")))
                        (outcome (map-elt summary "outcome"))
                        (alert-message (format "Unit Tests Run %s" outcome)))
                   (salesforce-core--alert alert-message))
                 (with-current-buffer buffer
                   (setq-local salesforce-apex--test-coverage
                               (map-nested-elt json-instance '("result" "coverage"))))
                 (when poll-id (cancel-timer poll-id))))))

(cl-defun salesforce-apex--execute-unit-test (&key test-cases test-level)
  "Execute specific unit tests with TEST-CASES and TEST-LEVEL."
  (let ((file-name (file-name-base)))
    (salesforce-core--apex-process
     :args `("run" "test" "--tests" ,test-cases "--test-level" ,test-level
             "--detailed-coverage" "--code-coverage" "--json")
     :callback
     (lambda (json-instance)
       (let* ((poll-id nil)
              (job-id (map-nested-elt json-instance '("result" "testRunId")))
              (callback (lambda (job)
                          (salesforce-apex--get-result-test-job job poll-id))))
         (if job-id
             (progn
               (salesforce-core--alert (format "%s class is running." file-name))
               (setq poll-id (run-at-time 60 nil callback job-id)))
           (salesforce-core--alert
            (format "Tests class run success with coverage %s"
                    (map-nested-elt json-instance
                                    '("result" "summary" "testRunCoverage"))))))))))

(defun salesforce-apex--retrieve-functions ()
  "Retrieve all function names in the current buffer.
FIXME: Improve function name extraction logic."
  (cl-loop for (_ . node) in (treesit-query-capture (treesit-buffer-root-node)
                                                 '((method_declaration) @function))
           collect (treesit-node-text 
                    (treesit-node-child-by-field-name node "name") t)))

(defun salesforce-apex-execute-method-test (node)
  "Execute a single unit test for the method at NODE."
  (interactive
   (list (treesit-parent-until 
       (treesit-node-at (point))
       (lambda (node)
         (string= (treesit-node-type node) "method_declaration")))))
  (when-let* ((func-name (treesit-node-text 
                          (treesit-node-child-by-field-name node "name")))
              (test-cases (format "%s.%s" (file-name-base) func-name)))
    (salesforce-apex--execute-unit-test :test-cases test-cases 
                                        :test-level "RunSpecifiedTests")))

(defun salesforce-apex-execute-test-class (file)
  "Execute all unit tests in the specified FILE."
  (interactive (list (file-name-base)))
  (salesforce-apex--execute-unit-test :test-cases file 
                                      :test-level "RunSpecifiedTests"))

(defun salesforce-apex-execute-local-tests ()
  "Run all test classes except those in the org managed package."
  (interactive)
  (salesforce-core--apex-process
   :args '("run" "test" "--test-level" "RunLocalTests" "--json")
   :callback (lambda (json-instance)
               (salesforce-apex--get-result-test-job
                (map-nested-elt json-instance '("result" "testRunId"))))))

;;; Lightning Development

(defun salesforce-lightning-local-lwc ()
  "Start the local server for Lightning Web Components (LWC)."
  (interactive)
  (salesforce-core--lightning-process
   :args '("lightning" "lwc" "start" "--json")
   :callback (lambda (_)
               (salesforce-core--alert "Start lwc local server success"))))

;;; Log Management

(defun salesforce-apex--time-format (format-string time-string)
  "Format TIME-STRING according to FORMAT-STRING."
  (format-time-string format-string
                      (encode-time (parse-time-string time-string))))

(defun salesforce-apex-consult--annotate (candidate)
  "Format a CANDIDATE string with properties for display in consult."
  (let* ((data candidate)
         (app (map-elt data "app"))
         (time (map-elt data "time"))
         (op (map-elt data "operation"))
         (size (map-elt data "log-length"))
         (status (map-elt data "status"))
         (id (map-elt data "log-id"))
         (len-text 10)
         (prop-time (propertize (salesforce-apex--time-format "%Y-%m-%d %H:%M:%S" time) 
                                'face 'org-time-grid))
         (prop-op (propertize (string-pad op len-text) 
                              'face 'font-lock-doc-markup-face))
         (prop-size (propertize (string-pad (format "%s" (/ size 1000)) len-text) 
                                'face 'font-lock-keyword-face))
         (prop-status (propertize (string-pad status len-text) 
                                  'face 'font-lock-keyword-face))
         (prefix (nerd-icons-octicon "nf-oct-log"))
         (suffix (concat (propertize (string-pad op len-text) 
                                     'face (if (string= status "success") 
                                               'font-lock-builtin-face 
                                             'font-lock-string-face))
                         prop-size
                         status 
                         prop-time)))
    `(,id ,prefix ,suffix)))

(defun salesforce-apex-prompt-log (callback)
  "Collect all logs and make prompt for selection.
Execute CALLBACK with selected candidate."
  (salesforce-core--apex-process
   :args '("list" "log" "--json")
   :callback
   (lambda (json-instance)
     (let* ((candidates (cl-loop for log-file across (map-elt json-instance "result")
                                 collect `("app" ,(map-elt log-file "Application")
                                           "time" ,(map-elt log-file "StartTime")
                                           "operation" ,(map-elt log-file "Operation")
                                           "log-length" ,(map-elt log-file "LogLength")
                                           "status" ,(map-elt log-file "Status")
                                           "log-id" ,(map-elt log-file "Id"))))
            (candidate (consult--read candidates
                                      :prompt "Log: "
                                      :category 'salesforce-log
                                      :require-match t
                                      :annotate #'salesforce-apex-consult--annotate)))
       (funcall callback candidate)))))


(defun salesforce-apex-soql-string-p (soql-string)
  "Check if SOQL-STRING is a valid SOQL query."
  (let ((soql-re "^SELECT [A-Za-z]+ FROM ([A-Za-z0-9_]+) "))
    (string-match-p soql-re soql-string)))

;; TODO: Implement these functions
(defun salesforce-apex--make-suitest-builder (path)
  "List unit test current project PATH."
  (let* ((transform-input (shell-quote-argument input t))
         (file-rule (format "--file=%s.el"
                            transform-input))
         (grep-args `(,@consult-grep-args
                      ,file-rule "-l"
                      "@istest" ,path))
         (command (consult--build-args grep-args)))

    (lambda (input)
      (pcase-let*
          ((`(,arg . ,opts) (consult--command-split input))
           (`(,re . ,hl) (consult--compile-regexp arga 'emacs t))))

      (cons command hl))))

(defun salesforce-apex-select-classes ()
  "Selection of classes in the project.
TODO: Implement this function."
  (interactive)
  (let ((builder (salesforce-apex--make-suitest-builder
                  (salesforce-project-metadata-path salesforce-project-session 'class))))
    (consult--read
     (consult--process-collection builder)
     :prompt "Suitest: "
     :lookup #'consult--lookup-member
     :require-match t
     :category 'salesforce-suitest
     :sort nil)))

(defun salesforce-apex-convert-test-result (test-result)
  "Convert TEST-RESULT to `salesforce-apex-test-result' instance."
  (let ((id (map-nested-elt test-result '("Id")))
        (class-name (map-nested-elt test-result '("ApexClass" "Name")))
        (coverage (map-nested-elt test-result '("testPass")))
        (tests-ran (map-nested-elt test-result '("testsRan")))
        (tests-passed (map-nested-elt test-result '("passing")))
        (tests-failed (map-nested-elt test-result '("failing"))))
    (cons id
          (make-instance 'salesforce-apex-test-result
                         :class class-name
                         :coverage coverage
                         :tests-failed tests-failed
                         :tests-passed tests-passed
                         :tests-ran tests-ran))))

(defun salesforce-apex-convert-test-results (test-results)
  "Convert TEST-RESULTS to list of `salesforce-apex-test-result' instances."
  (cl-loop for test-result across test-results
           collect (salesforce-apex-convert-test-result test-result)))

(defclass salesforce-apex-test-result (tablist-plus-data)
  ((class
    :initarg :class
    :initform nil
    :type string
    :documentation "Name of class.")
   (coverage
    :initarg :coverage
    :initform 0
    :type number
    :documentation "Percent of test coverage.")
   (tests-failed
    :initarg :tests-failed
    :initform 0
    :documentation "Number of tests failed.")
   (tests-passed
    :initarg :tests-passed
    :initform 0
    :documentation "Number of tests passed.")
   (tests-ran
    :initarg :tests-ran
    :initform 0
    :documentation "Number of tests ran.")))

(cl-defmethod tablist-plus-data-to-entry ((tests salesforce-apex-test-result) key)
  "Transform PROVIDER to tabulated-list entry format."
  (let* ((name (format "%s" (cloud-storage-provider-name provider)))
         (type (cloud-storage-utils-format-type-name
                (cloud-storage-provider-type provider)))
         (local-path (abbreviate-file-name
                      (or (cloud-storage-provider-local-path provider) "-")))
         (remote-path (cloud-storage-provider-remote-path provider))
         (auto-sync (if (cloud-storage-provider-auto-sync provider)
                        (format "Yes (%s)"
                                (cloud-storage-utils-format-interval
                                 (cloud-storage-provider-interval provider)))
                      "No"))
         (enabled (if (cloud-storage-provider-enabled provider) "✓" "✗"))
         (mount (cloud-storage-provider--human-mount provider)))
    (list key (vector name type local-path remote-path auto-sync enabled mount))))

(defun salesforce-apex-all-test ()
  "Run all tests on org."
  (emacs-pp-job
   (lambda ()
     (salesforce-core--apex-process
      :args '("run" "test" "-l" "RunAllTestsInOrg" "--synchronous" "--code-coverage" "--json")))
   (lambda (json-instance)
     (let* ((data (salesforce-apex-convert-test-results (map-nested-elt json-instance '("result" "tests"))))
            (table (make-instance 'tablist-plus-table
                                  [("Class Name" 30 t)
                                   ("Coverage" 10 t)
                                   ("Tests Ran" 10 t)
                                   ("Tests Passed" 12 t)
                                   ("Tests Failed" 12 t)]
                                  :data data)))
       (tablist-plus-table-render table)
       (pop-to-buffer (tablist-plus-table-buffer table))))))

(provide 'salesforce-apex)
;;; salesforce-apex.el ends here
