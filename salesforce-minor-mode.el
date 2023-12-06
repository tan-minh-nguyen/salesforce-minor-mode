;;; Salesforce minor mode -- add sf cli to emacs

(require 'alert)
(require 'projectile)
(require 'ctable)
(require 'subr-x)
(require 'cl-lib)

(defcustom sfmm:keymap-prefix "M-o"
  "The prefix for salesforce-mode key bindings."
  :type 'string
  :group 'salesforce)

(defcustom sfmm:org-keymap-prefix "O"
  "The keymap prefix for Org function."
  :type 'string
  :group 'salesforce)

(defcustom sfmm:auth-keymap-prefix "A"
  "The keymap prefix for Auth function."
  :type 'string
  :group 'salesforce)

(defcustom sfmm:apex-keymap-prefix "C"
  "The keymap prefix for Apex function."
  :type 'string
  :group 'salesforce)

(defcustom sfmm:query-keymap-prefix "Q"
  "The keymap prefix for Database function."
  :type 'string
  :group 'salesforce)

(defcustom sfmm:tangle-on-save t
  "When t, automatically tangle Org files on save."
  :type 'boolean
  :group 'salesforce)

(defcustom sfmm:api-version nil
  "Custom define api version for command."
   :type 'string
   :group 'salesforce-cli)

(defcustom sfmm:package-dir "manifest"
  "Custom define api version for command"
   :type 'string
   :group 'salesforce-cli)

(defcustom sfmm:org:non-scratch-org-header-display
  '("username" "instanceUrl" "orgId" "isDevHub" "instanceApiVersion" "alias" "lastUsed" "connectedStatus")
  "Custom define header display on table non scratch orgs"
  :type 'list
  :group 'salesforce-cli)

(defcustom sfmm:org:scratch-org-header-display
  '("username" "password" "instanceUrl" "orgId" "expirationDate" "instanceApiVersion" "alias" "connectedStatus")
  "Custom define header display on table scratch orgs"
  :type 'list
  :group 'salesforce-cli)

(defcustom sfmm:sfdx-lib-alias "sf"
  ""
  :type 'string
  :group 'command-alias)

(defcustom sfmm:sfdx-legacy-alias "force"
 ""
 :type 'string
 :group 'command-alias)

(defcustom sfmm:project-command-alias "project"
  ""
  :type 'string
  :group 'command-alias)

(defcustom sfmm:data-command-alias "data"
  ""
  :type 'string
  :group 'command-alias)

(defcustom sfmm:visualforce-command-alias "visualforce"
  ""
  :type 'string
  :group 'command-alias)

(defcustom sfmm:apex-command-alias "apex"
  ""
  :type 'string
  :group 'command-alias)

(defcustom sfmm:org-command-alias "org"
  ""
  :type 'string
  :group 'command-alias)

(defcustom sfmm:lightning-command-alias "lightning"
  ""
  :type 'string
  :group 'command-alias)

(defcustom sfmm:project-deploy-command
  (concat sfmm:project-command-alias " " "deploy")
  ""
  :type 'string
  :group 'project-command)

(defcustom sfmm:project-retrieve-command
  (concat sfmm:project-command-alias " " "retrieve")
  ""
  :type 'string
  :group 'project-command)

(defcustom sfmm:default-browser "qutebrowser"
  "Browser use for open url"
  :type 'string
  :group 'sfdx-cli)

(defcustom sfmm:default-apex-trigger-path "force-app/main/default/triggers"
 "Path save apex classes"
 :type 'string
 :group 'sfdx-config)

(defcustom sfmm:default-apex-class-path "force-app/main/default/classes"
 "Path save apex classes"
 :type 'string
 :group 'sfdx-config)

(defcustom sfmm:default-lwc-path "force-app/main/default/lwc"
 "Path save lwc components"
 :type 'string
 :group 'sfdx-config)

(defcustom sfmm:default-aura-path "force-app/main/default/aura"
 "Path save aura components"
 :type 'string
 :group 'sfdx-config)

(defcustom sfmm:default-vf-path "force-app/main/default/pages"
 "Path save visualforce page"
 :type 'string
 :group 'sfdx-config)

(defcustom sfmm:default-vf-components-path "force-app/main/default/components"
 "Path save visualforce page"
 :type 'string
 :group 'sfdx-config)

(defcustom sfmm:default-test-path "force-app/main/default/lightningTests"
 "Path save test components"
 :type 'string
 :group 'sfdx-config)

(defcustom sfmm:org:cache-dir ".cache/"
  "Directory to store cache files."
  :type 'string
  :group 'salesforce)

(defcustom sfmm:tracking-buffer-name "*Org Tracker*"
  "name of tracking metadata buffer."
  :type 'string
  :group 'tracker)

(add-to-list
 'display-buffer-alist
  '("salesforce api.*" . (display-buffer-no-window . nil)))

(defcustom sfmm:process-buffer "*Salesforce Process*"
  "name of process buffer."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:process-success-buffer "*Salesforce Success*"
  "name of process success buffer."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:process-error-buffer "*Salesforce Error*"
  "name of process error buffer."
  :type 'string
  :group 'salesforce-minor-mode)

(defvar sfmm:org-name ""
  "org name showing on mode line.")

(defun sfmm:project:create ()
  "Create dx project"
  (interactive)
  (let ((project-path (read-string "project-path: "))
        (project-name (read-string "project-name: "))
        (command (sfmm--helper:generate-command
                  (list sfmm:project-command-alias "generate"
                                                   "--name"
                                                   project-name
                                                   "--default-package-dir"
                                                   (cond (project-path
                                                          project-path)
                                                         (dired-directory
                                                          (concat dired-directory
                                                                  project-path))
                                                         (t
                                                          "."))))))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (let ((project-output (sfmm--helper:get-data-hashtable "result.outputDir" json-instance)))

          (alert "Create Project Success"
                 :title "Salesforce Alert"))))))

(defun sfmm:source:push
    ()
  "Push file to salesforce org."
  (interactive)
  (let* ((file-name (buffer-file-name))
         (push-command (list sfmm:sfdx-lib-alias "force" "source" "deploy" "-p" file-name "--json")))

    (sfmm:org:source-backup
     :handle-after-backup-lambda
     (lambda (_)
        (sfmm--helper:make-async-process
         :command `,push-command
         :handle-success-lambda
         `(lambda (process json-instance buffer)
           (alert (format "Deploy %s success" ,file-name)
                  :title "Salesforce Alert"))
         :handle-error-lambda
         (lambda (process json-instance buffer)
           (let ((show-message "")
                 (error-name (gethash "name" json-instance))
                 (error-message (gethash "message" json-instance)))

             (cond ((and error-name
                         error-message)
                    (setq show-message (format "Name: %s\nMessage: \n%s\n" error-name error-message)))
                   (t
                    (setq show-message (mapconcat (lambda (component)
                                                   (let ((problem (gethash "error" component))
                                                         (problem-type (gethash "problemType" component))
                                                         (line-number (gethash "lineNumber" component))
                                                         (file-name (gethash "filePath" component)))

                                                     (format "Problem-type: %s\nProblem: %s\n%s:%s"
                                                             problem-type
                                                             problem
                                                             file-name
                                                             line-number)))

                                                 (sfmm--helper:get-data-hashtable "result.deployedSource" json-instance)
                                                 "\n"))))

             (alert show-message
                    :title "Salesforce Alert"
                    :category 'error
                    :severity 'urgent))))))))

(defun sfmm:source:retrieve
    ()
  "Retrieve source salesforce form org"
  (interactive)
  (let ((retrieve-command (list sfmm:sfdx-lib-alias "force" "source" "retrieve" "-p" buffer-file-name "--json")))

    (sfmm--helper:make-async-process
     :command retrieve-command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (alert (format "Retrieve %s success" ,buffer-file-name)
               :title "Salesforce Alert")))))

(cl-defun sfmm:org:source-backup (&key handle-after-backup-lambda)
  "Backup the current buffer to the source directory."
  (let* ((buffer (buffer-file-name))
         (time (format-time-string "%Y_%m_%d_%H_%M_%S"))
         (file-name (file-name-base buffer))
         (cache-dir (concat (cdr (project-current)) sfmm:org:cache-dir))
         (backup-file-name (concat file-name "_" time))
         (command (sfmm--helper:generate-command (list sfmm:project-command-alias "retrieve" "start" "-d" buffer "-o" (sfmm:org:show-current-org) "-z" "-t" cache-dir "--zip-file-name" backup-file-name "--json"))))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir))

    (sfmm--helper:make-sync-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (funcall ,handle-after-backup-lambda ,(concat cache-dir backup-file-name)))
     :handle-error-lambda
     `(lambda (process json-instance buffer)
        (let ((show-message "")
              (error-name (gethash "name" json-instance))
              (error-message (gethash "message" json-instance)))

         (cond ((and error-name
                     error-message)
                (setq show-message (format "Name: %s\nMessage: \n%s\n" error-name error-message)))
               (t
                (setq show-message (mapconcat (lambda (component)
                                               (let ((problem (gethash "error" component))
                                                     (problem-type (gethash "problemType" component))
                                                     (line-number (gethash "lineNumber" component))
                                                     (file-name (gethash "filePath" component)))

                                                 (format "Problem-type: %s\nProblem: %s\n%s:%s"
                                                         problem-type
                                                         problem
                                                         file-name
                                                         line-number)))

                                             (sfmm--helper:get-data-hashtable "result.deployedSource" json-instance)
                                             "\n"))))

         (alert show-message
                :title "Backup Salesforce Failure"
                :category 'error))))))

(defun sfmm:org:specific-open ()
   "Use a specific user name to open org"
   (interactive)
   (let ((user-name (ctbl:cp-get-selected-data-cell (ctbl:cp-get-component))))

     (unless user-name
       (setq user-name (read-string "user-name: ")))

     (sfmm--helper:make-sync-process
      :command
      (sfmm--helper:generate-command (list "org" "open" "--json" "-o" user-name "-r"))
      :handle-success-lambda
      (lambda (process json-instance buffer)
        (let ((url (sfmm--helper:get-data-hashtable "result.url" json-instance)))

          (shell-command (format "%s --target %s %S"
                                 sfmm:default-browser
                                 "tab"
                                 url)))))))

(defun sfmm:org:default-open ()
   "Open default org"
   (interactive)
   (let ((command (sfmm--helper:generate-command (list "org" "open" "--json" "-r"))))

     (sfmm--helper:make-async-process
      :command command
      :handle-success-lambda
      (lambda (process json-instance buffer)
        (let ((url (sfmm--helper:get-data-hashtable "result.url" json-instance)))

          (shell-command (concat sfmm:default-browser (format " %S " url) " -r " " tab ")))))))

(defun sfmm:org:display-all (org-type)
  "Display all current connect org"
  (let ((command (sfmm--helper:generate-command (list sfmm:org-command-alias "list" "--json"))))

    (sfmm--helper:make-sync-process
     :command command
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (let ((start-index 1)
             (column-header-map #s(hash-table test equal data ("No" ((:align . 'left) (:title . "No"))))))
         (mapcar
          (lambda (item)
            (puthash
             (format "%s" item)
             `((:align . ,'left) (:title . ,item))
             column-header-map))
          (cond ((string= org-type "nonScratchOrgs") sfmm:org:non-scratch-org-header-display)
                ((string= org-type "scratchOrgs")) sfmm:org:scratch-org-header-display))

         (if (= (gethash "status" json-instance) 0)
             (let* ((non-scratch-orgs
                     (sfmm--helper:get-data-hashtable
                      (concat "result." org-type) json-instance))
                    (data
                     (mapcar
                      (lambda (element)
                        (let ((row
                               (sfmm--helper:convert-hashtable-data-to-list
                                :hashtable-data element
                                :columns
                                (cond ((string= org-type "nonScratchOrgs") sfmm:org:non-scratch-org-header-display)
                                      ((string= org-type "scratchOrgs")) sfmm:org:scratch-org-header-display)
                                :post-process
                                (lambda (key value)
                                  (let ((column-config
                                         `((:align . ,'left) (:title . ,key))))

                                    (when (length> value 50)
                                        (add-to-list 'column-config `(:max-width . ,'50))

                                        (puthash (format "%s" key) column-config column-header-map)))))))

                          (progn
                            (add-to-list 'row start-index
                                         nil (lambda (el1 el2) nil))
                            (setq start-index
                                  (1+ start-index))
                            row)))
                      non-scratch-orgs)))

               (sf--build:make-table-model
                :column-header (hash-table-values column-header-map)
                :data data))))))))

(defun sfmm:org:display-all-non-scratch ()
  (interactive)
  (sfmm:org:display-all "nonScratchOrgs"))

(defun sfmm:org:display-all-scratch ()
  (interactive)
  (sfmm:org:display-all "scratchOrgs"))

(defun sfmm:org:connect-status ()
  "Check connect status to org"
  (let ((display-org-information-command (sfmm--helper:generate-command (list sfmm:org-command-alias "display" "--json"))))

    (sfmm--helper:make-async-process
     :command display-org-information-command
     :handle-success-lambda
     (lambda (process json-instance buffer)
        (let* ((status (sfmm--helper:get-data-hashtable "result.connectedStatus" json-instance)))
          (when (string= status
                         "RefreshTokenAuthError")
            (alert "Token expired !!" :title "Salesforce Alert")))))))

(defun sfmm:org:show-current-org ()
  (let ((org-alias ""))

    (sfmm--helper:make-sync-process
     :command (sfmm--helper:generate-command (list sfmm:org-command-alias "display" "--json"))
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (setq ,'org-alias (sfmm--helper:get-data-hashtable "result.alias" json-instance))))
    org-alias))

(defun sfmm:refresh-default-org
    ()
  "Refresh current default org on layout"
  (interactive)
  (sfmm:org:show-current-org))

(cl-defun sfmm:apex:get-log (&key log-id number org post-log-handle)
  "Get log apex"
  (let ((command (sfmm--helper:generate-command (list sfmm:apex-command-alias "get" "log" "--json"))))

    (setq command (progn
                    (when org
                     (append command `("-o" ,org)))
                    (cond ((not (string= log-id "")) (append command `("--log-id" ,log-id)))
                          (number (append command `("--number" ,number))))))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)

        (setq json-result (gethash "result" json-instance))
        (funcall ,post-log-handle (gethash "log" (aref json-result 0)))))))

(cl-defun sfmm:apex:log-tail
    (&key (buffer-name "*apex-trace-log*") (org-id nil))
  :interactive
  (let (command (sfmm--helper:generate-command (list sfmm:apex-command-alias "get" "tail" "log" "--json")))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process output)
         (let ((buffer (get-buffer-create ,buffer-name)))
           (with-current-buffer buffer
             (goto-char (point-max))
             (insert output)))))))

(defun sfmm:execute-apex-code ()
 (interactive)
 (sfmm--helper:execute-apex (point-min)))

(defun sfmm--helper:org:login (url)
   "Authorize to salesforce org"
   (let* ((alias (read-string "alias: "))
          (authorize-command
            (sfmm--helper:generate-command (list sfmm:org-command-alias "login" "web" "-a" alias "--instanceurl" url "--set-default" "--json"))))
    (sfmm--helper:make-async-process
     :command
     authorize-command
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (let ((user-name (sfmm--helper:get-data-hashtable "result.username" json-instance)))

         (alert "Authorize success" :title "Salesforce Alert")
         (sfmm--helper:make-sync-process
          :command
          (sfmm--helper:generate-command (list "org" "open" "--json" "-o" user-name "-r"))
          :handle-success-lambda
          (lambda (process json-instance buffer)
            (let ((url (sfmm--helper:get-data-hashtable "result.url" json-instance)))

              (shell-command (concat sfmm:default-browser " " (format "%S" url) " -r " " tab "))))))))))

(defun sfmm:org:authorize-sandbox ()
  "Authorize use for scratch org and sanbox org"
  (interactive)
  (let* ((url "https://test.salesforce.com"))

    (sfmm--helper:org:login url)))

(defun sfmm:org:authorize-production ()
  "Authorize use for dev org and production org"
  (interactive)
  (let* ((url "https://login.salesforce.com"))

    (sfmm--helper:org:login url)))

(defun sfmm:org:authorize-custom-url ()
  "Authorize use custom instance url for org"
  (interactive)
  (let* ((url (read-string "url: ")))

    (sfmm--helper:org:login url)))

(defun sfmm:fetch-record-through-soql ()
  "Fetch salesforce record by calling API through Salesforce CLI library"
  (interactive)
  (let* ((history '())
         (file-name "soql-history")
         (cache-dir (concat (cdr (project-current)) sfmm:org:cache-dir))
         (file-contents `',(with-current-buffer (get-buffer-create (concat cache-dir file-name))
                             (buffer-string)))
         (soql-string (read-from-minibuffer "SOQL: " nil nil nil `("read-from-minibuffer"))))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir))

    (with-current-buffer (get-file-buffer (concat cache-dir "/" file-name))
      (erase-buffer)
      (insert `,file-contents))

    (sfmm--helper:execute-soql :query soql-string)))

(defun sfmm:fetch-record-through-file ()
  "Fetch record through file."
  (interactive)
  (let ((soql-file (read-string "SOQL-File: ")))

    (sfmm--helper:execute-soql :file soql-file)))

(defun sfmm:fetch-salesforce-file
    ()
  "Retrieve org file from salesforce"
  (let* ((local-path (expand-file-name "~/.cache/sfdx"))
         ())

    ))

(defun sfmm:visualforce:generate-page ()
  (interactive)
  (let* ((page-name (read-string "page name: "))
         (page-label (read-string "page label: "))
         (command (sfmm--helper:generate-command
                   (list sfmm:visualforce-command-alias "generate" "page" "--json" "--name" page-name "--label" page-label "--output-dir" (projectile-expand-root sfmm:default-vf-path)))))

    (sfmm--helper:make-sync-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)

        (alert (format "Create visualforce page" ,page-name)
               :title "Salesforce Alert")))))

(defun sfmm:visualforce:generate-component ()
  (interactive)
  (let* ((page-name (read-string "page name: "))
         (page-label (read-string "page label: "))
         (command (sfmm--helper:generate-command
                   (list sfmm:visualforce-command-alias "generate" "component" "--json" "--name" page-name "--label" page-label "--output-dir" (projectile-expand-root sfmm:default-vf-components-path)))))

    (sfmm--helper:make-sync-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)

        (alert (format "Create visualforce page" ,page-name)
               :title "Salesforce Alert")))))

(defun sfmm:apex:generate-trigger ()
  "Generate apex class"
  (interactive)
  (let* ((class-name (read-string "class name: "))
         (sobject-name (read-string "sobject name: "))
         (events-name (read-string "event name: "))
         (command (sfmm--helper:generate-command
                   (list sfmm:apex-command-alias "generate" "trigger" "--name" class-name "--output-dir" (projectile-expand-root sfmm:default-apex-trigger-path) "--json")))
         (class-expand ""))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (let ((full-path-file ,(concat (projectile-expand-root sfmm:default-apex-class-path) "/" class-name ".trigger")))
          (with-current-buffer (find-file full-path-file)
            (when ,sobject-name
                (replace-string "SOBJECT" ,sobject-name))
            (when ,events-name
                (replace-string "beforce insert" ,events-name))))))))

(defun sfmm:apex:generate-class ()
  "Generate apex class"
  (interactive)
  (let* ((class-name (read-string "class name: "))
         (class-extend (read-string "class parent: "))
         (class-implements (read-string "class implements: "))
         (command (sfmm--helper:generate-command
                   (list sfmm:apex-command-alias "generate" "class" "--name" class-name "--output-dir" (projectile-expand-root sfmm:default-apex-class-path) "--json")))
         (class-expand ""))

    (progn
      (unless (string= class-extend "")
        (setq class-expand (concat class-expand "extends" " " class-extend " ")))
      (unless (string= class-implements "")
        (setq class-expand (concat class-expand "implements" " " class-implements " "))))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (let ((full-path-file ,(concat (projectile-expand-root sfmm:default-apex-class-path) "/" class-name ".cls")))
          (org-open-file full-path-file)

          (goto-char (- (point-at-eol) 1))
          (insert ,class-expand))))))

(defun sfmm:apex:generate-test-class ()
  "Generate apex test class"
  (interactive)
  (let* ((class-name (read-string "class name: "))
         (command (sfmm--helper:generate-command
                   (list sfmm:apex-command-alias "generate" "class" "--name" class-name "--output-dir" (projectile-expand-root sfmm:default-apex-class-path) "--json"))))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (let ((full-path-file ,(concat (projectile-expand-root sfmm:default-apex-class-path) "/" class-name ".cls")))
          (org-open-file full-path-file)

          (insert "@isTest"))))))

(defun sfmm:apex:generate-test-method ()
  "Generate apex test method"
  (interactive)
  (let ((method-name (read-string "method name: ")))

    (end-of-buffer)
    (forward-line -1)
    (insert (format "\n%s\nprivate static void %s () {\n}"
                    "@isTest"
                    method-name))))

(cl-defun sfmm:lightning:generate
    (&key type output-dir message-success component-type)
  ""
  (let* ((component-name (read-string "lwc name: "))
         (command (sfmm--helper:generate-command
                    (list sfmm:lightning-command-alias "generate" "component" "--output-dir" output-dir "--name" component-name "--json"))))

    (when (string= type "component")
      (setq command
            (append command (list "--type" component-type))))

    (sfmm--helper:make-sync-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (alert (format message-success ,component-name)
               :title "Salesforce Alert")))))

(defun sfmm:lightning-component:generate-lwc ()
  ""
  (interactive)
  (sfmm:lightning:generate
   :type "component"
   :output-dir (projectile-expand-root sfmm:default-lwc-path)
   :message-success "Create %s success"
   :component-type "lwc"))

(defun sfmm:lightning-component:generate-aura ()
  "Generate Aura Component"
  (interactive)
  (sfmm:lightning:generate
   :type "component"
   :output-dir (projectile-expand-root sfmm:default-aura-path)
   :message-success "Create aura component %s success"
   :component-type "aura"))

(defun sfmm:lightning-app:generate ()
  "Create lightning app"
  (interactive)
  (sfmm:lightning:generate
   :type "app"
   :output-dir (projectile-expand-root sfmm:default-aura-path)
   :message-success "Create app %s sucesss"))

(defun sfmm:lightning-event:generate ()
  "Create lightning event"
  (interactive)
  (sfmm:lightning:generate
   :type "event"
   :output-dir (projectile-expand-root sfmm:default-aura-path)))

(defun sfmm:lightning-interface:generate ()
  "Create lightning interface"
  (interactive)
  (sfmm:lightning:generate
   :type "interface"
   :output-dir (projectile-expand-root sfmm:default-aura-path)
   :message-success "Create interface %s success"))

(defun sfmm:lightning-test:generate ()
  "Create lightning test"
  (interactive)
  (sfmm:lightning:generate
   :type "test"
   :output-dir (projectile-expand-root sfmm:default-test-path)
   :message-success "Create test %s sucess"))

(cl-defun sfmm:apex:get-result-test-job
    (&key job-id)
  "Get result tests"
  (let ((command (sfmm--helper:generate-command (list sfmm:apex-command-alias "get" "test" "-i" job-id "--json"))))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (let ((result-tests
              (mapconcat (lambda (result-test)
                           (let ((stack-trace (gethash "StackTrace" result-test))
                                 (outcome (gethash "Outcome" result-test))
                                 (error-message (gethash "Message" result-test))
                                 (method-name (gethash "MethodName" result-test))
                                 (class-name-test (sfmm--helper:get-data-hashtable "ApexClass.Name" result-test)))

                             (format "Class: %s\nMethod: %s\nResult: %s\n%s"
                                     class-name-test
                                     method-name
                                     (cond ((equal error-message ':null)
                                            outcome)
                                           (error-message
                                            error-message))
                                     (cond ((equal stack-trace ':null)
                                            "")
                                           (stack-trace
                                            stack-trace)))))

                         (sfmm--helper:get-data-hashtable "result.tests" json-instance)
                         "\n")))
         (alert result-tests
                :title "Salesforce Alert"))))))

(defun sfmm:apex:run-test-class ()
  "Run unit test for class"
  (interactive)
  (let ((command (sfmm--helper:generate-command (list sfmm:apex-command-alias "run" "test" "--tests" (file-name-base) "--test-level" "RunSpecifiedTests" "--json"))))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (alert "Class tests run success"
              :title "Salesforce Alert")
       (sfmm:apex:get-result-test-job
        :job-id (sfmm--helper:get-data-hashtable "result.testRunId" json-instance))))))

(defun sfmm:apex:run-local-tests ()
  "Run all tests class expect tests class in org managed package"
  (interactive)
  (let ((command (sfmm--helper:generate-command (list sfmm:apex-command-alias "run" "test" "--test-level" "RunLocalTests" "--json"))))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (sfmm:apex:get-result-test-job (job-id (sfmm--helper:get-data-hashtable "result.testRunId" json-instance)))))))



(defun sfmm:server:local-lwc ()
  ""
  (interactive)
  (let ((command (sfmm--helper:generate-command (list sfmm:sfdx-legacy-alias "lightning" "lwc" "start" "--json"))))

    (sfmm--helper:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-string buffer)
        (alert "Start lwc local server success"
               :title "Salesforce Alert")))))

(defun sfmm:diff-metadata ()
  "diff metadata between local and cloud."
  (interactive)
  (let ((file-name (buffer-file-name)))

    (sfmm:org:source-backup
     :handle-after-backup-lambda
     `(lambda (backup-file-name)
        (condition-case nil
            (diff (car (directory-files-recursively (concat backup-file-name "/") ,(file-name-nondirectory file-name))) ,file-name)
          (error
           (alert "Something Wrong"
                  :title "Salesforce Alert"
                  :severity 'urgent)))))))

(defun sfmm:tracking-org-source ()
  (interactive)
  (let* ((folder-name (file-name-base buffer-file-name))
         (file-name (file-name-nondirectory buffer-file-name))
         (folder-path (expand-file-name
                       (format "%s*/**/%s"
                              (concat (cdr (project-current))
                                      sfmm:org:cache-dir
                                      folder-name)
                              file-name)))
         (model
          (sf--build:make-table-model
           :column-header
           `((:title "Metadata Name")
             (:title "Created Date"))
           :data
           (mapcar (lambda (folder)
                     ;; format files show on buffer
                     (let* ((columns (string-split folder " "))
                            (date (nth 0 columns))
                            (time (nth 1 columns))
                            (file-name (nth 2 columns))
                            (suffix-file-folder (nth 3 columns)))

                       `(,(file-name-base file-name) ,(concat (string-replace "-" "/" date) "T" time) ,(concat file-name "_" suffix-file-folder))))
                   ;; list of file names
                   (split-string (shell-command-to-string
                                  ;; script list all files with name
                                  (concat "ls " folder-path " -tla --time-style=long-iso"
                                          " | " "cut -d \" \" -f 6,7,8,9"
                                          " | " "sed -E 's/[a-zA-Z]*\\_([[:digit:]\\_]+).*\\/(\\w+)\\.[A-Za-z]+$/\\2 \\1/'"))
                                 "\n"))))
         (component
          (sf--build:create-table-component
           :model model
           :buffer sfmm:tracking-buffer-name)))

    (ctbl:cp-add-click-hook component
                            `(lambda ()
                              (when-let* ((data (ctbl:cp-get-selected-data-row ,component))
                                          (dir (nth 2 data))
                                          (cache-dir ,(concat (cdr (project-current)) sfmm:org:cache-dir)))

                                (diff (car (directory-files-recursively dir ,file-name))
                                      ,buffer-file-name))))

    (switch-to-buffer (ctbl:cp-get-buffer component))))

(defun sfmm--helper:generate-command (commands)
  (add-to-list 'commands sfmm:sfdx-lib-alias))

(defun sfmm--helper:execute-apex (content)
emacs make-process pipe "Execute code"
  (let ((code (unless content
               (point-min)
               content))
        (temp-file (make-temp-file "temp_code")))

   (write-region (point-min) (point-max) temp-file)
   (setq execute-apex-code-command
     (sfmm--helper:generate-command "apex" "run" "-f" temp-file))

   (async-shell-command execute-apex-code-command buffer)))

(cl-defun sfmm--helper:execute-soql (&key query (type 'string) options)
  "Excute command fetch records from Salesforce through api"
  (let* ((options
          (cond ((equal type 'string)
                 (list "--query" query))
                ((equal type 'file)
                 (list "--file" query))))
         (execute-soql-code
          (append (sfmm--helper:generate-command (list sfmm:data-command-alias "query" "--json"))
                  options)))

    (sfmm--helper:make-async-process
     :command execute-soql-code
     :handle-success-lambda
     (lambda (process json-instance buffer)
       
       (if (length= (sfmm--helper:get-data-hashtable "result.records" json-instance) 0)
           (alert "No records found"
                  :title "Salesforce Query")
         (let* ((records-list (sfmm--helper:get-data-hashtable "result.records" json-instance))
                (header-columns (hash-table-keys (aref records-list 0)))
                (data (sf--build:make-data-table-from-vector
                       :header-columns header-columns
                       :data records-list)))

           (add-to-list 'header-columns "No")

           (sf--build:popup-table-component
            :model
            (sf--build:make-table-model
             :column-header
             (cl-loop for key in header-columns
                      when (not (string= key ""))
                      collect `(:align ,'left :title ,key `:max-width ,'50))
             :data data)
            :buffer buffer)))))))

(cl-defun sfmm--helper:make-sync-process (&key command handle-success-lambda (handle-error-lambda))

  (with-environment-variables (("NODE_NO_WARNINGS" "1"))
    (let* ((buffer-stdout (with-current-buffer (get-buffer-create "salesforce-process")
                            (let ((inhibit-read-only t))
                              (erase-buffer)
                              (current-buffer))))
           (process-identity "salesforce")
           (buffer-stderr  (with-current-buffer (get-buffer-create "salesforce-error")
                             (let ((inhibit-read-only t))
                               (erase-buffer)
                               (current-buffer))))
           (process-error
            (make-pipe-process
             :name
             (concat process-identity "-error")
             :buffer buffer-stderr
             :sentinel
             `(lambda (process event)
                (with-current-buffer ,buffer-stderr
                  (beginning-of-buffer)

                  (condition-case nil
                      (json-parse-buffer)
                    (error (cond ((= (buffer-size) 0)
                                  nil)
                                 (t
                                  (alert (replace-regexp-in-string "" "" (buffer-string))
                                         :title "Salesforce Alert"
                                         :severity 'urgent)))))))))
           (process-output "")
           (process
            (make-process
             :name process-identity
             :buffer buffer-stdout
             :stderr process-error
             :command command
             :connection-type 'pipe
             :filter
             `(lambda (process output)
               (setq process-output (concat ,process-output output)))
             :sentinel
             (lambda (process event)
              (cond ((string= event "deleted\n")
                     (kill-buffer (process-buffer process))))))))

      (when (accept-process-output process))

      (condition-case json-instance
        (json-parse-string process-output)
       (error (cond ((= (buffer-size) 0)
                     nil)
                    ((not (member "--json" command))
                     (funcall handle-success-lambda process (buffer-string) buffer-stdout))
                    (t
                     (alert (buffer-string)
                            :title "Salesforce Alert"
                            :severity 'urgent))))
       (:success
        (pcase (cond ((gethash "status" json-instance)
                      (gethash "status" json-instance))
                     ((gethash "code" json-instance)
                      (gethash "status" json-instance)))
          (1
           (cond (handle-error-lambda
                  (funcall handle-error-lambda process json-instance buffer-stderr))
                 (t
                  (alert (gethash "message" json-instance)
                         :title "Salesforce Alert"
                         :severity 'urgent))))
         (0
          (funcall handle-success-lambda process json-instance buffer-stdout))))))))

(cl-defun sfmm--helper:make-async-process
    (&key command buffer-name handle-success-lambda handle-error-lambda)
  "Make async process"
  (let* ((process-identity "salesforce")
         (buffer-stdout (with-current-buffer (get-buffer-create "salesforce-process")
                         (let ((inhibit-read-only t))
                           (erase-buffer)
                           (current-buffer))))
         (buffer-stderr (with-current-buffer (get-buffer-create "salesforce-error")
                         (let ((inhibit-read-only t))
                           (erase-buffer)
                           (current-buffer))))
         (buffer-view-post-process (cond ((or (null buffer-name)
                                              (string= buffer-name ""))
                                          (with-current-buffer (get-buffer-create "salesforce outcome")
                                            (let ((inhibit-read-only t))
                                              (erase-buffer)
                                              (current-buffer))))
                                         (buffer-name
                                          (generate-new-buffer buffer-name))))
         (process-error (make-pipe-process
                         :name
                         (concat process-identity "-error")
                         :buffer buffer-stderr
                         :sentinel
                         `(lambda (process event)
                            (with-current-buffer ,buffer-stderr
                              (beginning-of-buffer)

                              (condition-case nil
                                  (json-parse-buffer)
                                (error (cond ((= (buffer-size) 0)
                                              nil)
                                             (t
                                              (alert (replace-regexp-in-string "" "" (buffer-string))
                                                     :title "Salesforce Alert"
                                                     :severity 'urgent))))))))))

    (with-environment-variables (("NODE_NO_WARNINGS" "1"))

      (make-process
       :name (concat process-identity "-process")
       :buffer buffer-stdout
       :stderr process-error
       :command command
       :sentinel
       `(lambda (process event)
          (with-current-buffer ,buffer-stdout
            (beginning-of-buffer)

            (condition-case json-instance
                (json-parse-buffer)
              (error (cond ((= (buffer-size) 0)
                            nil)
                           ((not (member "--json" ',command))
                            (funcall ,handle-success-lambda process (buffer-string) ,buffer-view-post-process))
                           (t
                            (alert (buffer-string)
                                   :title "Salesforce Alert"
                                   :severity 'urgent))))
              (:success
                  (pcase (cond ((gethash "status" json-instance)
                                (gethash "status" json-instance))
                               ((gethash "code" json-instance)
                                (gethash "status" json-instance)))
                      (1
                       (cond (,handle-error-lambda
                              (funcall ,handle-error-lambda process json-instance ,buffer-view-post-process))
                             (t
                              (alert (gethash "message" json-instance)
                                    :title "Salesforce Alert"
                                    :severity 'urgent))))
                      (0
                       (funcall ,handle-success-lambda process json-instance ,buffer-view-post-process)))))))))))

(defun sfmm--helper:execute-command (command message-success)

  (sfmm--helper:make-sync-process
   command
   `(lambda (process output buffer)
      (unless (string= message-success "")
        (alert ,message-success :title "Salesforce Alert")))))

(cl-defun sfmm--helper:execute-async-command
    (&key command (message-success "") (message-failures ""))

  (sfmm--helper:make-async-process
   command
   `(lambda (process output buffer)
      (let* ((json (json-parse-string output))
             (is-success (sfmm--helper:get-data-hashtable "status" json)))

        (if (= is-success 1)
            (unless (string= ,message-success "")
             (alert ,message-success :title "Salesforce Alert"))
          (alert ,message-failures :title "Salesforce Alert"))))))

(cl-defun sfmm--helper:convert-hashtable-data-to-list
    (&key hashtable-data columns (post-process nil))
  "Convert hashtable data to list"
 (let ((data '()))

   (mapcar
      `(lambda (key)
         (when (member key columns)
           (let ((value (gethash key hashtable-data)))

             (when (eq value ':null)
               (setq value " "))
             (when (eq value ':false)
               (setq value "False"))
             (when (eq value 't)
               (setq value "True"))
             (when (eq value 'nil)
               (setq value " "))

             (add-to-list 'data value 1
                          '(lambda (element1 element2) nil))

             (when ,post-process
               (funcall ,post-process key value)))))
      columns)
   data))

(defun sfmm--helper:recursive-list (list-data lambda-function)
  ""
  (let* ((new-list (cdr list-data))
         (first-item (car list-data))
         (remap-list '()))

    (when (length> new-list 0)
        (setq remap-list
              (append remap-list
                      (sfmm--helper:recursive-list new-list lambda-function))))

    (add-to-list 'remap-list (funcall lambda-function first-item))))

(defun sfmm--helper:get-data-hashtable (path table)
  "Get all data follow the path in hash table"
  (let* ((path-splited (split-string path "\\."))
         (key (car path-splited))
         (key-remain (cdr path-splited)))

    (if key-remain
      (sfmm--helper:get-data-hashtable
       (string-join key-remain ".")
       (gethash key table))

     (gethash key table))))

(cl-defun sf--build:create-table-component (&key model buffer open)
  "Use ctable to build table data"
  (let ((component (ctbl:create-table-component-buffer
                    :model model
                    :buffer (get-buffer-create buffer))))
    (when open
      (with-current-buffer (switch-to-buffer (ctbl:cp-get-buffer component))
        (ctbl:table-mode)
        (read-only-mode)))
    component))

(cl-defun sf--build:make-table-model (&key column-header data)
  "Use ctable to build table data"
  (let ((column-model
         (mapcar 'sf--build:make-header-table column-header))
        (async-model
         (ctbl:async-model-wrapper data)))

   (make-ctbl:model
    :column-model column-model :data async-model)))

(defun sf--build:make-header-table (header-config)
  "Build header ctable"
  (let* ((title
          (plist-get header-config :title))
         (min-width
          (plist-get header-config :min-width))
         (max-width
          (plist-get header-config :max-width))
         (align
          (plist-get header-config :align)))

    (make-ctbl:cmodel
     :title title
     :sorter 'ctbl:sort-number-lessp
     :min-width min-width
     :max-width max-width
     :align align)))

(cl-defun sf--build:make-data-table-from-vector
    (&key header-columns data (enable-count-rows t))
  "Build data from input hash table and header-columns"
  (let ((data-table ()))
    (dotimes (i (length data))
      (let ((row (append (list (+ i 1))
                         (mapcar `(lambda (key)
                                    (let ((value (gethash key ,(aref data i))))

                                      (if (hash-table-p value)
                                          (gethash "url" value)
                                        (cond ((eq value ':null)
                                               "")
                                              ((eq value ':false)
                                               "False")
                                              ((eq value 't)
                                               "True")
                                              (t
                                               value)))))

                                 header-columns))))
        (add-to-list 'data-table row 1 '(lambda (v1 v2)
                                             nil))))
    data-table))

(defun sfmm:site:list ()
  ""
  (interactive)
  (let* ((execute-soql-code
          (sfmm--helper:generate-command (list sfmm:data-command-alias "query" "--query" "SELECT PathPrefix, Domain.Domain, Domain.HttpsOption, Site.Status, Site.SiteType FROM DomainSite"))))

    (sfmm--helper:make-sync-process
     :command execute-soql-code
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (let* ((records-list (sfmm--helper:get-data-hashtable "result.records" json-instance))
              (start-index 1)
              (column-header-map #s(hash-table test equal data ("No" ((:align . 'left) (:title . "No"))))))

         (mapc
           (lambda (element)

             (let ((row `(,start-index)))
               (maphash
                (lambda (key value)
                  (let ((column-config `((:align . ,'left) (:title . ,key))))
                    (unless (hash-table-p value)
                      (cond ((eq value ':null)
                             (setq value " "))
                            ((eq value ':false)
                             (setq value "False"))
                            ((eq value 't)
                             (setq value "True")))

                      (add-to-list 'row
                                   (replace-regexp-in-string "\\([\n]\\)" "" value) 1
                                   '(lambda (element1 element2) nil))

                      (when (length> value 50)
                        (add-to-list 'column-config `(:max-width . ,'50)))

                      (puthash (format "%s" key) column-config column-header-map))))
                element)
               (setq start-index (1+ start-index))
               row))
           records-list)
         (sf--build:make-table-model
          :column-header (hash-table-values column-header-map)
          :data records-list))))))

(defun sfmm:hook-on-handler ()
  ""
  (setq org-default-alias (sfmm:org:show-current-org))
  (when org-default-alias
    (add-to-list 'mode-line-misc-info '(" " org-default-alias " "))
    (sfmm:org:connect-status)))


(defun sfmm:hook-off-handler ()
  ""
  (setq org-default-alias (sfmm:org:show-current-org))
  (when org-default-alias
    (setq mode-line-misc-info
        (delete '(" " org-default-alias " ") mode-line-misc-info))))

(defun sfmm:org:clear-log ()
  "clear all apex log on org."
  (interactive)
  (let ((temp-file (make-temp-file "log" nil ".csv")))

    (sfmm--helper:make-async-process
      :command
      (sfmm--helper:generate-command
       (list sfmm:data-command-alias "query" "--query" "SELECT Id FROM ApexLog" "-t" "-r" "csv"))
      :handle-error-lambda
      (lambda (process data buffer) _)
      :handle-success-lambda
      `(lambda (process data buffer)
         (with-current-buffer ,temp-file
           (insert data))

         (sfmm--helper:make-async-process
           :command
           (sfmm--helper:generate-command
            (list sfmm:data-command-alias "delete" "bulk" "--sobject" "ApexLog" "--file" ,temp-file "--json"))
           :handle-success-lambda
           (lambda (process json-instance buffer)
             (alert "clear log success"
                    :title "Success")))))))

(define-minor-mode salesforce-minor-mode
  "Toggles global salesforce minor mode."
  nil ; Inital value, nil for disabled
  :global t
  :group 'salesforce
  :lighter " salesforce-minor-mode"

  (add-hook 'salesforce-minor-mode-on-hook #'sfmm:hook-on-handler)

  (add-hook 'salesforce-minor-mode-off-hook #'sfmm:hook-off-handler))

(provide 'salesforce-minor-mode) ;;; salesforce-minor-mode end here.
