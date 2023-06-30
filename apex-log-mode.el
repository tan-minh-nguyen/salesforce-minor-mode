(defface salesforce-details-log-face '((t :foreground "#2D4356"))
  "Face for detail in log file"
  :group 'salesforce-log)

(defface salesforce-groverment-log-face '((t :foreground "#6DA9E4"))
  "Face for groverment in log file"
  :group 'salesforce-log)

(defface salesforce-execute-log-face '((t :foreground "#6C9BCF"))
  "Face for execute in log file"
  :group 'salesforce-log)

(defface salesforce-run-mode-face '((t :foreground "#576CBC"))
  "Face for running mode in log file"
  :group 'salesforce-log)

(defface salesforce-log-text-face '((t :foreground "#EEEEEE"))
  "Face for running mode in log file"
  :group 'salesforce-log)

(defface salesforce-log-line-face '((t :foreground "#2DCDDF"))
  "Face for line code in log file"
  :group 'salesforce-log)

(defface salesforce-log-timestamp-face '((t :foreground "#4D4D4D"))
  "Face for timestamp in log file"
  :group 'salesforce-log)

(defface salesforce-groverment-value-face '((t :foreground "#6C9BCF"))
  "Face for groverment value in log file"
  :group 'salesforce-log)

(defface salesforce-groverment-limit-face '((t :foreground "#D21312"))
  "Face for groverment limit in log file"
  :group 'salesforce-log)

(defcustom salesforce-function-event-keywords '("SYSTEM_METHOD_EXIT"
                                                "SYSTEM_METHOD_ENTRY"
                                                "METHOD_ENTRY"
                                                "METHOD_EXIT")
  ""
  :type 'list
  :group 'salesforce-log)

(defcustom salesforce-groverment-event-keywords '("HEAP_ALLOCATE"
                                                  "LIMIT_USAGE_FOR_NS"
                                                  "Number of SOQL queries"
                                                  "Number of query rows"
                                                  "Number of SOSL queries"
                                                  "Number of DML statements"
                                                  "Number of Publish Immediate DML"
                                                  "Number of DML rows"
                                                  "Maximum CPU time"
                                                  "Maximum heap size"
                                                  "Number of callouts"
                                                  "Number of Email Invocations"
                                                  "Number of future calls"
                                                  "Number of queueable jobs added to the queue"
                                                  "Number of Mobile Apex push calls"
                                                  "CUMULATIVE_LIMIT_USAGE"
                                                  "CUMULATIVE_LIMIT_USAGE_END")
  ""
  :type 'list
  :group 'salesforce-log)

(defcustom salesforce-execute-event-keywords '("STATEMENT_EXECUTE"
                                               "CODE_UNIT_STARTED"
                                               "CODE_UNIT_FINISHED"
                                               "EXECUTION_STARTED"
                                               "EXECUTION_FINISHED")
  ""
  :type 'list
  :group 'salesforce-log)

(defcustom salesforce-mode-event-keywords '("SYSTEM_MODE_ENTER"
                                            "SYSTEM_MODE_EXIT")
  ""
  :type 'list
  :group 'salesforce-log)

(defcustom log-details-keywords-regex "\\(\\s\\S\\)"
  ""
  :group 'salesforce-log)

(setq salesforce-font-lock
      (let ((salesforce-function-event-keywords-regex (regexp-opt salesforce-function-event-keywords 'word))
            (salesforce-groverment-event-keywords-regex (regexp-opt salesforce-groverment-event-keywords 'word))
            (salesforce-execute-event-keywords-regex (regexp-opt salesforce-execute-event-keywords 'word))
            (salesforce-mode-event-keywords-regex (regexp-opt salesforce-mode-event-keywords 'word)))

        `((,salesforce-groverment-event-keywords-regex . 'salesforce-groverment-log-face)
          (,salesforce-execute-event-keywords-regex . 'salesforce-execute-log-face)
          (,salesforce-function-event-keywords-regex . 'font-lock-function-name-face)
          (,salesforce-mode-event-keywords-regex . 'salesforce-run-mode-face)
          ("\\([0-9]+\\) out of \\([0-9]+\\)" . ((1 'salesforce-groverment-value-face) (2 'salesforce-groverment-limit-face)))
          ("[0-9]\\{0,2\\}:[0-9]\\{0,2\\}:[0-9]\\{0,2\\}.[0-9]\\{0,3\\}" . 'salesforce-log-timestamp-face)
          ("\\[\\([0-9]+\\)\\]" . (1 'salesforce-log-line-face)))))



(define-derived-mode apex-log-mode fundamental-mode "apex-log"
  "Major mode for log salesforce."

  (setq font-lock-defaults '((salesforce-font-lock))))

(provide 'apex-log-mode)
