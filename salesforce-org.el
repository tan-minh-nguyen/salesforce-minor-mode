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

(cl-defun salesforce-org--web-authorize (alias &key (url "https://login.salesforce.com"))
  "Authorize a Salesforce org through the web login flow.

URL is the login endpoint to connect to.
ALIAS is the name to assign to the authorized org."
  (salesforce-core--org-process
   :args `("login" "web" "-a" ,alias "--instance-url" ,url "--set-default" "--json")
   :callback
   (lambda (json-instance)
     (setq salesforce-org-name alias
           salesforce-project-url (salesforce-project--get-user-data alias "instanceUrl")
           salesforce-project-token (salesforce-project--get-user-data alias "accessToken"))
     (salesforce-project--update-dir-local-config 'salesforce-org-name alias)
     (salesforce-core--alert (format "Authorize to %s success"
                                     (map-nested-elt json-instance '("result" "username")))))))

(cl-defun salesforce-org--check-status (&key then org)
  "Check current org status.
THEN is a callback function to handle the result.
ORG specifies which org to check."
  (salesforce-core--org-process
   :args `("display" "-o" ,org "--json")
   :callback then))

(cl-defun salesforce-org--collect (&key args then)
  "Fetch Salesforce orgs, using cache when valid.

Options:
- FINISH-FUNC: Callback to receive results (async mode)."
  (salesforce-core--org-process
   :args `("list" "--json" ,@args)
   :callback then))

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

(cl-defun salesforce-org-read-user (then &key prompt require-match)
  "Select available orgs that are authorized.

PROMPT: label of input candidate.
BODY: The forms to run after getting user selection.
REQUIRE-MATCH: Whether to require a match."
  (emacs-job
   (lambda (_)
     (salesforce-org--collect :args '("--skip-connection-status")))
   (lambda (json)
     (let ((org-pairs (map-elt json "result")))
       (consult--multi
        (cl-loop for org-type in (hash-table-keys org-pairs)
                 as org-collection = (gethash org-type org-pairs)
                 as async = (consult--async-dynamic
                             (lambda (input)
                               (seq-map (lambda (candidate)
                                          (cons (map-elt candidate "username")
                                                candidate))
                                        org-collection)))
                 as narrow = (aref (upcase org-type) 0)
                 as annotate = (pcase-lambda (`(,cand . ,data))
                                 (let* ((alias (map-elt data "alias"))
                                        (last-used (map-elt data "lastUsed"))
                                        (desc (format "[%s\t%s]" alias last-used)))
                                   (concat cand "\t" desc)))
                 collect (list :async async
                            :name org-type
                            :category 'salesforce-org
                            :narrow narrow
                            :annotate annotate
                            :action then
                            :new (lambda (cand)
                                   (apply then (cons cand nil)))))
        :prompt prompt
        :require-match require-match)))))

;;; Interactive commands - Org management

(defun salesforce-org--open (org-name &key args then)
  "Open org CANDIDATE selected with browser."
  (declare (indent 1))
  (salesforce-core--org-process
   :args `("open" "--json" "-o" ,org-name ,@args)
   :callback then))

(cl-defun salesforce-org-open (&key org)
  "Open selected org."
  (interactive)
  (salesforce-org-read-user "Select Org: "
    (pcase-lambda (`(,org . ,data))
      (salesforce-org--open org
        :args '("-r")
        :then
        (lambda (json-instance)
          (browse-url-generic (map-nested-elt json-instance '("result" "url"))))))
    :require-match t))

(defun salesforce-org-authorize ()
  "Use web login to authorize to org."
  (interactive)
  (salesforce-org-read-user
      (pcase-lambda (`(,alias . ,data))
        (let* ((collection '((sandbox "https://test.salesforce.com")
                             (production "https://login.salesforce.com")))
               (annotate-fn
                (lambda (candidate)
                  (list candidate
                     (nerd-icons-faicon "nf-fa-cloud")
                     (apply #'pcase candidate
                            (,@collection
                             (t "custom"))))))
               (lookup (lambda (cand &rest _)
                         (apply #'pcase cand
                                `(,@collection
                                  (t ,cand)))))
               (url (or (map-elt data "loginURL")
                       (consult--read collection
                                      :prompt "URL: "
                                      :annotate annotate-fn
                                      :loopkup lookup-fn))))
          (salesforce-org--web-authorize alias :url url)))
    :prompt "Select Org: "))

(defun salesforce-org-set-default-org (org-name)
  "set default ORG-NAME for current project."
  (salesforce-core--config-process
   :args `("set" "target-org" ,org-name "--json")
   :callback
   (lambda (&rest _)
     (setq salesforce-org-name org-name
           salesforce-project-url (salesforce-project--get-user-data org-name "instanceUrl")
           salesforce-project-token (salesforce-project--get-user-data org-name "accessToken"))
     (salesforce-project--update-dir-local-config 'salesforce-org-name org-name)
     (salesforce-core--alert (format "Change to %s success" org-name)))))

(defun salesforce-org-switch-connect ()
  "Change default connection org."
  (interactive)
  (salesforce-org-read-user
   (pcase-lambda (`(,org-name . ,data))
     (salesforce-org-set-default-org org-name))
   :prompt "Select Org: "
   :require-match t))

;;; Log management

(defun salesforce-org-read-log ()
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


(defun salesforce-org-log-view ()
  "Select a Salesforce log and open its content in a buffer."
  (interactive)
  (emacs-pp-job
   (lambda ()
     (salesforce-org-read-log))
   (lambda (select-log)
     (salesforce-core--apex-process
      :args `("get" "log" "--log-id" ,select-log "--json")))
   (lambda (json-instance)
     (let ((file-name (concat (salesforce--get-log-dir-path) selected-log ".log"))
           (file (create-file-buffer file-name)))
       (with-current-buffer file
         (with-silent-modifications
           (setf (buffer-string) (map-nested-elt json-instance '("result" 0 "log")))))
       (salesforce-core--alert (format "Fetch log %s success" selected-log))))))

(defun salesforce-org-delete-logs ()
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
