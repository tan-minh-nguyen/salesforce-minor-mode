;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-config)
(require 'dx-core)
(require 'dx-soql)

(defun dx-log-view-log ()
  "Fetch log."
  (interactive)
  (dx-log--fetch-logs
   (lambda (log-list)
     (let ((log-map (cl-loop for data in log-list
                             with log-map = (make-hash-table :test #'equal)
                             do (puthash (dx-core--get-data-json "Id" data) data log-map)
                             finally return log-map))
           (read-log (consult--read (hash-table-keys log--map)
                                    :prompt "Log: "
                                    :require-match t
                                    :annotate (lambda (item)
                                                (funcall #'dx-log--annotation item log-map)))))

       (dx-core--apex-process
        :cmd `("get" "log" "--log-id" ,read-log "--json")
        (let ((file (create-file-buffer (format "%s%s.log" (dx--get-log-dir-path) read-log))))
          (with-current-buffer file
            (with-silent-modifications
              (setf (buffer-string) (dx-core--get-data-json "result.0.log" json-instance))))
          (alert (format "Fetch log %s success" read-log)
                 :title "DX Alert")))))))

(defun dx-log--annotation (item log-map)
  "Build log annotate"
  (let* ((data (gethash item log-map))
         (size (/ (dx-core--get-data-json "LogLength" data) (* 1024 1024)))
         (op (dx-core--get-data-json "Operation" data))
         (time (format-time-string "%Y-%m-%d" (parse-time-string (dx-core--get-data-json "StartTime" data)))))

    (list (propertize item 'face '(:width 10 :foreground "yellow")) nil (format "%s:%s" size time))))

(defun dx--convert-log-to-obarray (log-list attrs)
  "Generate obarray from plist."
  (let ((array (obarray-make (* (length log-list) (length attrs)))))

    (dolist (log-data log-list)
      (dolist (attr attrs)
        (obarray-put array (plist-get log-data attr))))))

(defun dx-log--fetch-logs (callback)
  "Fetch all logs list."
  (dx-core--apex-process
   :cmd ("log" "list" "--json")
   (funcall callback (dx-core--get-data-json "result" json-instance))))

(defun dx-log-clear ()
  "Clear all apex log on org."
  (interactive)
  (dx-org--fetch-org-list
   (lambda (org-list)
     (let ((temp-file (make-temp-file "log" nil ".csv"))
           (org-name (completing-read "Org alias: " org-list nil nil dx-org-name)))

       (dx-core--data-process
        :cmd `("query" "--query" "SELECT Id FROM ApexLog" "-t" "-r" "csv" "-o" ,org-name)
        ;; Save data to temp file.
        (write-region (with-current-buffer (process-buffer json-instance) (buffer-string)) nil temp-file)

        ;; Clear log on org.
        (dx-soql--delete-bulk "ApexLog" temp-file))))))

(provide 'dx-log)
