;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-core)

(defun dx-org-specific-open ()
  "Use a specific user name to open org"
  (interactive)
  (let ((user-name (or (ctbl:cp-get-selected-data-cell (ctbl:cp-get-component))
                      (read-string "user name:" ))))

    (dx-make-process-json-async
     :cmd (dx-generate-command (list "org" "open" "--json" "-o" user-name "-r"))
     (cond ((= (plist-get json-instance :status) 0)
            (let ((url (dx-get-data-json "result.url" json-instance)))

              (shell-command (format "%s --target %s %S"
                                     dx-default-browser
                                     "tab"
                                     url))))
           (t (message "error"))))))

(defun dx-org-default-open ()
  "Open default org"
  (interactive)
  (dx-make-process-json-async
   :cmd (dx-build-sf-command "org" "open" "--json" "-r")
   (let ((url (dx-get-data-json "result.url" json-instance)))

     (shell-command (concat dx-default-browser (format " %S " url) " -r " " tab ") "*vc-log*"))))

(defun dx-fetch-all-users-org (org-type)
  "Display all current connect org"
  (dx-make-process-json-async
   :cmd (dx-build-sf-command dx-org-command-alias "list" "--json")
   (pop-to-buffer
    (dx-table--create-table
     :model
     (dx-table--make-table-mode
      :column-header
      (mapcar (lambda (column-name)
                (list :title column-name :align 'left :max-width '50))
              dx-org-list-header-display)
      :data
      (mapcar (lambda (data)
                (mapcar (lambda (column-name)
                          (let ((value (gethash column-name data)))

                            (pcase value
                              (:false "false")
                              (:true  "true")
                              (_ value))))
                        dx-org-list-header-display))
              (dx-get-data-json
               (concat "result." org-type) json-instance))))
    :buffer dx-dedicated-window-right)))

(defun dx-org-display-all-orgs ()
  (interactive)
  (dx-fetch-all-users-org "other"))

(defun dx-org-display-all-devhubs ()
  (interactive)
  (dx-fetch-all-users-org "devhubs"))

(defun dx-org-connect-status ()
  "Check connect status to org"
  (let ((display-org-information-command (dx-generate-command (list dx-org-command-alias "display" "--json"))))

    (dx-make-process-json-async
     :cmd display-org-information-command
     (when (string= (dx-get-data-json "result.connectedStatus" json-instance)
                    "RefreshTokenAuthError")
       (alert "Token expired !!" :title "Salesforce Alert")))))

(defun dx-diff-deploy-metadata ()
  "Use for deploy diff change between two branches."
  (interactive
   (let* ((current-branch (magit-get-current-branch))
          (branches (magit-list-local-branch-names))
          (org-name (completing-read "Target org: " nil org-list dx-org-name))
          (active-brach (completing-read "Base: " nil branches current-branch))
          (deploy-branch (completing-read "Deploy: " nil branches current-branch)))))
  (dx-org-alias-list
   (unless (string= active-brach current-branch)
     (shell-command (string-join `("git" "checkout" ,active-brach "-f")  " ")))

   (dx-make-process-json-async
    :cmd (sf-command (dx-build-sf-command
                      "deploy" "functions" "--connected-org" org-name
                      "--branch" deploy-branch "--json"))
    (cond ((= (plist-get json-instance :status) 0)
           (alert (format "Deploy branch %s success" deploy-branch)
                  :title "DX Alert"))
          (t (funcall #'dx-handle-process-error--json json-instance))))))

(defun dx-org-change ()
  "Change default org alias."
  (interactive)
  (dx-org-alias-list
   (let* ((switch-org (completing-read "Org name: " org-list))
          (json-instance (dx-make-process-json-async
                          :cmd (dx-build-sf-command "config" "set" "target-org" switch-org  "--json")
                          (cond ((= (plist-get json-instance :status) 0)
                                 (let ((org-name (dx-get-data-json "result.successes.0.value" json-instance)))
                                   (setq dx-org-name org-name)
                                   (alert (format "Change to %s success" org-name) :title "DX Alert")))
                                (t (funcall #'dx-handle-process-error--json json-instance)))))))))

(defun dx-org-authorize ()
  "Authorize org."
  (interactive)
  (let* ((org-list '("SANBOX/SCRATCH" "PRODUCTION" "CUSTOM URL"))
         (org-select (completing-read "Edittion: " org-list nil 'require-match))
         (org-url (pcase org-select
                    ("SANBOX/SCRATCH"
                     "https://test.salesforce.com")
                    ("PRODUCTION"
                     "https://login.salesforce.com")
                    (_ (read-from-minibuffer "URL: ")))))

    (dx-web-login org-url)))

(defun dx-note-news ()
  "What news on dx cli."
  (interactive)
  (with-current-buffer (pop-to-buffer (get-buffer-create "*sf-note-news*"))
    (delete-selection-mode 1)

    (insert (shell-command-to-string "sf whatsnew"))))

(provide 'dx-org)
