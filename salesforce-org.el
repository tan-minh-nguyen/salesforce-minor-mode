;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'salesforce-core)
(require 'salesforce-soql)

;;TODO: create transient menu

(defun salesforce-org-specific-open (org)
  "Use a specific user name to open org"
  (interactive (list (ctbl:cp-get-selected-data-cell (ctbl:cp-get-component))))
  (salesforce-core--org-process
   :cmd `("org" "open" "--json" "-o" ,(or org (read-string "Org: ")) "-r")
   (shell-command (string-join `(,salesforce-default-browser
                                 ,(salesforce-core--get-data-json "result.url" json-instance))
                               " "))))

(defun salesforce-org-open-current ()
  "Open current default org."
  (interactive)
  (salesforce-core--org-process
   :cmd '("org" "open" "--json" "-r")
   (async-start (lambda ()
                  (shell-command (string-join `(,salesforce-default-browser
                                                ,(salesforce-core--get-data-json "result.url" json-instance))
                                              " ")))
                'ignore)))

(defun salesforce-org-display-all-orgs ()
  (interactive)
  (salesforce-org--fetch-users-org "other"))

(defun salesforce-org-display-all-devhubs ()
  (interactive)
  (salesforce-org--fetch-users-org "devhubs"))

(defun salesforce-org-authorize ()
  "Using web login to authorize to org."
  (interactive)
  (let* ((org-list '("SANBOX/SCRATCH" "PRODUCTION" "CUSTOM URL"))
         (org-select (completing-read "Edittion: " org-list nil 'require-match))
         (org-url (pcase org-select
                    ("SANBOX/SCRATCH"
                     "https://test.salesforce.com")
                    ("PRODUCTION"
                     "https://login.salesforce.com")
                    (_ (read-from-minibuffer "URL: ")))))

    (salesforce-org--list 
     (lambda (org-list)
       (salesforce-core--org-process
        :cmd (list "login" "web" "-a" (completing-read "Alias: " org-list nil nil) "--instance-url" org-url "--set-default" "--json")
        (alert (format "Authorize to %s success" (salesforce-core--get-data-json "result.username" json-instance)) :title "Salesforce Alert"))))))

(defun salesforce-org-note-news ()
  "What news on dx cli."
  (interactive)
  (with-current-buffer (pop-to-buffer (get-buffer-create "*sf-note-news*"))
    (delete-selection-mode 1)

    (insert (shell-command-to-string "sf whatsnew"))))

(defun salesforce-org-change-connection ()
  "Change default connection org."
  (interactive)
  (salesforce-org--list (lambda (org-list)
                         (let ((org (completing-read "Org name: " org-list)))
                           (salesforce-core--config-process
                            :cmd `("set" "target-org" ,org "--json")
                            (let ((org-name (salesforce-core--get-data-json "result.successes.0.value" json-instance)))
                              (alert (format "Change to %s success" (setq salesforce-org-name org-name)) :title "DX Alert")))))))

(defun salesforce-org--get-status ()
  "Checking connect status on current org"
  (salesforce-core--org-process
   :cmd `("display" "--json")
   (when (string= (salesforce-core--get-data-json "result.connectedStatus" json-instance)
                  "RefreshTokenAuthError")
     (alert "Token expired !!" :title "Salesforce Alert"))))

(defun salesforce-org--fetch-users-org (org-type)
  "Show all user connected organizations."
  (salesforce-core--org-process
   :cmd '("list" "--json")
   (pop-to-buffer
    (salesforce-table--create-table
     :model
     (salesforce-table--make-table-mode
      :column-header
      (mapcar (lambda (column-name)
                (list :title column-name :align 'left :max-width '50))
              salesforce-org-list-header-display)
      :data
      (mapcar (lambda (data)
                (mapcar (lambda (column-name)
                          (let ((value (plist-get (intern (format ":%s" column-name)) data)))

                            (pcase value
                              (:false "false")
                              (:true  "true")
                              (_ value))))
                        salesforce-org-list-header-display))
              (salesforce-core--get-data-json
               (concat "result." org-type) json-instance))))
    :buffer salesforce-dedicated-window-right)))


(defun salesforce-org-view-log ()
  "View specific log."
  (interactive)
  (salesforce-org--fetch-logs
   (lambda (log-list)
     (let ((log-map (cl-loop for data in log-list
                             with log-map = (make-hash-table :test #'equal)
                             do (puthash (salesforce-core--get-data-json "Id" data) data log-map)
                             finally return log-map))
           (read-log (consult--read (hash-table-keys log--map)
                                    :prompt "Log: "
                                    :require-match t
                                    :annotate (lambda (item)
                                                (funcall #'salesforce-org--annotation item log-map)))))

       (salesforce-core--apex-process
        :cmd `("get" "log" "--log-id" ,read-log "--json")
        (let ((file (create-file-buffer (format "%s%s.log" (salesforce--get-log-dir-path) read-log))))
          (with-current-buffer file
            (with-silent-modifications
              (setf (buffer-string) (salesforce-core--get-data-json "result.0.log" json-instance))))
          (alert (format "Fetch log %s success" read-log)
                 :title "DX Alert")))))))

(defun salesforce-org--annotation (item log-map)
  "Build log annotate"
  (let* ((data (gethash item log-map))
         (size (/ (salesforce-core--get-data-json "LogLength" data) (* 1024 1024)))
         (op (salesforce-core--get-data-json "Operation" data))
         (time (format-time-string "%Y-%m-%d" (parse-time-string (salesforce-core--get-data-json "StartTime" data)))))

    (list (propertize item 'face '(:width 10 :foreground "yellow")) nil (format "%s:%s" size time))))

(defun salesforce-org--convert-log-to-obarray (log-list attrs)
  "Generate obarray from plist."
  (let ((array (obarray-make (* (length log-list) (length attrs)))))

    (dolist (log-data log-list)
      (dolist (attr attrs)
        (obarray-put array (plist-get log-data attr))))))

(defun salesforce-org--fetch-logs (callback)
  "Fetch all logs list."
  (salesforce-core--apex-process
   :cmd ("log" "list" "--json")
   (funcall callback (salesforce-core--get-data-json "result" json-instance))))

;; TODO: Clear log with input date condition
(defun salesforce-org-clear-log-data ()
  "Clear all apex log on org."
  (interactive)
  (salesforce-org--list
   (lambda (org-list)
     (let ((temp-file (make-temp-file "log" nil ".csv"))
           (org-name (completing-read "Org alias: " org-list nil nil salesforce-org-name)))

       (salesforce-core--data-process
        :cmd `("query" "--query" "SELECT Id FROM ApexLog" "-t" "-r" "csv" "-o" ,org-name)
        ;; Save data to temp file.
        (write-region (with-current-buffer json-instance (buffer-string)) nil temp-file)

        ;; Clear log on org.
        (salesforce-soql--delete-bulk "ApexLog" temp-file))))))

(defun salesforce-org--clear-cache ()
  "Clear the org list cache."
  (interactive)
  (setq salesforce-core--org-list-cache nil)
  (message "Org list cache cleared"))

(defun salesforce-org--list-build-format-1 (json-instance)
  "Build list of orgs from json response."
  (when-let* ((org-types (salesforce-core--get-data-json "result" json-instance))
              (org-data (cl-loop for (_ orgs) on org-types by #'cddr
                                 append (cl-loop for org across orgs
                                                 collect `(:username ,(salesforce-core--get-data-json "username" org)
                                                                     :alias ,(salesforce-core--get-data-json "alias" org)
                                                                     :isDevHub ,(salesforce-core--get-data-json "isDevHub" org)
                                                                     :orgType ,(salesforce-core--get-data-json "orgType" org))))))
    ;; Update cache
    (setq salesforce-core--org-list-cache 
          `((timestamp . ,(time-to-seconds))
            (data . ,org-data)))
    ;; Return filtered results
    org-data))

(cl-defun salesforce-org--list (finish-func &key org-type sync)
  "Fetch org information."
  (let ((data (salesforce-org--list-1 :finish-func finish-func
                              :org-type org-type
                              :sync sync)))
    (when (processp data)
      (ignore-errors (salesforce-org--list-build-format-1
                      (json-parse-string (with-current-buffer (process-buffer data)
                                           (buffer-string))
                                         :object-type 'plist))))))

(cl-defun salesforce-org--list-1 (&key finish-func org-type sync)
  "Internal process that fetch list of available Salesforce orgs with caching.
Optional ORG-TYPE can be 'devhub' or 'scratch' to filter orgs.
Returns list of org aliases or nil on error."
  (let* ((cached (assoc 'timestamp salesforce-core--org-list-cache))
         (now (time-to-seconds))
         (cache-valid (and cached 
                         (< (- now (cdr cached)) 
                            salesforce-core--org-list-cache-ttl))))
    (if cache-valid
        (let ((orgs (assoc 'data salesforce-core--org-list-cache)))
          (cond (finish-func
                 (funcall finish-func
                          (if org-type
                              (cl-loop for org in (cdr orgs)
                                       when (or (and (eq org-type 'devhub)
                                                  (plist-get org :isDevHub))
                                               (and (eq org-type 'scratch)
                                                  (string= (plist-get org :orgType) "ScratchOrg")))
                                       collect (plist-get org :alias))
                            (mapcar (lambda (org) (plist-get org :alias)) (cdr orgs)))))
                (mapcar (lambda (org) (plist-get org :alias)) (cdr orgs))))

      (let ((default-directory (or (projectile-project-root) default-directory)))
        (salesforce-core--org-process
         :cmd `("list" "--skip-connection-status" "--json")
         :sync sync
         (unless sync
           (let ((org-data (salesforce-org--list-build-format-1 json-instance)))
             (funcall finish-func
                      (if org-type
                          (cl-loop for org in org-data
                                   when (or (and (eq org-type 'devhub)
                                              (plist-get org :isDevHub))
                                           (and (eq org-type 'scratch)
                                              (string= (plist-get org :orgType) "ScratchOrg")))
                                   collect (plist-get org :alias))
                        (mapcar (lambda (org) (or (plist-get org :alias) (plist-get org :username))) org-data))))))))))

(cl-defun salesforce-org--status (&key finish-func org)
  "Check current org status."
  (salesforce-core--org-process
   :cmd `("display" "-o" ,(or org salesforce-org-name) "--json")
   (funcall finish-func json-instance)))

(defun salesforce-org-retrieve-metatdata-sobjects ()
  "Retrieves sobjects metadata on org.")

(provide 'salesforce-org)
