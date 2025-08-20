;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'salesforce-core)

;;; Code:
(cl-defmacro salesforce-apex-get-result-test-job (&rest body &key job-id &allow-other-keys)
  "Get result tests"
  `(salesforce-core--process--make-handle-json
    :cmd (salesforce-build-sf-command salesforce-apex-command-alias "get" "test" "-i" ,job-id "--json")
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
      (when body
        ,@body))))

(cl-defun salesforce-soql--delete-bulk (sobject file &optional (message-after-process "Clear record success"))
  "Call API clear record come from file."
  (salesforce-core--data-process
   (lambda (_)
     (salesforce-core-alert message-after-process))
   :cmd `("delete" "bulk" "--sobject" ,sobject "--file" ,file "--json")))

(cl-defun salesforce-soql--export-bulk (soql format-type)
  "Call API export records with query string."
  (salesforce-core--data-process
   (lambda (_)
     (salesforce-core-alert message-after-process))
   :cmd `("export" "bulk" "--sobject" ,sobject "--file" ,file "--json")))

(provide 'salesforce-soql)
