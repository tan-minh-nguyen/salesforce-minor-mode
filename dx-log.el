;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-config)
(require 'dx-core)

(defun dx-log-get-log ()
  "Fetch log."
  (interactive)
  (dx--log-fetch-logs
   (let ((log-list-map (make-hash-table :test #'equal)))
     (dolist (data log-list)
       (puthash  (dx-get-data-json "Id" data) data log-list-map))

     (dx-make-process-json-async
      :cmd
      (dx-build-sf-command dx-apex-command-alias
                           "get"
                           "log"
                           "--log-id"
                           (consult--read (hash-table-keys log-list-map)
                                          :prompt "Log: "
                                          :require-match t
                                          :annotate (lambda (item)
                                                      (let* ((data (gethash item log-list-map))
                                                             (size (/ (dx-get-data-json "LogLength" data) (* 1024 1024)))
                                                             (op (dx-get-data-json "Operation" data))
                                                             (time (format-time-string "%Y-%m-%d" (parse-time-string (dx-get-data-json "StartTime" data)))))

                                                        (list (propertize item 'face '(:width 10 :foreground "yellow")) nil (format "%s:%s" size time)))))
                           "--json")
      (cond ((= (plist-get json-instance :status) 0)
             (with-current-buffer (find-file-noselect (format "%s.log" (concat (dx--get-log-dir-path) log-id)))
               (erase-buffer)
               (insert (dx-get-data-json "result.0.log" json-instance))
               (save-buffer))
             (alert (format "Fetch log %s success" log-id)
                    :title "DX Alert"))
            (t (funcall #'dx-handle-process-error--json json-instance)))))))

(defun dx--convert-log-to-obarray (log-list attrs)
  "Generate obarray from plist."
  (let ((array (obarray-make (* (length log-list) (length attrs)))))

    (dolist (log-data log-list)
      (dolist (attr attrs)
        (obarray-put array (plist-get log-data attr))))))

(defmacro dx--log-fetch-logs (&rest body)
  "Fetch all logs list."
  `(dx-make-process-json-async
    :cmd
    (dx-build-sf-command dx-apex-command-alias "log" "list" "--json")
    (cond ((= (plist-get json-instance :status) 0)
           (let* ((log-list (dx-get-data-json "result" json-instance)))

             ,@body))
          (t (funcall #'dx-handle-process-error--json json-instance)))))

(defun dx-clear-log ()
  "Clear all apex log on org."
  (interactive)

  (dx-org-alias-list
   (let ((temp-file (make-temp-file "log" nil ".csv"))
         (org-name (completing-read "Org name: " org-list nil 'require-match dx-org-name)))

     (dx-make-chain-process
      (list :cmd (dx-build-sf-command
               dx-data-command-alias "query" "--query" "SELECT Id FROM ApexLog" "-t" "-r" "csv" "-o" org-name)
         :callback
         (lambda (&rest arg)
           ;; Save data to temp file.
           (with-current-buffer dx-process-success-buffer
             (write-region (point-min) (point-max) temp-file))))

      ;; Clear log on org.
      (list :cmd
         (dx-build-sf-command
          dx-data-command-alias "delete" "bulk" "--sobject" "ApexLog" "--file" temp-file "--json")
         :callback
         (alert "Clear log success"
                :title "DX Alert"))))))

(provide 'dx-log)
