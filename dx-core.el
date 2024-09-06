;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-config)
(require 'dx-process)

(defun dx-build-sf-command (&rest args)
  `(,dx-lib-alias ,@args))

(defun dx-execute-apex (content)
"emacs make-process pipe Execute code"
  (let ((code (unless content
               (point-min)
               content))
        (temp-file (make-temp-file "temp_code")))

   (write-region (point-min) (point-max) temp-file)
   (setq execute-apex-code-command
     (dx-build-sf-command "apex" "run" "-f" temp-file))

   (async-shell-command execute-apex-code-command buffer)))

(cl-defun dx-execute-soql (&key query (type 'string) options)
  "Excute command fetch records from Salesforce through api"
  (let ((execute-soql-code (dx-build-sf-command dx-data-command-alias
                                                 "query"
                                                 (pcase type
                                                   ('string
                                                    `,@("--query" query))
                                                   ('file
                                                    `,@("--file" query)))
                                                 "--json")))

    (dx-make-process-json
     :cmd execute-soql-code
     (when (length= (dx-get-data-json "result.records" json-instance) 0)
       (alert "No records found"
              :title "Salesforce Query")
       (error "No records found"))

     (let* ((records-list (dx-get-data-json "result.records" json-instance))
            (header-columns (remove-if (lambda (key) (member key '("attributes")))
                                       (hash-table-keys (aref records-list 0))))
            (data (dx-table--make-data-table-from-vector
                   :header-columns header-columns
                   :data records-list)))

       (add-to-list 'header-columns "No")

       (with-current-buffer (pop-to-buffer
                             (dx-table--create-table
                              :model
                              (dx-table--make-table-mode
                               :column-header
                               (cl-loop for key in header-columns
                                        when (not (string= key ""))
                                        collect `(:align ,'left :title ,key `:max-width ,'50))
                               :data data)
                              :buffer dx-dedicated-window-right
                              :open 't))
         (ctbl:table-mode)
         (read-only-mode))))))

(cl-defun dx-convert-hashtable-data-to-list
    (&key hashtable-data columns (post-process nil))
  "Convert hashtable data to list"
  (let ((data '()))

    (mapcar
     `(lambda (key)
        (when (member key columns)
          (let ((value (plist-get ,hashtable-data key (lambda (prop key)
                                                        (string= (format ":%s" key) (symbol-name prop))))))

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

(defun dx-recursive-list (list-data lambda-function)
  ""
  (let* ((new-list (cdr list-data))
         (first-item (car list-data))
         (remap-list '()))

    (when (length> new-list 0)
        (setq remap-list
              (append remap-list
                      (dx-recursive-list new-list lambda-function))))

    (add-to-list 'remap-list (funcall lambda-function first-item))))

(defun dx-get-data-json (path table)
  "Get all data follow the path in hash table"
  (let* ((path-splited (split-string path "\\."))
         (key (car path-splited))
         (value (cond
                 ((plistp table)
                  (plist-get table key (lambda (prop key)
                                         (string= (format ":%s" key) (symbol-name prop)))))
                 ((arrayp table)
                  (aref table (string-to-number key)))
                 (t
                  (gethash key table))))
         (key-remain (cdr path-splited)))

    (cond (key-remain
           (dx-get-data-json
            (string-join key-remain ".")
            value))
          (t
           value))))

(defun dx-find-root-dir ()
  (cdr (project-current)))

(defun dx-build-full-path (&rest args)
  (mapconcat 'identity `(,(dx-find-root-dir) ,@args) "/"))

(defmacro dx-org-alias-list (&rest body)
  "Get all alias of orgs."
  `(let* ((json-instance (dx-make-process-json-sync
                          :cmd (dx-build-sf-command dx-org-command-alias
                                                    "list"
                                                    "--json"
                                                    "--skip-connection-status")))

          (org-list (remove-if #'null (append (mapcar (lambda (data)
                                                        (plist-get data :alias))
                                                      (dx-get-data-json
                                                       "result.other" json-instance))
                                              (mapcar (lambda (data)
                                                        (plist-get data :alias))
                                                      (dx-get-data-json
                                                       "result.nonScratchOrgs" json-instance))))))
     ,@body))



(defun dx-web-login (url)
  "Authorize to `url' salesforce org."
  (dx-org-alias-list
   (let ((alias (completing-read "Alias: " org-list nil nil)))

     (dx-make-process-json-async
      :cmd (dx-build-sf-command dx-org-command-alias "login" "web" "-a" alias "--instance-url" url "--set-default" "--json")
      (let ((user-name (dx-get-data-json "result.username" json-instance)))
        (alert "Authorize success" :title "Salesforce Alert"))))))

(defun dx-handle-process-error--json (json-instance)
  "Handle error response by dx process."
  (let ((show-message "")
        (error-name (plist-get json-instance :name))
        (error-message (plist-get json-instance :message)))

    (cond ((and error-name
                error-message)
           (setq show-message (format "Name: %s\nMessage: \n%s\n" error-name error-message)))
          (t
           (setq show-message (mapconcat (lambda (component)
                                           (let ((problem (plist-get component :error))
                                                 (problem-type (plist-get component :problemType))
                                                 (line-number (plist-get component :lineNumber))
                                                 (file-name (plist-get component :filePath)))

                                             (format "Problem-type: %s\nProblem: %s\n%s:%s"
                                                     problem-type
                                                     problem
                                                     line-number
                                                     file-name)))

                                         (dx-get-data-json "result.deployedSource" json-instance)
                                         "\n"))))

    (alert show-message
           :title "DX Alert"
           :category 'error
           :severity 'urgent)))

;;;###autoload
(cl-defun dx-internal-current-org ()
  (let* ((root-dir (dx-find-root-dir))
         (config-path (concat root-dir ".sf/config.json"))
         (old-config-path (concat root-dir ".sfdx/sfdx-config.json")))

    (cond
     ;; Return empty string if config files not exist
     ((not (or (file-exists-p config-path)
             (file-exists-p old-config-path)))
      "")
     ;; Return org name var if root dir not change
     ((and (string= root-dir dx-project-root-dir)
         dx-org-name)
      dx-org-name)
     ;; Find org alias in root dir
     (t
      (condition-case org-name
          (string-replace "\n" ""
                          (shell-command-to-string (concat "[ -f " config-path " ] && grep -Po '(?<=\"target-org\": )\"[^\"]+\"' " config-path " | sed -E 's/\"([^\"]+)\"/\\1/' || grep -Po '(?<=\"defaultusername\": )\"[^\"]+\"' " old-config-path " | sed -E 's/\"([^\"]+)\"/\\1/'")))
        (:success org-name)
        (error
         (dx-get-data-json "result.0.value"
                           (dx-make-process-json-sync
                            :cmd (dx-build-sf-command "config" "get" "target-org" "--json")))))))))

(defun dx--get-cache-folder-path ()
  "Get absolute path of cache directory."
  (let ((cache-dir (expand-file-name (concat dx-org-cache-dir dx-org-name "/") (dx-find-root-dir))))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir 'parents))

    cache-dir))

(defun dx--get-log-dir-path ()
  "Get absolute path of log directory."
  (let ((cache-dir (expand-file-name (concat dx-log-dir-path "/") (dx-find-root-dir))))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir 'parents))

    cache-dir))

(defmacro dx--find-backup-files (file-name &optional dir)
  "Find backup files."
  `(when-let* ((org-name dx-org-name)
               (default-directory (or ,dir (dx--get-cache-folder-path))))

     (directory-files-recursively default-directory
                                  ,file-name)))

(defmacro dx--find-backup-file (file-name &optional dir)
  "Find backup file."
  `(car (dx--find-backup-files ,file-name ,dir)))

(defun dx--org-status (&optional org)
  "Check current org status."
  (let ((json-instance (dx-make-process-json-sync
                        :cmd (append (dx-build-sf-command dx-org-command-alias "display" "--json")
                                     (when org (list "-o" org))))))
    (cond ((= (plist-get json-instance :status) 0)
           (dx-get-data-json "result.connectedStatus" json-instance))
          (t (funcall #'dx-handle-process-error--json json-instance)))))

(defun dx--get-lwc-directory ()
  "Get lwc directory."
  (expand-file-name dx-default-lwc-path (dx-find-root-dir)))

(defun dx--find-parents (file &optional depth)
  "Find parents of directory."
  (if (< depth 1)
      (file-name-directory (directory-file-name file))
    (dx--find-parents (file-name-directory (directory-file-name file)) (- depth 1))))

(provide 'dx-core)
