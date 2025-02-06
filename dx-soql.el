;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-core)

;;; Code:
(defun dx-soql--read-content ()
  "Read content that sf support for SOQL."
  (pcase (completing-read "Content type: " '(QUERY FILE REGION) nil t)
    ("FILE" (read-file-name "File name: "))
    ("REGION" (buffer-substring-no-properties (mark) (point)))
    (_ (let ((minibuffer-setup-hook `(,@minibuffer-setup-hook soql-ts-mode)))
         (read-from-minibuffer "SOQL: ")))))

(cl-defmacro dx-apex-get-result-test-job (&rest body &key job-id &allow-other-keys)
  "Get result tests"
  `(dx-process--make-handle-json
    :cmd (dx-build-sf-command dx-apex-command-alias "get" "test" "-i" ,job-id "--json")
    (let ((result-tests
           (mapconcat (lambda (result-test)
                        (let ((stack-trace (gethash "StackTrace" result-test))
                              (outcome (gethash "Outcome" result-test))
                              (error-message (gethash "Message" result-test))
                              (method-name (gethash "MethodName" result-test))
                              (class-name-test (dx-core--get-data-json "ApexClass.Name" result-test)))

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

                      (dx-core--get-data-json "result.tests" json-instance)
                      "\n")))
      (alert result-tests
             :title "Salesforce Alert")
      (when body
        ,@body))))

(cl-defun dx-soql--delete-bulk (sobject file &optional (message-after-process "Clear record success"))
  "Call API clear record come from file."
  (dx-start-process
   (lambda (_)
     (alert message-after-process
            :title "DX Alert"))
   dx-data-command-alias "delete" "bulk" "--sobject" sobject "--file" file "--json"))

(cl-defun dx-soql--export-bulk (soql format-type)
  "Call API export records with query string."
  (dx-start-process
    (lambda (_)
      (alert message-after-process
             :title "DX Alert"))
    dx-data-command-alias "export" "bulk" "--sobject" sobject "--file" file "--json"))

(defun dx-apex-run-local-tests ()
  "Run all tests class expect tests class in org managed package"
  (interactive)
  (dx-process--make-handle-json
   :cmd (dx-generate-command (list dx-apex-command-alias "run" "test" "--test-level" "RunLocalTests" "--json"))
   (dx-apex-get-result-test-job (job-id (dx-core--get-data-json "result.testRunId" json-instance)))))

(defun dx-server-local-lwc ()
  "Start lwc server on local."
  (interactive)
  (dx-make-async-process
   :cmd (dx-generate-command (list dx-legacy-alias "lightning" "lwc" "start" "--json"))
   (alert "Start lwc local server success"
          :title "Salesforce Alert")))

(provide 'dx-soql)
