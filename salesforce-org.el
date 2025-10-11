;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'salesforce-core)
(require 'salesforce-consult)

(defvar salesforce-org--consult-keymap
  (salesforce-core--make-keymap '("M-r" salesforce-org--consult-authorize))
  "Keymap for org sources.")

(defun salesforce-org--consult-authorize ()
  "Authorize the Salesforce org at point using web login."
  (interactive)
  (let ((alias/username (or (get-text-property (point) 'alias)
                           (get-text-property (point) 'username)))
        (url (get-text-property (point) 'instanceUrl)))

    (salesforce-org--web-authorize url alias/username)))

(defun salesforce-org-open ()
  "Open selection org."
  (interactive)
  (salesforce-org--collect
   :finish-func
   (lambda (_)
     (cl-loop for symbol in (list org--consult-other-source
                            org--consult-sandbox-source
                            org--consult-devhub-source
                            org--consult-scratch-source
                            org--consult-nonscratch-source)
              do (plist-put symbol :action #'salesforce-org--consult-open))
     
     (consult--multi '(org--consult-other-source
                       org--consult-sandbox-source
                       org--consult-devhub-source
                       org--consult-scratch-source
                       org--consult-nonscratch-source)))))

(defun salesforce-org-authorize ()
  "Using web login to authorize to org."
  (interactive)
  (let ((url (completing-read
              "URL: "
              '("https://test.salesforce.com"
                "https://login.salesforce.com"))))

    (salesforce-org-user-prompt 
     "Select Org: "
     (salesforce-org--web-authorize url org))))

(defun salesforce-org--web-authorize (url alias)
  "Authorize a Salesforce org through the web login flow.

URL is the login endpoint to connect to.
ALIAS is the name to assign to the authorized org."
  (salesforce-core--org-process
   :args `("login" "web" "-a" ,alias "--instance-url" ,url "--set-default" "--json")
   (salesforce-core--alert (format "Authorize to %s success"
                                   (salesforce-core--get-data-json "result.username" json-instance)))))

(defun salesforce-org-switch-connect ()
  "Change default connection org."
  (interactive)
  (salesforce-org-user-prompt
   "Select Org: "
   (salesforce-core--config-process
    :args `("set" "target-org" ,org "--json")
    (let ((org-name (salesforce-core--get-data-json "result.successes.0.value" json-instance)))
      (salesforce-core--alert (format "Change to %s success" (setq salesforce-org-name org-name)))))))

;; TODO: Refactor this, maybe use export to get a list of logs and convert to an org-table for selection.
(defun salesforce-org-find-log-file ()
  "View specific log."
  (interactive)
  (salesforce-core--apex-process
   :args '("log" "list" "--json")
   (let* ((logs (salesforce-core--get-data-json "result" json-instance))
          (log-map (cl-loop for data in log-list
                            with log-map = (make-hash-table :test #'equal)
                            do (puthash (salesforce-core--get-data-json "Id" data) data log-map)
                            finally return log-map))
          (read-log (consult--read (hash-table-keys log--map)
                                   :prompt "Log: "
                                   :require-match t
                                   :annotate (lambda (item)
                                               (funcall #'salesforce-org--annotation item log-map)))))

     (salesforce-core--apex-process
      :args `("get" "log" "--log-id" ,read-log "--json")
      (let ((file (create-file-buffer (format "%s%s.log" (salesforce--get-log-dir-path) read-log))))
        (with-current-buffer file
          (with-silent-modifications
            (setf (buffer-string) (salesforce-core--get-data-json "result.0.log" json-instance))))
        (salesforce-core--alert (format "Fetch log %s success" read-log)))))))

;; TODO: rebuild it use as default for package
(defun salesforce-org--annotation (item log-map)
  "Build log annotate"
  (let* ((data (gethash item log-map))
         (size (/ (salesforce-core--get-data-json "LogLength" data) (* 1024 1024)))
         (op (salesforce-core--get-data-json "Operation" data))
         (time (format-time-string "%Y-%m-%d" (parse-time-string (salesforce-core--get-data-json "StartTime" data)))))

    (list (propertize item 'face '(:width 10 :foreground "yellow")) nil (format "%s:%s" size time))))

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
        :callback
        (lambda (_)
          (salesforce-core-alert "Deleting log data succeeded")))))))

(defun salesforce-org-user-prompt--annotate (candidate)
  "Annotate CANDIDATE for org prompt."
  (let* ((data (cdr candidate))
         (status (plist-get data :connectedStatus))
         (last-used (plist-get data :lastUsed))
         (url (plist-get data :instanceUrl))
         (format-last-used (format-time-string "%Y-%m-%d %H:%M:%S" (date-to-time last-used)))
         (url-propertized (propertize url 'face 'font-lock-regexp-face))
         (time-propertized (propertize format-last-used 'face 'font-lock-number-face))
         (status-propertized (apply #'propertize status `(face ,(if (string= (downcase status) "connected")
                                                                    'success
                                                                  'font-lock-comment-face))))
         (postfix (concat url-propertized "\t"
                          time-propertized "\t"
                          status-propertized)))

    postfix))

(defmacro salesforce-org-user-prompt (prompt &rest body)
  "Selection available orgs that authorized.

PROMPT: label of input candidate.
BODY: The forms run after get user."
  `(salesforce-org--collect
    :finish-func 
    (lambda (_)
      (cl-loop for symbol in (list org--consult-other-source
                             org--consult-sandbox-source
                             org--consult-devhub-source
                             org--consult-scratch-source
                             org--consult-nonscratch-source)
               do (plist-put symbol :action #'(lambda (candidate)
                                                ,@body)))
      
      (consult--multi '(org--consult-other-source
                        org--consult-sandbox-source
                        org--consult-devhub-source
                        org--consult-scratch-source
                        org--consult-nonscratch-source)))))

(defun salesforce-org--list-build-format (data)
  "Build a list of orgs from the JSON DATA response and update the cache."
  (let* ((org-types (salesforce-core--get-data-json "result" data))
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

(cl-defun salesforce-org--collect (&key finish-func sync)
  "Fetch Salesforce orgs, using cache when valid.

Options:
- FINISH-FUNC: Callback to receive results (async mode).
- SYNC: Run synchronously if non-nil."
  (let* ((cached (assoc 'timestamp salesforce-core--org-list-cache))
         (now (time-to-seconds))
         (cache-valid (and cached
                         (< (- now (cdr cached))
                            salesforce-core--org-list-cache-ttl))))
    (if cache-valid
        (let* ((org-alist (assoc 'data salesforce-core--org-list-cache)))
          (if finish-func
              (funcall finish-func org-alist)
            org-alist))
      ;; not cached: fetch
      (let* ((process (salesforce-core--org-process
                       :args `("list" "--json")
                       :sync sync
                       (unless sync
                         (when-let ((orgs (salesforce-org--list-build-format json-instance)))
                           (funcall finish-func orgs))))))

        (when-let* ((_ (processp process))
                    (json-instance (salesforce-core-parse-buffer-json (process-buffer process))))
          (salesforce-org--list-build-format json-instance))))))

(cl-defun salesforce-org-list (finish-func &key org-type sync)
  "Fetch Salesforce orgs and pass aliases/usernames to FINISH-FUNC.

Options:
- ORG-TYPE: Filter orgs by type ('devhub, 'scratch, 'scratchorgs, 'nonscratchorgs, 'other).
- SYNC: Run synchronously if non-nil."
  (salesforce-org--fetch-list-org
   :finish-func (lambda (orgs)
                  (funcall finish-func orgs))
   :org-type org-type
   :sync sync))

(cl-defun salesforce-org-status (&key finish-func org)
  "Check current org status."
  (salesforce-core--org-process
   :args `("display" "-o" ,(or org salesforce-org-name) "--json")
   (funcall finish-func json-instance)))

(defun salesforce-org--consult-open (candidate)
  "Open org CANDIDATE selected with browser."
  (salesforce-core--org-process
   :args `("org" "open" "--json" "-o" ,(car candidate) "-r")
   (browse-url-generic (salesforce-core--get-data-json "result.url" json-instance))))

(defun salesforce-org--collect-orgs (org-type)
  "Collect ORG-TYPE from cache."
  (assoc-default org-type (assoc-default 'data salesforce-core--org-list-cache)))

(defun salesforce-org--consult-candidates (org-type &optional icon)
  "Collect candidates for selected ORG-TYPE with ICON."
  (mapcar
   (lambda (candidate)
     (let* ((org-identity (or (plist-get candidate :alias)
                             (plist-get candidate :username)))
            (display-text (if icon
                              (concat (propertize icon 'face 'salesforce-mode-line-face) " " org-identity)
                            org-identity)))
       (cons display-text
             `(,org-identity . ,candidate))))
   (salesforce-org--collect-orgs org-type)))

(salesforce-consult--define-source "org"
  :name "other"
  :narrow ?o
  :face 'font-lock-misc-punctuation-face                                   
  :category 'other-org
  :annotate salesforce-org-user-prompt--annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'other (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
  :name "sandbox"
  :narrow ?s
  :face 'font-lock-misc-punctuation-face                                   
  :category 'sandbox-org
  :annotate salesforce-org-user-prompt--annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'sandboxs (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
  :name "nonScratch"
  :narrow ?n
  :face 'font-lock-misc-punctuation-face                                   
  :category 'non-scratch-org
  :annotate salesforce-org-user-prompt--annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'nonScratchOrgs (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
  :name "devHub"
  :narrow ?d
  :face 'font-lock-misc-punctuation-face                                   
  :category 'devhub-org
  :annotate salesforce-org-user-prompt--annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'devHubs (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
  :name "scratch"
  :narrow ?S
  :face 'font-lock-misc-punctuation-face                                   
  :category 'scratch-org
  :annotate salesforce-org-user-prompt--annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'scratchOrgs (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(provide 'salesforce-org)
