;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-core)
(require 'soql-ts-mode)
(require 'treesit)

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
  (dx-execute-soql :file (read-file-name "SOQL File: ")))

(cl-defmacro dx-apex-get-result-test-job (&rest body &key job-id &allow-other-keys)
  "Get result tests"
  `(dx-make-process-json-async
    :cmd (dx-build-sf-command dx-apex-command-alias "get" "test" "-i" ,job-id "--code-coverage" "--json")
    ,@body))

(defmacro dx-tests-execute (&rest test-cases)
  `(dx-make-process-json-async
    :cmd (dx-build-sf-command dx-apex-command-alias
                              "run"
                              "test"
                              ,@test-cases
                              "--test-level"
                              "RunSpecifiedTests"
                              "--detailed-coverage"
                              "--code-coverage"
                              "--json")
    (let* ((poll-id nil)
           (job-id (dx-get-data-json "result.testRunId" json-instance))
           (callback (lambda (job-id)
                       (dx-apex-get-result-test-job
                        :job-id job-id
                        (cond ((= (plist-get json-instance :status) 100)
                               (alert (dx-get-data-json "result.tests.0.StackTrace" json-instance)
                                      :title "DX Alert"
                                      :severity 'urgent))
                              (t (alert (format "Tests class run success with coverage %s"
                                                (dx-get-data-json "result.summary.testRunCoverage" json-instance))
                                        :title "DX Alert")))
                        (cancel-timer poll-id)))))
      (cond ((and (= (plist-get json-instance :status) 0)
                job-id)
             (alert (format "%s class is running." `,(file-name-base))
                    :title "DX Alert")
             (setq poll-id (run-at-time 60 t callback job-id)))
            ((= (plist-get json-instance :status) 0)
             (alert (format "Tests class run success with coverage %s"
                            (dx-get-data-json "result.summary.testRunCoverage" json-instance))
                    :title "DX Alert"))
            (t (funcall #'dx-handle-process-error--json json-instance))))))

(defun dx-apex-run-test-class ()
  "Run unit test for class"
  (interactive)
  (dx-tests-execute "--tests" (file-name-base)))

(defun dx-apex-run-local-tests ()
  "Run all tests class expect tests class in org managed package"
  (interactive)
  (dx-make-process-json-async
   :cmd (dx-generate-command (list dx-apex-command-alias "run" "test" "--test-level" "RunLocalTests" "--json"))
   (dx-apex-get-result-test-job (job-id (dx-get-data-json "result.testRunId" json-instance)))))

(defun dx-apex-run-method-test (node)
  "Execute method test."
  (interactive
   (list (treesit-parent-until (treesit-node-at (point))
                            (lambda (node)
                              (string= (treesit-node-type node) "method_declaration")))))
  (when-let ((func-name (treesit-node-text (treesit-node-child-by-field-name node "name"))))
    (dx-tests-execute "--tests" (format "%s.%s" (file-name-base) func-name))))

(defun dx-server-local-lwc ()
  "Start lwc server on local."
  (interactive)
  (dx-make-async-process
   :cmd (dx-generate-command (list dx-legacy-alias "lightning" "lwc" "start" "--json"))
   (alert "Start lwc local server success"
          :title "Salesforce Alert")))

(provide 'dx-query)
