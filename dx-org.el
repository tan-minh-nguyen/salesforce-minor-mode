;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-core)

;;TODO: create transient menu

(defun dx-org-specific-open ()
  "Use a specific user name to open org"
  (interactive)
  (let ((user-name (or (ctbl:cp-get-selected-data-cell (ctbl:cp-get-component))
                      (read-string "user name:"))))

    (dx-core--org-process
     :cmd (list "org" "open" "--json" "-o" user-name "-r")
     (shell-command (format "%s --target %s %S"
                            dx-default-browser
                            "tab"
                            (dx-core--get-data-json "result.url" json-instance))))))

(defun dx-org-open-current ()
  "Open current default org."
  (interactive)
  (dx-core--org-process
   :cmd '("org" "open" "--json" "-r")
   (async-start (lambda ()
                  (shell-command (format "%s %S" 
                                         dx-default-browser 
                                         (dx-core--get-data-json "result.url" json-instance))))
                'ignore)))

(defun dx-org-display-all-orgs ()
  (interactive)
  (dx-org--fetch-users-org "other"))

(defun dx-org-display-all-devhubs ()
  (interactive)
  (dx-org--fetch-users-org "devhubs"))

(defun dx-org-authorize ()
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

    (dx-org--fetch-org-list 
     (lambda (org-list)

       (dx-core--org-process
        :cmd (list "login" "web" "-a" (completing-read "Alias: " org-list nil nil) "--instance-url" org-url "--set-default" "--json")
        (alert (format "Authorize to %s success" (dx-core--get-data-json "result.username" json-instance)) :title "Salesforce Alert"))))))

(defun dx-org-note-news ()
  "What news on dx cli."
  (interactive)
  (with-current-buffer (pop-to-buffer (get-buffer-create "*sf-note-news*"))
    (delete-selection-mode 1)

    (insert (shell-command-to-string "sf whatsnew"))))

(defun dx-org-change-connection ()
  "Change default connection org."
  (interactive)
  (dx-org--fetch-org-list (lambda (org-list)
                            (dx-core--config-process
                             :cmd `("set" "target-org" ,(completing-read "Org name: " org-list)  "--json")
                             (let ((org-name (dx-core--get-data-json "result.successes.0.value" json-instance)))
                               (alert (format "Change to %s success" (setq dx-org-name org-name)) :title "DX Alert"))))))

(defun dx-org--get-status ()
  "Checking connect status on current org"
  (dx-process--make-handle-json
   :cmd (list dx-org-command-alias "display" "--json")
   (when (string= (dx-core--get-data-json "result.connectedStatus" json-instance)
                  "RefreshTokenAuthError")
     (alert "Token expired !!" :title "Salesforce Alert"))))

;;TODO: change to use om-dash instead of ctable
(defun dx-org--fetch-users-org (org-type)
  "Show all user connected organizations."
  (dx-core--org-process
   :cmd '("list" "--json")
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
                          (let ((value (plist-get (intern (format ":%s" column-name)) data)))

                            (pcase value
                              (:false "false")
                              (:true  "true")
                              (_ value))))
                        dx-org-list-header-display))
              (dx-core--get-data-json
               (concat "result." org-type) json-instance))))
    :buffer dx-dedicated-window-right)))

(defun dx-org--fetch-org-list (cb)
  "Get all alias of orgs."
  (dx-core--org-process
   :cmd `("list" "--json" "--skip-connection-status")
   (funcall cb (remove-if #'null (append (mapcar (lambda (data)
                                                (plist-get data :alias))
                                              (dx-core--get-data-json
                                               "result.other" json-instance))
                                      (mapcar (lambda (data)
                                                (plist-get data :alias))
                                              (dx-core--get-data-json
                                               "result.nonScratchOrgs" json-instance)))))))


(provide 'dx-org)
