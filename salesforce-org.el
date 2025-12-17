;;; salesforce-org.el --- Salesforce org management -*- lexical-binding: t; no-byte-compile: t; no-native-compile: t -*-

;;; Commentary:
;; This package provides Salesforce org management functionality including
;; authentication, org switching, and log management.

;;; Code:

(require 'salesforce-core)
(require 'nerd-icons)

;;; Keymap

(defvar salesforce-org--consult-keymap
  (salesforce-core--make-keymap '("M-r" salesforce-org--consult-authorize))
  "Keymap for org sources.")

;;; Core org operations

(defun salesforce-org--web-authorize (url alias)
  "Authorize a Salesforce org through the web login flow.

URL is the login endpoint to connect to.
ALIAS is the name to assign to the authorized org."
  (salesforce-core--org-process
   :args `("login" "web" "-a" ,alias "--instance-url" ,url "--set-default" "--json")
   (setq salesforce-org-name alias
         salesforce-project-url (salesforce-project--get-user-data alias "instanceUrl")
         salesforce-project-token (salesforce-project--get-user-data alias "accessToken"))
   (salesforce-project--update-dir-local-config salesforce-org-name alias)
   (salesforce-core--alert (format "Authorize to %s success"
                                   (map-nested-elt json-instance '("result" "username"))))))

(cl-defun salesforce-org--check-status (&key then org)
  "Check current org status.
THEN is a callback function to handle the result.
ORG specifies which org to check."
  (cl-letf (((symbol-function 'salesforce-core--async-when-done)
             (cl-function
              (lambda (proc &optional _change)
                (when-let ((_ (> (process-exit-status proc) 0))
                           (_ (string-match-p salesforce-process-buffer 
                                              (buffer-name (process-buffer proc)))))
                  (funcall then (salesforce-core-parse-buffer-json (process-buffer proc))))))))

    (salesforce-core--org-process
     :args `("display" "-o" ,org "--json")
     (funcall then json-instance))))

;;; Org list and caching

(defun salesforce-org--build-list-from-json (data)
  "Build a list of orgs from the JSON DATA response and update the cache."
  (let* ((org-types (map-elt data "result"))
         (org-data (cl-loop for (type orgs) in `((other ,(map-elt org-types "other"))
                                              (sandboxs ,(map-elt org-types "sandboxs"))
                                              (nonScratchOrgs ,(map-elt org-types "nonScratchOrgs"))
                                              (devHubs ,(map-elt org-types "devHubs"))
                                              (scratchOrgs ,(map-elt org-types "scratchOrgs")))
                            collect `(,type . ,(cl-loop for org across orgs
                                                        when (map-delete org "accessToken")
                                                        collect org)))))
    ;; Save org data to cache for reuse
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
        (let ((org-alist (assoc 'data salesforce-core--org-list-cache)))
          (if finish-func
              (funcall finish-func org-alist)
            org-alist))
      ;; Not cached: fetch
      (let ((process (salesforce-core--org-process
                      :args `("list" "--json")
                      :sync sync
                      (unless sync
                        (when-let ((orgs (salesforce-org--build-list-from-json json-instance)))
                          (funcall finish-func orgs))))))

        (when-let* ((_ (processp process))
                    (json-instance (salesforce-core-parse-buffer-json (process-buffer process))))
          (salesforce-org--build-list-from-json json-instance))))))

(defun salesforce-org--collect-by-type (org-type)
  "Collect orgs of ORG-TYPE from cache."
  (assoc-default org-type (assoc-default 'data salesforce-core--org-list-cache)))

;;; Consult integration

(defun salesforce-org--consult-authorize ()
  "Authorize the Salesforce org at point using web login."
  (interactive)
  (let ((alias/username (or (get-text-property (point) 'alias)
                            (get-text-property (point) 'username)))
        (url (get-text-property (point) 'instanceUrl)))
    (salesforce-org--web-authorize url alias/username)))

(defun salesforce-org--consult-open (candidate)
  "Open org CANDIDATE selected with browser."
  (salesforce-core--org-process
   :args `("open" "--json" "-o" ,(car candidate) "-r")
   (browse-url-generic (map-nested-elt json-instance '("result" "url")))))

(defun salesforce-org--consult-annotate (candidate)
  "Annotate CANDIDATE for org prompt."
  (let* ((data (cdr candidate))
         (status (map-elt data "connectedStatus"))
         (last-used (map-elt data "lastUsed"))
         (url (map-elt data "instanceUrl"))
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

(defun salesforce-org--consult-candidates (org-type &optional icon)
  "Collect candidates for selected ORG-TYPE with ICON."
  (mapcar
   (lambda (candidate)
     (let* ((org-identity (or (map-elt candidate "alias")
                              (map-elt candidate "username")))
            (display-text (if icon
                              (concat (propertize icon 'face 'salesforce-mode-line-face) " " org-identity)
                            org-identity)))
       (cons display-text
             `(,org-identity . ,candidate))))
   (salesforce-org--collect-by-type org-type)))

(cl-defmacro salesforce-org-read-user (prompt &rest body &key require-match &allow-other-keys)
  "Select available orgs that are authorized.

PROMPT: label of input candidate.
BODY: The forms to run after getting user selection.
REQUIRE-MATCH: Whether to require a match."
  (declare (indent 1))
  `(salesforce-org--collect
    :finish-func 
    (lambda (_)
      (let ((action (lambda (candidate)
                      ,@(seq-difference body (list :require-match require-match))))
            new-input)
        ;; Set action for all source types
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
                              :prompt ,prompt
                              :require-match ,require-match))
        (when ,require-match
          (funcall action new-input))))))

;;; Interactive commands - Org management

(defun salesforce-org-open ()
  "Open selected org."
  (interactive)
  (salesforce-org-read-user "Select Org: "
                            (funcall #'salesforce-org--consult-open candidate)
                            :require-match t))

(defun salesforce-org-authorize ()
  "Use web login to authorize to org."
  (interactive)
  (let ((url (completing-read
              "URL: "
              '("https://test.salesforce.com"
                "https://login.salesforce.com"))))
    (salesforce-org-read-user "Select Org: "
                              (salesforce-org--web-authorize url (car candidate)))))

(defun salesforce-org-switch-connect ()
  "Change default connection org."
  (interactive)
  (salesforce-org-read-user "Select Org: "
    (let ((org-name (car candidate)))
      (salesforce-core--config-process
       :args `("set" "target-org" ,org-name "--json")
       (setq salesforce-org-name org-name
             salesforce-project-url (salesforce-project--get-user-data org-name "instanceUrl")
             salesforce-project-token (salesforce-project--get-user-data org-name "accessToken"))
       (salesforce-project--update-dir-local-config salesforce-org-name org-name)
       (salesforce-core--alert (format "Change to %s success" org-name))))
    :require-match t))

;;; Log management

(defun salesforce-org--log-annotate (candidate)
  "Annotate CANDIDATE for log prompt."
  (let* ((data (cdr candidate))
         (log-id (map-elt data "id"))
         (size (/ (map-elt data "length") (* 1024 1024)))
         (operation (map-elt data "operation"))
         (time (format-time-string "%Y-%m-%d" (parse-time-string (map-elt data "start-time")))))
    (concat (propertize (format "%.2fMB" size) 'face 'font-lock-number-face)
            "\t"
            (propertize time 'face 'font-lock-string-face)
            "\t"
            (nerd-icons-octicon "nf-oct-log")
            " "
            (propertize operation 'face 'font-lock-keyword-face))))

(defun salesforce-org-get-log-file ()
  "View specific log."
  (interactive)
  (salesforce-core--apex-process
   :args '("log" "list" "--json")
   (let* ((raw-results (map-elt json-instance "result"))
          (candidates (cl-loop for data across raw-results
                               for log-id = (map-elt data "Id")
                               collect `(,log-id
                                         "id" ,log-id
                                         "start-time" ,(map-elt data "startTime")
                                         "length" ,(map-elt data "logLength")
                                         "operation" ,(map-elt data "operation")
                                         "request" ,(map-elt data "request")
                                         "status" ,(map-elt data "status"))))
          (selected-log (consult--read candidates
                                       :prompt "Select log file: "
                                       :require-match t
                                       :lookup (lambda (candidate) (car candidate))
                                       :annotate #'salesforce-org--log-annotate)))
     (salesforce-core--apex-process
      :args `("get" "log" "--log-id" ,selected-log "--json")
      (let ((file-name (concat (salesforce--get-log-dir-path) selected-log ".log"))
            (file (create-file-buffer file-name)))
        (with-current-buffer file
          (with-silent-modifications
            (setf (buffer-string) (map-nested-elt json-instance '("result" 0 "log")))))
        (salesforce-core--alert (format "Fetch log %s success" selected-log)))))))

(defun salesforce-org-delete-logs ()
  "Clear logs from the connected Salesforce org."
  (interactive)
  (let ((temp-file (make-temp-file "log" nil ".csv")))
    (salesforce-data--export-bulk
     `("-q" "SELECT Id FROM ApexLog" "--result-format=csv" "--output-file" ,temp-file)
     :callback
     (lambda (_)
       ;; Clear log on org
       (salesforce-data--delete-bulk
        `("--sobject" "ApexLog" "--file" ,temp-file)
        :callback
        (lambda (_)
          (salesforce-core-alert "Deleting log data succeeded")))))))

;;; Consult source definitions

(salesforce-consult--define-source "org"
  :name "other"
  :narrow ?o
  :face 'font-lock-misc-punctuation-face
  :category 'other-org
  :annotate salesforce-org--consult-annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'other (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
  :name "sandbox"
  :narrow ?s
  :face 'font-lock-misc-punctuation-face
  :category 'sandbox-org
  :annotate salesforce-org--consult-annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'sandboxs (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
  :name "nonScratch"
  :narrow ?n
  :face 'font-lock-misc-punctuation-face
  :category 'non-scratch-org
  :annotate salesforce-org--consult-annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'nonScratchOrgs (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
  :name "devHub"
  :narrow ?d
  :face 'font-lock-misc-punctuation-face
  :category 'devhub-org
  :annotate salesforce-org--consult-annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'devHubs (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(salesforce-consult--define-source "org"
  :name "scratch"
  :narrow ?S
  :face 'font-lock-misc-punctuation-face
  :category 'scratch-org
  :annotate salesforce-org--consult-annotate
  :items (lambda ()
           (salesforce-org--consult-candidates 'scratchOrgs (nerd-icons-faicon "nf-fa-cloud")))
  :keymap salesforce-org--consult-keymap)

(provide 'salesforce-org)
