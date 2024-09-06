;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-core)

(defun dx-soql-string ()
  "Fetch salesforce record by calling API through Salesforce CLI library"
  (interactive)
  (let* ((cache-dir (dx--get-cache-folder-path))
         ;; config local hook for minibuffer
         (minibuffer-history (cl-remove-if (lambda (item)
                                             (not (null (s-index-of item "SELECT"))))
                                           minibuffer-history))
         (minibuffer-mode-hook '(soql-ts-mode))
         (max-mini-window-height 5))

    (dx-execute-soql :query (completing-read "SOQL: " minibuffer-history nil 'require-match))))

(defun dx-fetch-record-through-file ()
  "Fetch record through file."
  (interactive)
  (let ((soql-file (read-from-minibuffer "SOQL-File: ")))

    (dx-execute-soql :file soql-file)))

(defun dx-site-list ()
  ""
  (interactive)
  (dx-execute-soql
   :query "SELECT PathPrefix, Domain.Domain, Domain.HttpsOption, Site.Status, Site.SiteType FROM DomainSite"))

(defun dx-fetch-dx-file
    ()
  "Retrieve org file from salesforce"
  (let* ((local-path (expand-file-name "~/.cache/sfdx"))
         ())

    ))

(cl-defmacro dx-apex-get-result-test-job (&rest body &key job-id &allow-other-keys)
  "Get result tests"
  (dx-make-process-json-async
   :cmd (dx-build-sf-command dx-apex-command-alias "get" "test" "-i" job-id "--json")
   `(let ((result-tests
           (mapconcat (lambda (result-test)
                        (let ((stack-trace (gethash "StackTrace" result-test))
                              (outcome (gethash "Outcome" result-test))
                              (error-message (gethash "Message" result-test))
                              (method-name (gethash "MethodName" result-test))
                              (class-name-test (dx-get-data-json "ApexClass.Name" result-test)))

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

                      (dx-get-data-json "result.tests" json-instance)
                      "\n")))
      (alert result-tests
             :title "Salesforce Alert")
      (when body
        ,@body))))

(defun dx-apex-run-test-class ()
  "Run unit test for class"
  (interactive)
  (dx-make-process-json-async
   :cmd (dx-build-sf-command dx-apex-command-alias "run" "test" "--tests" (file-name-base) "--test-level" "RunSpecifiedTests" "--json")
   (let* ((poll-id nil)
          (closure (lambda (job-id)
                     (dx-apex-get-result-test-job
                      :job-id job-id
                      (cancel-timer poll)))))
     (cond ((= (plist-get json-instance :status) 0)
            (alert (format "%s class is running." `,(file-name-base))
                   :title "DX Alert")
            (setq poll-id (run-at-time 60 t closure (dx-get-data-json "result.testRunId" json-instance))))
           (t (funcall #'dx-handle-process-error--json json-instance))))))

(defun dx-apex-run-local-tests ()
  "Run all tests class expect tests class in org managed package"
  (interactive)
  (dx-make-process-json-async
   :cmd (dx-generate-command (list dx-apex-command-alias "run" "test" "--test-level" "RunLocalTests" "--json"))
   (dx-apex-get-result-test-job (job-id (dx-get-data-json "result.testRunId" json-instance)))))



(defun dx-server-local-lwc ()
  "Start lwc server on local."
  (interactive)
  (dx-make-async-process
   :cmd (dx-generate-command (list dx-legacy-alias "lightning" "lwc" "start" "--json"))
   (alert "Start lwc local server success"
          :title "Salesforce Alert")))
