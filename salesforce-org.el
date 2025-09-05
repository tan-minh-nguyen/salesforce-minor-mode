;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'salesforce-core)
(require 'salesforce-soql)

;;TODO: create transient menu

(defun salesforce-org-open ()
  "Open selection org."
  (interactive)
  (salesforce-org-prompt-org
   (lambda (org)
     (salesforce-core--org-process
      :cmd `("org" "open" "--json" "-o" ,org "-r")
      (browse-url-generic (salesforce-core--get-data-json "result.url" json-instance))))))

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

    (salesforce-org-prompt-org 
     (lambda (org)
       (salesforce-core--org-process
        :cmd `("login" "web" "-a" ,org "--instance-url" ,org-url "--set-default" "--json")
        (salesforce-core--alert (format "Authorize to %s success"
                                        (salesforce-core--get-data-json "result.username" json-instance))))))))

(defun salesforce-org-note-news ()
  "What news on dx cli."
  (interactive)
  (with-current-buffer (pop-to-buffer (get-buffer-create "*sf-note-news*"))
    (delete-selection-mode 1)

    (insert (shell-command-to-string "sf whatsnew"))))

(defun salesforce-org-change-connection ()
  "Change default connection org."
  (interactive)
  (salesforce-org-prompt-org
   (lambda (org)
     (salesforce-core--config-process
      :cmd `("set" "target-org" ,org "--json")
      (let ((org-name (salesforce-core--get-data-json "result.successes.0.value" json-instance)))
        (salesforce-core--alert (format "Change to %s success" (setq salesforce-org-name org-name))))))))

(defun salesforce-org--get-status ()
  "Checking connect status on current org"
  (salesforce-core--org-process
   :cmd `("display" "--json")
   (when (string= (salesforce-core--get-data-json "result.connectedStatus" json-instance)
                  "RefreshTokenAuthError")
     (salesforce-core--alert "Token expired !!"))))

;; TODO: Refactor this, maybe use export to get a list of logs and convert to an org-table for selection.
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
          (salesforce-core--alert (format "Fetch log %s success" read-log))))))))

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
(defun salesforce-org-delete-logs ()
  "Clear logs from the connected Salesforce org."
  (interactive)
  (let ((temp-file (make-temp-file "log" nil ".csv")))

    (salesforce-data--export-bulk
     `("-q" "SELECT Id FROM ApexLog" "--result-format=csv" "--output-file" ,temp-file)
     :callback
     (lambda (_)
       ;; Save data to temp file.
       ;; (write-region (with-current-buffer json-instance (buffer-string)) nil temp-file)

       ;; Clear log on org.
       (salesforce-data--delete-bulk
        `("--sobject" "ApexLog" "--file" ,temp-file)
        :callback (lambda (_)
                    (salesforce-core-alert "Deleting log data succeeded")))))))

(defun salesforce-org--complete-candidate (orgs input pred action)
  "Completion table for ORGS.
Handles INPUT, PRED, ACTION according to `completing-read' contract."
  (if (eq action 'metadata)
      `(metadata (category . salesforce-org))
    (complete-with-action action (mapcar (lambda (org)
                                           (or (plist-get org :alias)
                                              (plist-get org :username)))
                                         orgs)
                          input pred)))

(defun salesforce-org-prompt-org (callback)
  "Selection available orgs that authorized.
CALLBACK: The function to get the organization is selected."
  (salesforce-org--fetch-list-org
   :finish-func (lambda (org-list)
                  (funcall callback (completing-read "Org: " (apply-partially #'salesforce-org--complete-candidate org-list))))
   :fields '(:alias :username :instanceUrl :connectedStatus :isDevHub)))

(defun salesforce-org--list-build-format (json-instance)
  "Build a list of orgs from the JSON-INSTANCE response and update the cache."
  (let* ((org-types (salesforce-core--get-data-json "result" json-instance))
         (org-data (cl-loop for (type orgs) in `((other ,(plist-get org-types :other))
                                              (sandboxs ,(plist-get org-types :sandboxs))
                                              (nonScratchOrgs ,(plist-get org-types :nonScratchOrgs))
                                              (devHubs ,(plist-get org-types :devHubs))
                                              (scratchOrgs ,(plist-get org-types :scratchOrgs)))
                            collect `(,type . ,(cl-loop for org across orgs
                                                        collect (seq-difference org `(:accessToken ,(plist-get org :accessToken))))))))
    ;; save org data to cache for reuse
    (when org-data
      (setq salesforce-core--org-list-cache
            `((timestamp . ,(time-to-seconds))
              (data . ,org-data))))
    org-data))

(defun salesforce-org--filter (orgs org-type)
  "Filter ORGS by ORG-TYPE (nil, 'devhub or 'scratch)."
  (if org-type
      (assoc-default org-type orgs)
    (cl-loop for (_ . items) in orgs
             append items)))

(defun salesforce-org--extract-fields (orgs fields)
  "Return ORGS with only FIELDS."
  (mapcar (lambda (org)
            (mapcar (lambda (f) `(,f . ,(plist-get org f))) fields))
          orgs))

(cl-defun salesforce-org--fetch-list-org (&key finish-func org-type sync fields)
  "Fetch Salesforce orgs, using cache when valid.

Options:
- FINISH-FUNC: Callback to receive results (async mode).
- ORG-TYPE: Filter orgs by type ('devhub, 'scratch, 'scratchorgs, 'nonscratchorgs, 'other).
- SYNC: Run synchronously if non-nil.
- FIELDS: Fields to return (default: (:alias))."
  (let* ((cached (assoc 'timestamp salesforce-core--org-list-cache))
         (now (time-to-seconds))
         (cache-valid (and cached
                         (< (- now (cdr cached))
                            salesforce-core--org-list-cache-ttl))))
    (if cache-valid
        (let* ((orgs (cdr (assoc 'data salesforce-core--org-list-cache)))
               (filtered (salesforce-org--filter orgs org-type)))
          (if finish-func
              (funcall finish-func (salesforce-org--extract-fields filtered (or fields '(:alias))))
            (salesforce-org--extract-fields filtered (or fields '(:alias)))))
      ;; not cached: fetch
      (let* ((process (salesforce-core--org-process
                       :cmd `("list" "--json")
                       :sync sync
                       (unless sync
                         (when-let ((orgs (salesforce-org--list-build-format json-instance)))
                           (funcall finish-func (salesforce-org--filter orgs org-type)))))))

        (when-let* ((_ (processp process))
                    (json-instance (salesforce-core-parse-buffer-json (process-buffer process)))
                    (filtered (salesforce-org--filter (salesforce-org--list-build-format json-instance) org-type)))
          (salesforce-org--extract-fields filtered (or fields '(:alias))))))))

(cl-defun salesforce-org-list (finish-func &key org-type sync)
  "Fetch Salesforce orgs and pass aliases/usernames to FINISH-FUNC.

Options:
- ORG-TYPE: Filter orgs by type ('devhub, 'scratch, 'scratchorgs, 'nonscratchorgs, 'other).
- SYNC: Run synchronously if non-nil."
  (salesforce-org--fetch-list-org
   :finish-func (lambda (orgs)
                  (funcall finish-func
                           (mapcar (lambda (org)
                                     (or (assoc-default :alias org)
                                        (assoc-default :username org)))
                                   orgs)))
   :org-type org-type
   :fields '(:alias :username)
   :sync sync))

(cl-defun salesforce-org-status (&key finish-func org)
  "Check current org status."
  (salesforce-core--org-process
   :cmd `("display" "-o" ,(or org salesforce-org-name) "--json")
   (funcall finish-func json-instance)))

(defun salesforce-org-retrieve-metatdata-sobjects ()
  "Retrieves sobjects metadata on org.")

(provide 'salesforce-org)
