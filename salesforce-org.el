;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'salesforce-core)
(require 'salesforce-soql)

;;TODO: create transient menu

(defun salesforce-org-open ()
  "Open selection org."
  (interactive)
  (salesforce-org-list
   (lambda (org-list)
     (salesforce-core--org-process
      :cmd `("org" "open" "--json" "-o" ,(completing-read "Org: " org-list) "-r")
      (browse-url-generic (salesforce-core--get-data-json "result.url" json-instance))))))

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

    (salesforce-org-list 
     (lambda (org-list)
       (salesforce-core--org-process
        :cmd (list "login" "web" "-a" (completing-read "Alias: " org-list nil nil) "--instance-url" org-url "--set-default" "--json")
        (salesforce-core--alert (format "Authorize to %s success" (salesforce-core--get-data-json "result.username" json-instance))))))))

(defun salesforce-org-note-news ()
  "What news on dx cli."
  (interactive)
  (with-current-buffer (pop-to-buffer (get-buffer-create "*sf-note-news*"))
    (delete-selection-mode 1)

    (insert (shell-command-to-string "sf whatsnew"))))

(defun salesforce-org-change-connection ()
  "Change default connection org."
  (interactive)
  (salesforce-org-list
   (lambda (org-list)
     (let ((org (completing-read "Org name: " org-list)))
       (salesforce-core--config-process
        :cmd `("set" "target-org" ,org "--json")
        (let ((org-name (salesforce-core--get-data-json "result.successes.0.value" json-instance)))
          (salesforce-core--alert (format "Change to %s success" (setq salesforce-org-name org-name)))))))))

(defun salesforce-org--get-status ()
  "Checking connect status on current org"
  (salesforce-core--org-process
   :cmd `("display" "--json")
   (when (string= (salesforce-core--get-data-json "result.connectedStatus" json-instance)
                  "RefreshTokenAuthError")
     (salesforce-core--alert "Token expired !!"))))

(defun salesforce-org--fetch-users-org (org-type)
  "Show all user connected organizations."
  (salesforce-core--org-process
   :cmd '("list" "--json")
   (let ((header (make-salesforce-ctable (:show-index t
                                                      :columns '("alias" "instanceUrl" "connectedStatus" "lastUsed")
                                                      :)))))))


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
  "Clear all apex log on org."
  (interactive)
  (salesforce-org-list
   (lambda (org-list)
     (let ((temp-file (make-temp-file "log" nil ".csv"))
           (org-name (completing-read "Org alias: " org-list nil nil salesforce-org-name)))

       (salesforce-core--data-process
        :cmd `("query" "--query" "SELECT Id FROM ApexLog" "-t" "-r" "csv" "-o" ,org-name)
        ;; Save data to temp file.
        (write-region (with-current-buffer json-instance (buffer-string)) nil temp-file)

        ;; Clear log on org.
        (salesforce-soql--delete-bulk "ApexLog" temp-file))))))

(defun salesforce-org--annotation (candidate)
  "Format CANDIDATE to show on `completing-read'."
  (let* ((hub (when (plist-get candidate :isDevHub)
                (propertize "D" 'face 'font-lock-keyword-face)))
         (status (if (string= (plist-get candidate :connectedStatus) "Connected")
                     (propertize salesforce-mode-line-connect-icon 'face 'success)
                   (propertize salesforce-mode-line-disconnect-icon 'face 'error)))
         (url (propertize (plist-get candidate :instanceUrl)
                          'face 'font-lock-comment-face)))
    `(,hub ,(concat status " " url))))

(defun salesforce-org--complete-candidate (orgs input pred action)
  "Completion table for ORGS.
Handles INPUT, PRED, ACTION according to `completing-read' contract."
  (if (eq action 'metadata)
      `(metadata (category . salesforce-org))
    (complete-with-action
     action
     (mapcar (lambda (org)
               (cons (propertize (or (plist-get org :alias)
                                    (plist-get org :username))
                                 'face 'font-lock-string-face
                                 'data org)
                     (plist-get org :username)))
             orgs)
     input pred)))

(defun salesforce-org-prompt-org ()
  "Selection available orgs that authorized."
  (salesforce-org--fetch-list-org
   :finish-func (lambda (org-list)
                  (let ((completion-extra-properties
                         '(:affixation-function (lambda (cands)
                                                  (mapcar (lambda (cand)
                                                            (pcase-let ((`(,prefix ,suffix)
                                                                         (salesforce-org--annotation (get-text-property 0 'data cand))))
                                                              (list cand prefix suffix)))
                                                          cands)))))
                    (completing-read "Org: " (apply-partially #'salesforce-org--complete-candidate org-list))))
   :fields '(:alias :username :instanceUrl :connectedStatus :isDevHub)))

(defun salesforce-org--list-build-format (json-instance)
  "Build list of orgs from JSON response and update cache."
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
  "Fetch Salesforce orgs with caching.
Optional ORG-TYPE filters ('devhub, 'scratch)."
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
  "Fetch org information and pass list of aliases/usernames to FINISH-FUNC."
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
