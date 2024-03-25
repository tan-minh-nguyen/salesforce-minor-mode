;; -*- no-byte-compile: t; no-native-compile: t -*-
(require 'salesforce-config)

(defun sfmm:note:news ()
  "What news on sf cli."
  (interactive)
  (with-current-buffer (pop-to-buffer (get-buffer-create "*sf-note-news*"))
    (delete-selection-mode 1)

    (insert (shell-command-to-string "sf whatsnew"))))

(defun sfmm:project:create ()
  "Create dx project"
  (interactive)
  (let* ((project-path (read-string "project-path: "))
         (package-dir (read-string "package-dir: "))
         (command (sfmm--internal:build-sf-command
                   sfmm:project-command-alias
                   "generate"
                   "--name" project-path
                   "--default-package-dir" package-dir
                   "--json")))

    (make-directory project-path 'parents)

    (sfmm--internal:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (let ((project-output (sfmm--internal:get-data-hashtable "result.outputDir" json-instance)))

          (alert "Create Project Success"
                 :title "Salesforce Alert"))))))

(defun sfmm:source:push ()
  "Push file to salesforce org."
  (interactive)
  (let* ((file-name buffer-file-name)
         (push-command (sfmm--internal:build-sf-command "force" "source" "deploy" "-p" file-name "--json")))

    (sfmm:org:source-backup)

    (sfmm--internal:make-async-process
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
                                                         (gethash "problemType" component)
                                                         (gethash "error" component)
                                                         (gethash "lineNumber" component)
                                                         (gethash "filePath" component))))

                                             (sfmm--internal:get-data-hashtable "result.deployedSource" json-instance)
                                             "\n"))))

         (alert show-message
                :title "Salesforce Alert"
                :category 'error
                :severity 'urgent))))))

(defun sfmm:source:retrieve
    ()
  "Retrieve source salesforce form org"
  (interactive)
  (let ((retrieve-command (sfmm--internal:build-sf-command "force" "source" "retrieve" "-p" buffer-file-name "--json")))

    (sfmm--internal:make-async-process
     :command retrieve-command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (alert (format "Retrieve %s success" ,buffer-file-name)
               :title "Salesforce Alert")))))

(cl-defun sfmm:org:source-backup (&key target-org)
  "Backup the current buffer to the source directory."
  (let* ((json-instance nil)
         (buffer (buffer-file-name))
         (file-name (file-name-base buffer))
         (cache-dir (concat (sfmm--internal:find-root-dir)
                            sfmm:org:cache-dir
                            (cond (target-org
                                   target-org)
                                  (t
                                   (sfmm--internal-current-org)))
                            "/"))
         (backup-file-name (concat file-name "_" (format "%s" (time-convert (current-time) 'integer))))
         (command (append (sfmm--internal:build-sf-command sfmm:project-command-alias "retrieve" "start" "-d" buffer "-z" "-t" cache-dir "--zip-file-name" backup-file-name "--json")
                          (when target-org `("-o" ,target-org))))

         (json-instance (progn (unless (file-exists-p cache-dir)
                                 (make-directory cache-dir 'parents))
                               (sfmm--internal:make-process
                                :type 'sync
                                :command command))))
    (unless json-instance
      (error (concat "Backup " file-name " Failure")))
    ;; rename backup directory to new directory containing the last modified id
    ;; and the last modified date
    (let ((new-dir-name (concat cache-dir backup-file-name "_"
                                (sfmm--internal:get-data-hashtable "result.fileProperties.0.lastModifiedById"
                                                                 json-instance)
                                "_"
                                (format "%s"
                                        (time-convert
                                         (date-to-time
                                          (sfmm--internal:get-data-hashtable "result.fileProperties.0.lastModifiedDate"
                                                                           json-instance))
                                         'integer)))))

         (rename-file (concat cache-dir backup-file-name)
                      new-dir-name)
         new-dir-name)))

(defun sfmm:diff:deploy-metadata (branch)
  "Use for deploy diff change between two branches."
  (interactive ("Brach deploy: "))
  (let (sf-command (sfmm--internal:build-sf-command
                    "deploy" "functions" "--connected-org" sfmm:org-name
                    "--branch" branch "--json"))

    (sfmm--internal:make-process
     :type 'async
     :command sf-command
     :handle-success-lambda
     `(lambda (_ json-instance buffer)

        (alert "Deploy metadata success"
               :title "Saleforce Alert")))))

(defun sfmm--ediff-startup-hook ()
  "Ediff hook on startup."
  (let ((coding-system (with-current-buffer ediff-buffer-B
                         buffer-file-coding-system)))

    ;; Set coding for buffer A
    (with-current-buffer ediff-buffer-A
      (set-buffer-file-coding-system coding-system t t))
    (ediff-toggle-read-only ediff-buffer-A)

    (when ediff-buffer-C
      (ediff-toggle-read-only ediff-buffer-C)

      ;; Set coding for buffer C
      (with-current-buffer ediff-buffer-C
        (set-buffer-file-coding-system coding-system t t)))))

(defun sfmm--ediff-quit-hook ()
  "Hook on quit."
 (kill-buffer ediff-buffer-A)
 (when ediff-buffer-C
   (kill-buffer ediff-buffer-C))

 ; Clear hooks
 (remove-hook 'ediff-startup-hook #'sfmm--ediff-startup-hook)
 (remove-hook 'ediff-quit-hook #'sfmm--ediff-quit-hook))

(defun sfmm:diff-metadata ()
  "diff metadata between local and cloud."
  (interactive)
  (let ((file-name (buffer-file-name))
        (backup-file-name (sfmm:org:source-backup)))

    (condition-case error
        (ediff (car (directory-files-recursively (concat backup-file-name "/") (file-name-nondirectory file-name))) file-name
               '((lambda ()
                  (add-hook 'ediff-startup-hook #'sfmm--ediff-startup-hook)
                  (add-hook 'ediff-quit-hook #'sfmm--ediff-quit-hook))))


     (error
      (alert error
             :title "Salesforce Alert"
             :severity 'urgent)))))

(defun sfmm:diff3-metadata ()
  "diff metadata between multiple enviroment."
  (interactive)
  (let* ((minibuffer-history (sfmm--internal:org-alias-list))
         (file-name (buffer-file-name))
         (target-org (read-from-minibuffer "Target Org: "))
         (bk-file-org (sfmm:org:source-backup))
         (bk-file-target-org (sfmm:org:source-backup
                              :target-org target-org)))

    (condition-case error
        (ediff3 (car (directory-files-recursively (concat bk-file-org "/") (file-name-nondirectory file-name))) file-name (car (directory-files-recursively (concat bk-file-target-org "/") (file-name-nondirectory file-name)))
                '((lambda ())
                  (add-hook 'ediff-startup-hook #'sfmm--ediff-startup-hook)
                  (add-hook 'ediff-quit-hook #'sfmm--ediff-quit-hook)))
      (error
       (alert error
              :title "Salesforce Alert"
              :severity 'urgent)))))

(defun sfmm:source-tracker ()
  (interactive)
  (let* ((folder-name (file-name-base buffer-file-name))
         (file-name (file-name-nondirectory buffer-file-name))
         (sfmm:dedicated-window-right "*Org Tracker*")
         (folder-path (expand-file-name
                       (format "%s*/**/%s"
                              (concat (cdr (project-current))
                                      sfmm:org:cache-dir
                                      (sfmm--internal-current-org)
                                      "/"
                                      folder-name)
                              file-name)))
         (model
          (sf--build-table:make-table-mode
           :column-header
           `((:title "Backup DateTime")
             (:title "User Modified Id")
             (:title "Last Modified DateTime"))
           :data
           (remove 'nil
                   (mapcar (lambda (folder)
                            ;; format files show on buffer
                            (when-let* ((columns (string-split folder " "))
                                        (date-time (format-time-string "%Y/%m/%d %H:%M:%S" (string-to-number (nth 0 columns))))
                                        (user-id (nth 1 columns))
                                        (last-modified-date (format-time-string "%Y/%m/%d %H:%M:%S" (string-to-number (nth 2 columns)))))

                              `(,date-time ,user-id ,last-modified-date ,(concat (nth 3 columns) "_" (nth 0 columns) "_" user-id "_" (nth 2 columns)))))
                          ;; list of file names
                          (split-string (shell-command-to-string
                                         ;; script list all files with name
                                         (concat "ls " folder-path " -ta"
                                                 " | " "sed -E 's/.+\\/([a-zA-Z]+)\\_([[:digit:]]+)\\_([A-Za-z0-9]+)\\_([[:digit:]]+)\\/.+$/\\2 \\3 \\4 \\1/'"))
                                        "\n")))))
         (component
          (sf--build-table:create-table
           :model model
           :buffer sfmm:dedicated-window-right)))

    (ctbl:cp-add-click-hook component
                            `(lambda ()
                              (when-let* ((data (ctbl:cp-get-selected-data-row ,component))
                                          (cache-dir (concat (cdr (project-current))
                                                             sfmm:org:cache-dir
                                                             sfmm:org-name
                                                             "/"
                                                             (nth 3 data))))
                                (ediff (car (directory-files-recursively cache-dir ,file-name))
                                       ,buffer-file-name
                                       '((lambda ()
                                           (add-hook 'ediff-startup-hook #'sfmm--ediff-startup-hook)
                                           (add-hook 'ediff-quit-hook #'sfmm--ediff-quit-hook)))))))

    (pop-to-buffer (ctbl:cp-get-buffer component))))

(defun sfmm:org:specific-open ()
   "Use a specific user name to open org"
   (interactive)
   (let ((user-name (ctbl:cp-get-selected-data-cell (ctbl:cp-get-component))))

     (unless user-name
       (setq user-name (read-string "user-name: ")))

     (sfmm--internal:make-sync-process
      :command
      (sfmm--internal:generate-command (list "org" "open" "--json" "-o" user-name "-r"))
      :handle-success-lambda
      (lambda (process json-instance buffer)
        (let ((url (sfmm--internal:get-data-hashtable "result.url" json-instance)))

          (shell-command (format "%s --target %s %S"
                                 sfmm:default-browser
                                 "tab"
                                 url)))))))

(defun sfmm:org:default-open ()
   "Open default org"
   (interactive)
   (let ((command (sfmm--internal:generate-command (list "org" "open" "--json" "-r"))))

     (sfmm--internal:make-async-process
      :command command
      :handle-success-lambda
      (lambda (process json-instance buffer)
        (let ((url (sfmm--internal:get-data-hashtable "result.url" json-instance)))

          (shell-command (concat sfmm:default-browser (format " %S " url) " -r " " tab ") "*vc-log*"))))))

(defun sfmm--internal:fetch-all-users-org (org-type)
  "Display all current connect org"
  (sfmm--internal:make-async-process
   :command
   (sfmm--internal:build-sf-command sfmm:org-command-alias "list" "--json")
   :handle-success-lambda
   (lambda (process json-instance buffer)
     (pop-to-buffer
      (sf--build-table:create-table
       :model
       (sf--build-table:make-table-mode
        :column-header
        (mapcar (lambda (column-name)
                  (list :title column-name :align 'left :max-width '50))
                sfmm:org:list-header-display)
        :data
        (mapcar (lambda (data)
                  (mapcar (lambda (column-name)
                            (let ((value (gethash column-name data)))

                              (pcase value
                                (:false "false")
                                (:true  "true")
                                (_ value))))
                          sfmm:org:list-header-display))
                (sfmm--internal:get-data-hashtable
                 (concat "result." org-type) json-instance))))
      :buffer sfmm:dedicated-window-right))))

(defun sfmm:org:display-all-orgs ()
  (interactive)
  (sfmm--internal:fetch-all-users-org "other"))

(defun sfmm:org:display-all-devhubs ()
  (interactive)
  (sfmm--internal:fetch-all-users-org "devhubs"))

(defun sfmm:org:connect-status ()
  "Check connect status to org"
  (let ((display-org-information-command (sfmm--internal:generate-command (list sfmm:org-command-alias "display" "--json"))))

    (sfmm--internal:make-async-process
     :command display-org-information-command
     :handle-success-lambda
     (lambda (process json-instance buffer)
        (let* ((status (sfmm--internal:get-data-hashtable "result.connectedStatus" json-instance)))
          (when (string= status
                         "RefreshTokenAuthError")
            (alert "Token expired !!" :title "Salesforce Alert")))))))

;;;###autoload
(cl-defun sfmm--internal-current-org ()
  (let* ((root-dir (sfmm--internal:find-root-dir))
         (config-path (concat root-dir ".sf/config.json"))
         (old-config-path (concat root-dir ".sfdx/sfdx-config.json")))

    ;; Return empty string if config files not exist
    (unless (or (file-exists-p config-path)
                (file-exists-p old-config-path))
      (cl-return ""))

    ;; Return org name var if root-dir not change
    (when (and (string= root-dir sfmm:project-root-dir)
               sfmm:org-name)
        sfmm:org-name)

    (condition-case org-name
        (string-replace "\n" ""
         (shell-command-to-string (concat "[ -f " config-path " ] && grep -Po '(?<=\"target-org\": )\"[^\"]+\"' " config-path " | sed -E 's/\"([^\"]+)\"/\\1/' || grep -Po '(?<=\"defaultusername\": )\"[^\"]+\"' " old-config-path " | sed -E 's/\"([^\"]+)\"/\\1/'")))
      (:success org-name)
      (error
        (sfmm--internal:get-data-hashtable "result.0.value"
                                          (sfmm--internal:make-process
                                           :type 'sync
                                           :command
                                           (sfmm--internal:build-sf-command "config" "get" "target-org" "--json")))))))

(defun sfmm:apex:get-all-log ()
  "Get log apex"
  (interactive)
  (let ((command (sfmm--internal:build-sf-command sfmm:apex-command-alias "list" "log" "--json")))

    (sfmm--internal:make-async-process
     :command command
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (let* ((records-list (sfmm--internal:get-data-hashtable "result" json-instance))
              (header-columns '("No" "Id" "Browser" "Operation"))
              (data (sf--build:make-data-table-from-vector
                     :header-columns header-columns
                     :data records-list)))

         (pop-to-buffer
          (sf--build-table:create-table
           :model
           (sf--build-table:make-table-mode
            :column-header
            (cl-loop for key in header-columns
                     collect `(:align ,'left :title ,key `:max-width ,'50))
            :data data)
           :buffer sfmm:dedicated-window-right
           :open t)))))))

(cl-defun sfmm:apex:get-log (&key log-id number org post-log-handle)
  "Get log apex"
  (sfmm--internal:make-async-process
   :command
   (append
    (sfmm--internal:build-sf-command
     sfmm:apex-command-alias "get" "log" "--json")
    (when org `("-o" ,org))
    (unless (string-empty-p log-id) `("--log-id" ,log-id))
    (unless (null number) `("--number" ,number)))
   :handle-success-lambda
   `(lambda (process json-instance buffer)

      (setq json-result (gethash "result" json-instance))
      (funcall ,post-log-handle (gethash "log" (aref json-result 0))))))

(cl-defun sfmm:apex:log-tail
    (&key (buffer-name "*apex-trace-log*") (org-id nil))
  :interactive
  (let (command (sfmm--internal:generate-command (list sfmm:apex-command-alias "get" "tail" "log" "--json")))

    (sfmm--internal:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process output)
         (let ((buffer (get-buffer-create ,buffer-name)))
           (with-current-buffer buffer
             (goto-char (point-max))
             (insert output)))))))

(defun sfmm:execute-apex-code ()
 (interactive)
 (sfmm--internal:execute-apex (point-min)))

(defun sfmm:org:change ()
   (interactive)
   (let* ((minibuffer-history (sfmm--internal:org-alias-list))
          (org-list-json (sfmm--internal:make-process
                          :type 'sync
                          :command
                          (sfmm--internal:build-sf-command sfmm:org-command-alias "list" "--json" "--skip-connection-status")))
          (switch-org (read-from-minibuffer "org-name: " nil nil nil nil sfmm:org-name))
          (json-instance (sfmm--internal:make-process
                          :type 'sync
                          :command (sfmm--internal:build-sf-command "config" "set" "target-org" switch-org  "--json")))
          (org-name (sfmm--internal:get-data-hashtable "result.successes.0.value" json-instance)))

     (setopt sfmm:org-name org-name)
     (alert (format "Change to %s success" org-name) :title "Saleforve Alert")))

(defun sfmm--internal:org:login (url)
   "Authorize to salesforce org"
   (let* ((alias (read-string "alias: "))
          (authorize-command
            (sfmm--internal:generate-command (list sfmm:org-command-alias "login" "web" "-a" alias "--instanceurl" url "--set-default" "--json"))))
    (sfmm--internal:make-async-process
     :command
     authorize-command
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (let ((user-name (sfmm--internal:get-data-hashtable "result.username" json-instance)))

         (alert "Authorize success" :title "Salesforce Alert")
         (sfmm--internal:make-sync-process
          :command
          (sfmm--internal:generate-command (list "org" "open" "--json" "-o" user-name "-r"))
          :handle-success-lambda
          (lambda (process json-instance buffer)
            (let ((url (sfmm--internal:get-data-hashtable "result.url" json-instance)))

              (shell-command (concat sfmm:default-browser " " (format "%S" url) " -r " " tab "))))))))))

(defun sfmm:org:authorize-sandbox ()
  "Authorize use for scratch org and sanbox org"
  (interactive)
  (let* ((url "https://test.salesforce.com"))

    (sfmm--internal:org:login url)))

(defun sfmm:org:authorize-production ()
  "Authorize use for dev org and production org"
  (interactive)
  (let* ((url "https://login.salesforce.com"))

    (sfmm--internal:org:login url)))

(defun sfmm:org:authorize-custom-url ()
  "Authorize use custom instance url for org"
  (interactive)
  (let* ((url (read-string "url: ")))

    (sfmm--internal:org:login url)))

(defun sfmm:soql:string ()
  "Fetch salesforce record by calling API through Salesforce CLI library"
  (interactive)
  (let* ((cache-dir (concat (sfmm--internal:find-root-dir) sfmm:org:cache-dir))
         ;; config local hook for minibuffer
         (minibuffer-history '())
         (minibuffer-mode-hook '((lambda ()
                                   (soql-ts-mode))))
         (max-mini-window-height 5)

         (soql-string (read-from-minibuffer "" nil nil nil nil)))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir))

    (sfmm--internal:execute-soql :query soql-string)))

(defun sfmm:fetch-record-through-file ()
  "Fetch record through file."
  (interactive)
  (let ((soql-file (read-from-minibuffer "SOQL-File: ")))

    (sfmm--internal:execute-soql :file soql-file)))

(defun sfmm:site:list ()
  ""
  (interactive)
  (sfmm--internal:execute-soql
   :query "SELECT PathPrefix, Domain.Domain, Domain.HttpsOption, Site.Status, Site.SiteType FROM DomainSite"))

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
         (command (sfmm--internal:build-sf-command sfmm:visualforce-command-alias "generate" "page" "--json" "--name" page-name "--label" page-label "--output-dir" (sfmm--internal:build-full-path sfmm:default-vf-path))))

    (sfmm--internal:make-sync-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        ;; Swtich new page
        (switch-to-buffer ,(find-file (concat (sfmm--internal:build-full-path sfmm:default-vf-path) "/" page-name ".page")))

        (alert (format "Create visualforce page" ,page-name)
               :title "Salesforce Alert")))))

(defun sfmm:visualforce:generate-component ()
  (interactive)
  (let* ((page-name (read-string "page name: "))
         (page-label (read-string "page label: "))
         (command (sfmm--internal:generate-command
                   (list sfmm:visualforce-command-alias "generate" "component" "--json" "--name" page-name "--label" page-label "--output-dir" (sfmm--internal:build-full-path sfmm:default-vf-components-path)))))

    (sfmm--internal:make-sync-process
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
         (command (sfmm--internal:build-sf-command
                   sfmm:apex-command-alias "generate" "trigger" "--name" class-name "--output-dir" (sfmm--internal:build-full-path sfmm:default-apex-trigger-path) "--json"))
         (class-expand ""))

    (sfmm--internal:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (let ((full-path-file ,(concat (sfmm--internal:build-full-path sfmm:default-apex-trigger-path) "/" class-name ".trigger")))
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
         (command (sfmm--internal:build-sf-command
                   sfmm:apex-command-alias "generate" "class" "--name" class-name "--output-dir" (sfmm--internal:build-full-path sfmm:default-apex-class-path) "--json"))
         (class-expand ""))

    (progn
      (unless (string= class-extend "")
        (setq class-expand (concat class-expand "extends" " " class-extend " ")))
      (unless (string= class-implements "")
        (setq class-expand (concat class-expand "implements" " " class-implements " "))))

    (sfmm--internal:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (switch-to-buffer ,(find-file (concat (sfmm--internal:build-full-path sfmm:default-apex-class-path) "/" class-name ".cls")))

        (goto-char (- (point-at-eol) 1))
        (insert ,class-expand)))))

(defun sfmm:apex:generate-test-class ()
  "Generate apex test class"
  (interactive)
  (let* ((class-name (read-string "class name: "))
         (command (sfmm--internal:generate-command
                   (list sfmm:apex-command-alias "generate" "class" "--name" class-name "--output-dir" (sfmm--internal:build-full-path sfmm:default-apex-class-path) "--json"))))

    (sfmm--internal:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)
        (let ((full-path-file ,(concat (sfmm--internal:build-full-path sfmm:default-apex-class-path) "/" class-name ".cls")))
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
         (command (sfmm--internal:generate-command
                    (list sfmm:lightning-command-alias "generate" "component" "--output-dir" output-dir "--name" component-name "--json"))))

    (when (string= type "component")
      (setq command
            (append command (list "--type" component-type))))

    (sfmm--internal:make-sync-process
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
   :output-dir (sfmm--internal:build-full-path sfmm:default-lwc-path)
   :message-success "Create %s success"
   :component-type "lwc"))

(defun sfmm:lightning-component:generate-aura ()
  "Generate Aura Component"
  (interactive)
  (sfmm:lightning:generate
   :type "component"
   :output-dir (sfmm--internal:build-full-path sfmm:default-aura-path)
   :message-success "Create aura component %s success"
   :component-type "aura"))

(defun sfmm:lightning-app:generate ()
  "Create lightning app"
  (interactive)
  (sfmm:lightning:generate
   :type "app"
   :output-dir (sfmm--internal:build-full-path sfmm:default-aura-path)
   :message-success "Create app %s sucesss"))

(defun sfmm:lightning-event:generate ()
  "Create lightning event"
  (interactive)
  (sfmm:lightning:generate
   :type "event"
   :output-dir (sfmm--internal:build-full-path sfmm:default-aura-path)))

(defun sfmm:lightning-interface:generate ()
  "Create lightning interface"
  (interactive)
  (sfmm:lightning:generate
   :type "interface"
   :output-dir (sfmm--internal:build-full-path sfmm:default-aura-path)
   :message-success "Create interface %s success"))

(defun sfmm:lightning-test:generate ()
  "Create lightning test"
  (interactive)
  (sfmm:lightning:generate
   :type "test"
   :output-dir (sfmm--internal:build-full-path sfmm:default-test-path)
   :message-success "Create test %s sucess"))

(cl-defun sfmm:apex:get-result-test-job
    (&key job-id)
  "Get result tests"
  (sfmm--internal:make-async-process
   :command
   (sfmm--internal:build-sf-command sfmm:apex-command-alias "get" "test" "-i" job-id "--json")
   :handle-success-lambda
   (lambda (process json-instance buffer)
     (let ((result-tests
            (mapconcat (lambda (result-test)
                         (let ((stack-trace (gethash "StackTrace" result-test))
                               (outcome (gethash "Outcome" result-test))
                               (error-message (gethash "Message" result-test))
                               (method-name (gethash "MethodName" result-test))
                               (class-name-test (sfmm--internal:get-data-hashtable "ApexClass.Name" result-test)))

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

                       (sfmm--internal:get-data-hashtable "result.tests" json-instance)
                       "\n")))
       (alert result-tests
              :title "Salesforce Alert")))))

(defun sfmm:apex:run-test-class ()
  "Run unit test for class"
  (interactive)
  (sfmm--internal:make-async-process
   :command
   (sfmm--internal:generate-command sfmm:apex-command-alias "run" "test" "--tests" (file-name-base) "--test-level" "RunSpecifiedTests" "--json")
   :handle-success-lambda
   (lambda (process json-instance buffer)
     (alert "Class tests run success"
            :title "Salesforce Alert")

     (sfmm:apex:get-result-test-job
      :job-id (sfmm--internal:get-data-hashtable "result.testRunId" json-instance)))))

(defun sfmm:apex:run-local-tests ()
  "Run all tests class expect tests class in org managed package"
  (interactive)
  (let ((command (sfmm--internal:generate-command (list sfmm:apex-command-alias "run" "test" "--test-level" "RunLocalTests" "--json"))))

    (sfmm--internal:make-async-process
     :command command
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (sfmm:apex:get-result-test-job (job-id (sfmm--internal:get-data-hashtable "result.testRunId" json-instance)))))))



(defun sfmm:server:local-lwc ()
  ""
  (interactive)
  (let ((command (sfmm--internal:generate-command (list sfmm:sfdx-legacy-alias "lightning" "lwc" "start" "--json"))))

    (sfmm--internal:make-async-process
     :command command
     :handle-success-lambda
     `(lambda (process json-string buffer)
        (alert "Start lwc local server success"
               :title "Salesforce Alert")))))

(defun sfmm:org:clear-log ()
  "clear all apex log on org."
  (interactive)
  (let ((temp-file (make-temp-file "log" nil ".csv"))
        (data (sfmm--internal:make-process
               :ignore-error t
               :type 'sync
               :command
               (sfmm--internal:build-sf-command
                sfmm:data-command-alias "query" "--query" "SELECT Id FROM ApexLog" "-t" "-r" "csv"))))

    (with-temp-file temp-file
      (when data
        (insert data)))

    (sfmm--internal:make-async-process
     :command
     (sfmm--internal:build-sf-command
      sfmm:data-command-alias "delete" "bulk" "--sobject" "ApexLog" "--file" temp-file "--json")
     :handle-success-lambda
     (lambda (process json-instance buffer)
       (alert "clear log success"
              :title "Success")))))

(defun sfmm:open-project-note ()
  "Open note for current project."
  (interactive)
  (if-let ((note-file (plist-get (cl-find-if (lambda (el)
                                               (string= (expand-file-name (plist-get el :project)) sfmm:project-root-dir))
                                             sfmm:project-config)
                                 :note-file)))

      (display-buffer-in-side-window (find-file-noselect
                                      (expand-file-name note-file))
                                     '((side . right)
                                       (window-width . 0.4)))
    (error "note file not found.")))

(provide 'salesforce-core)
