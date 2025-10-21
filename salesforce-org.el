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

    (salesforce-org-read-user 
     "Select Org: "
     (salesforce-org--web-authorize url (car candidate)))))

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
  (salesforce-org-read-user
   "Select Org: "
   (let ((org (car candidate)))

     (salesforce-core--config-process
      :args `("set" "target-org" ,org "--json")
      (let ((org-name (salesforce-core--get-data-json "result.successes.0.value" json-instance)))
        (salesforce-core--alert (format "Change to %s success" (setq salesforce-org-name org-name))))))))

(defun salesforce-org-get-log-file ()
  "View specific log."
  (interactive)
  (salesforce-org-read-log
   "Select log file: "
   (salesforce-core--apex-process
    :args `("get" "log" "--log-id" ,log-file "--json")
    (let ((file-name (concat (salesforce--get-log-dir-path) read-log ".log"))
          (file (create-file-buffer file-name)))
      (with-current-buffer file
        (with-silent-modifications
          (setf (buffer-string) (salesforce-core--get-data-json "result.0.log" json-instance))))
      (salesforce-core--alert (format "Fetch log %s success" read-log))))))

(defmacro salesforce-org-read-log (prompt &rest body)
  "Read available logs on Salesforce.

PROMPT: label of input candidate.
BODY: The forms run after get user."
  (salesforce-core--apex-process
   :args '("log" "list" "--json")
   (let* ((raw-results (salesforce-core--get-data-json "result" json-instance))
          (callback (lambda (log-file)
                      ,@body))
          (candidates (cl-loop for data in raw-results
                               collect `(,(salesforce-core--get-data-json "Id" data)
                                         :id (salesforce-core--get-data-json "Id" data)
                                         :start-time (salesforce-core--get-data-json "startTime" data)
                                         :length (salesforce-core--get-data-json "logLength" data)
                                         :operation (salesforce-core--get-data-json "operation" data)
                                         :request (salesforce-core--get-data-json "request" data)
                                         :status (salesforce-core--get-data-json "status" data)))))

     (funcall callback
              (consult--read candidates
                             :prompt prompt
                             :require-match t
                             :lookup (lambda (candidate)
                                       (car candidate))
                             :annotate #'salesforce-org-log-prompt--annotate)))))

;; TODO: rebuild it use as default for package
(defun salesforce-org-log-prompt--annotate (candidate)
  "Annotate CANDIDATE for log prompt."
  (let* ((data (cdr candidate))
         (size (/ (plist-get data :log-length)
                  (* 1024 1024)))
         (operator (plist-get data :operator))
         (time (format-time-string "%Y-%m-%d" (parse-time-string (plist-get data :start-time)))))

    `(,(propertize item 'face '(:width 10 :foreground "#FFC400"))
      ,(nerd-icons-octicon "nf-oct-log")
      ,(format "%s\t%s" size time))))

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

(defun salesforce-org-read-user--annotate (candidate)
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

(defmacro salesforce-org-read-user (prompt &rest body)
  "Selection available orgs that authorized.

PROMPT: label of input candidate.
BODY: The forms run after get user."
  `(salesforce-org--collect
    :finish-func 
    (lambda (_)
      (let ((action #'(lambda (candidate)
                        ,@body))
            new-input)
        (cl-loop for symbol in (list org--consult-other-source
                               org--consult-sandbox-source
                               org--consult-devhub-source
                               org--consult-scratch-source
                               org--consult-nonscratch-source)
                 do (plist-put symbol :action action))
        
        (setq new-input
              (consult--multi '(org--consult-other-source
                                org--consult-sandbox-source
                                org--consult-devhub-source
                                org--consult-scratch-source
                                org--consult-nonscratch-source)
                              :require-match nil))
        (when new-input
          (funcall action new-input))))))

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
   :args `("open" "--json" "-o" ,(car candidate) "-r")
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
                                   :annotate salesforce-org-read-user--annotate
                                   :items (lambda ()
                                            (salesforce-org--consult-candidates 'other (nerd-icons-faicon "nf-fa-cloud")))
                                   :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
                                   :name "sandbox"
                                   :narrow ?s
                                   :face 'font-lock-misc-punctuation-face                                   
                                   :category 'sandbox-org
                                   :annotate salesforce-org-read-user--annotate
                                   :items (lambda ()
                                            (salesforce-org--consult-candidates 'sandboxs (nerd-icons-faicon "nf-fa-cloud")))
                                   :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
                                   :name "nonScratch"
                                   :narrow ?n
                                   :face 'font-lock-misc-punctuation-face                                   
                                   :category 'non-scratch-org
                                   :annotate salesforce-org-read-user--annotate
                                   :items (lambda ()
                                            (salesforce-org--consult-candidates 'nonScratchOrgs (nerd-icons-faicon "nf-fa-cloud")))
                                   :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
                                   :name "devHub"
                                   :narrow ?d
                                   :face 'font-lock-misc-punctuation-face                                   
                                   :category 'devhub-org
                                   :annotate salesforce-org-read-user--annotate
                                   :items (lambda ()
                                            (salesforce-org--consult-candidates 'devHubs (nerd-icons-faicon "nf-fa-cloud")))
                                   :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
                                   :name "scratch"
                                   :narrow ?S
                                   :face 'font-lock-misc-punctuation-face                                   
                                   :category 'scratch-org
                                   :annotate salesforce-org-read-user--annotate
                                   :items (lambda ()
                                            (salesforce-org--consult-candidates 'scratchOrgs (nerd-icons-faicon "nf-fa-cloud")))
                                   :keymap salesforce-org--consult-keymap)

(provide 'salesforce-org)
