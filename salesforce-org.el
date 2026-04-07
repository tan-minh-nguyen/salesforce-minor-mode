;;; salesforce-org.el --- Salesforce org management -*- lexical-binding: t; no-byte-compile: t; no-native-compile: t -*-

;;; Commentary:
;; This package provides Salesforce org management functionality including
;; authentication, org switching, and log management.

;;; Code:

(require 'salesforce-core)
(require 'nerd-icons)

;;; Keymap

(defvar salesforce-org--keymap
  (salesforce-core--make-keymap '("M-r" salesforce-org--auth-point))
  "Keymap for org sources.")

;;; Core org operations

(cl-defun salesforce-org--auth-web (alias &key (url "https://login.salesforce.com"))
  "Authorize a Salesforce org through the web login flow.

URL is the login endpoint to connect to.
ALIAS is the name to assign to the authorized org."
  (salesforce-core--org-process
   :args `("login" "web" "-a" ,alias "--instance-url" ,url "--set-default" "--json")
   :callback
   (lambda (json-instance)
     (setf (salesforce-project-org salesforce-project-session) alias
           (salesforce-project-url salesforce-project-session)
           (salesforce-project--user-data alias "instanceUrl")
           (salesforce-project-token salesforce-project-session)
           (salesforce-project--user-data alias "accessToken"))
     (salesforce-project--save-session)
     (salesforce-core--alert (format "Authorize to %s success"
                                     (map-nested-elt json-instance '("result" "username")))))))

(cl-defun salesforce-org--status (&key then org)
  "Check current org status.
THEN is a callback function to handle the result.
ORG specifies which org to check."
  (salesforce-core--org-process
   :args `("display" "-o" ,org "--json")
   :callback then))

(cl-defun salesforce-org--list (&key args then)
  "Fetch Salesforce orgs, using cache when valid.

Options:
- FINISH-FUNC: Callback to receive results (async mode)."
  (salesforce-core--org-process
   :args `("list" "--json" ,@args)
   :callback then))

(defun salesforce-org--list-type (org-type)
  "Collect orgs of ORG-TYPE from cache."
  (assoc-default org-type (assoc-default 'data salesforce-core--org-list-cache)))

;;; Consult integration

(defun salesforce-org--auth-point ()
  "Authorize the Salesforce org at point using web login."
  (interactive)
  (let ((alias/username (or (get-text-property (point) 'alias)
                           (get-text-property (point) 'username)))
        (url (get-text-property (point) 'instanceUrl)))
    (salesforce-org--auth-web alias/username :url url)))

(cl-defun salesforce-org-read (then &key prompt require-match)
  "Select available orgs that are authorized.

PROMPT: label of input candidate.
BODY: The forms to run after getting user selection.
REQUIRE-MATCH: Whether to require a match."
  (let (candidate)
    (emacs-pp-job
     (lambda ()
       (salesforce-org--list :args '("--skip-connection-status")))
     (lambda (json)
       (let ((org-pairs (map-elt json "result")))
         (setq candidate
               (consult--multi
                (cl-loop for org-type in (hash-table-keys org-pairs)
                         as org-collection = (gethash org-type org-pairs)
                         as collection = (seq-map (lambda (item)
                                                    (cons (propertize (map-elt item "username") 'face 'font-lock-constant-face)
                                                          item))
                                                  org-collection)
                         as async = (consult--async-dynamic
                                     (lambda (input)
                                       (if input
                                           (seq-filter (pcase-lambda (`(,username . ,data))
                                                         (string-prefix-p input (substring-no-properties username) t))
                                                       collection)
                                         collection)))
                         as narrow = (aref (upcase org-type) 0)
                         as annotate = (pcase-lambda (data)
                                         (let* ((alias (or (map-elt data "alias") ""))
                                                (last-used (format-time-string
                                                            "%Y-%m-%d %H:%M"
                                                            (parse-iso8601-time-string (map-elt data "lastUsed"))))
                                                (org-name (or (map-elt data "name") "")))
                                           (concat " "
                                                   (propertize (truncate-string-to-width alias 15 0 ?\s "…")
                                                               'face 'font-lock-string-face)
                                                   " "
                                                   (propertize (truncate-string-to-width org-name 20 0 ?\s "…")
                                                               'face 'font-lock-comment-face)
                                                   " "
                                                   (propertize last-used 'face 'font-lock-doc-face))))
                         collect (list :async async
                                    :name org-type
                                    :category 'salesforce-org
                                    :narrow narrow
                                    :annotate annotate))
                :prompt prompt
                :initial ""
                :require-match require-match))))
     :finally
     (lambda ()
       (let* ((selected-value (car candidate))
              (pair-value (if (hash-table-p selected-value)
                              (cons (map-elt selected-value "username")
                                    selected-value)
                            (cons (string-replace "#" "" selected-value) nil))))

         (funcall then pair-value))))))

;;; Interactive commands - Org management

(defun salesforce-org--browse (org-name &key args then)
  "Open org CANDIDATE selected with browser."
  (declare (indent 1))
  (salesforce-core--org-process
   :args `("open" "--json" "-o" ,org-name ,@args)
   :callback then))

(cl-defun salesforce-org-browse (&key org)
  "Open selected org."
  (interactive)
  (salesforce-org-read
   (pcase-lambda (`(,org . ,data))
     (salesforce-org--browse org
       :args '("-r")
       :then
       (lambda (json-instance)
         (browse-url-generic (map-nested-elt json-instance '("result" "url"))))))
   :prompt "Select Org: "
   :require-match t))

(defun salesforce-org-auth ()
  "Use web login to authorize to org."
  (interactive)
  (salesforce-org-read
   (pcase-lambda (`(,alias . ,data))
     (let* ((collection '(sandbox production))
            (annotate-fn
             (lambda (candidate)
               (list candidate
                  ""
                  (concat "\t"
                          (propertize (pcase candidate
                                        ("sandbox" "https://test.salesforce.com")
                                        ("production" "https://login.salesforce.com")
                                        (_ "custom"))
                                      'face
                                      'font-lock-comment-face)))))
            (lookup-fn
             (lambda (cand &rest _)
               (pcase cand
                 ("sandbox" "https://test.salesforce.com")
                 ("production" "https://login.salesforce.com")
                 (_ cand))))
            (url (or (map-elt data "loginURL")
                    (consult--read collection
                                   :prompt "URL: "
                                   :annotate annotate-fn
                                   :lookup lookup-fn))))
       (salesforce-org--auth-web alias :url url)))
   :prompt "Select Org: "))

(defun salesforce-org-set-default (org-name)
  "Set default ORG-NAME for current project."
  (salesforce-core--config-process
   :args `("set" "target-org" ,org-name "--json")
   :callback
   (lambda (&rest _)
     (setf (salesforce-project-org salesforce-project-session) org-name
           (salesforce-project-url salesforce-project-session)
           (salesforce-project--user-data org-name "instanceUrl")
           (salesforce-project-token salesforce-project-session)
           (salesforce-project--user-data org-name "accessToken"))
     (salesforce-project--save-session)
     (salesforce-core--alert (format "Change to %s success" org-name)))))

(defun salesforce-org-switch ()
  "Change default connection org."
  (interactive)
  (salesforce-org-read
   (pcase-lambda (`(,org-name . ,data))
     (salesforce-org-set-default org-name))
   :prompt "Select Org: "
   :require-match t))

;;; Log management

(defun salesforce-org-log-read ()
  "Use consult to create select box for log."
  (salesforce-core--apex-process
   :args '("log" "list" "--json")
   :callback
   (lambda (json-instance)
     (let* ((raw-results ))
       (consult--read (consult--async-dynamic
                       ;; TODO: add filter by one of these data or all?
                       (lambda (input)
                         (cl-loop for data across (map-elt json-instance "result")
                                  as log-id = (map-elt data "Id")
                                  collect (cons log-id data))))
                      :prompt "Select log file: "
                      :require-match t
                      :lookup (lambda (candidate &rest _) (car candidate))
                      :annotate
                      (pcase-lambda (`(,_ . ,data))
                        (let* ((log-id (map-elt data "id"))
                               (size (/ (map-elt data "length") (* 1024 1024)))
                               (operation (map-elt data "operation"))
                               (time (format-time-string "%Y-%m-%d" (parse-time-string (map-elt data "start-time")))))

                          (concat (propertize (format "%.2fMB" size) 'face 'font-lock-number-face)
                                  "\t"
                                  (propertize time 'face 'font-lock-string-face)
                                  "\t"
                                  (nerd-icons-octicon "nf-oct-log")
                                  " "
                                  (propertize operation 'face 'font-lock-keyword-face)))))))))


(defun salesforce-org-log-show ()
  "Select a Salesforce log and open its content in a buffer."
  (interactive)
  (emacs-pp-job
   (lambda ()
     (salesforce-org-log-read))
   (lambda (select-log)
     (salesforce-core--apex-process
      :args `("get" "log" "--log-id" ,select-log "--json")))
   (lambda (json-instance)
     (let* ((log-dir (salesforce-project-log-dir salesforce-project-session))
            (file-name (concat log-dir selected-log ".log"))
            (file (create-file-buffer file-name)))
       (with-current-buffer file
         (with-silent-modifications
           (setf (buffer-string) (map-nested-elt json-instance '("result" 0 "log")))))
       (salesforce-core--alert (format "Fetch log %s success" selected-log))))))

(defun salesforce-org-log-delete ()
  "Clear logs from the connected Salesforce org."
  (interactive)
  (let ((temp-file (make-temp-file "log" nil ".csv")))
    (emacs-job
     (lambda (_)
       (salesforce-data--export-bulk
        `("-q" "SELECT Id FROM ApexLog" "--result-format=csv" "--output-file" ,temp-file)))
     (lambda (_)
       (salesforce-data--delete-bulk
        `("--sobject" "ApexLog" "--file" ,temp-file)))
     (lambda ()
       (salesforce-core-alert "Deleting log data succeeded")))))

(provide 'salesforce-org)
