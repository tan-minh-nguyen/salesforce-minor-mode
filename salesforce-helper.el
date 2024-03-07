(require 'salesforce-config)

(defun sfmm--internal:generate-command (commands)
  (add-to-list 'commands sfmm:sfdx-lib-alias))

(defun sfmm--internal:build-sf-command (&rest args)
  `(,sfmm:sfdx-lib-alias ,@args))

(defun sfmm--internal:execute-apex (content)
 emacs make-process pipe "Execute code"
  (let ((code (unless content
               (point-min)
               content))
        (temp-file (make-temp-file "temp_code")))

   (write-region (point-min) (point-max) temp-file)
   (setq execute-apex-code-command
     (sfmm--internal:generate-command "apex" "run" "-f" temp-file))

   (async-shell-command execute-apex-code-command buffer)))

(cl-defun sfmm--internal:execute-soql (&key query (type 'string) options)
  "Excute command fetch records from Salesforce through api"
  (let* ((options
          (cond ((equal type 'string)
                 (list "--query" query))
                ((equal type 'file)
                 (list "--file" query))))
         (execute-soql-code
          (append (sfmm--internal:generate-command (list sfmm:data-command-alias "query" "--json"))
                  options)))

    (sfmm--internal:make-async-process
     :command execute-soql-code
     :handle-success-lambda
     (lambda (process json-instance buffer)
       
       (when (length= (sfmm--internal:get-data-hashtable "result.records" json-instance) 0)
         (alert "No records found"
                :title "Salesforce Query")
         (error "No records found"))

       (let* ((records-list (sfmm--internal:get-data-hashtable "result.records" json-instance))
              (header-columns (remove-if (lambda (key) (member key '("attributes")))
                                         (hash-table-keys (aref records-list 0))))
              (data (sf--build:make-data-table-from-vector
                     :header-columns header-columns
                     :data records-list)))

         (add-to-list 'header-columns "No")

         (with-current-buffer (pop-to-buffer
                               (sf--build-table:create-table
                                :model
                                (sf--build-table:make-table-mode
                                 :column-header
                                 (cl-loop for key in header-columns
                                          when (not (string= key ""))
                                          collect `(:align ,'left :title ,key `:max-width ,'50))
                                 :data data)
                                :buffer sfmm:dedicated-window-right
                                :open 't))
           (ctbl:table-mode)
           (read-only-mode)))))))

(cl-defun sfmm--internal:make-sync-process (&key command handle-success-lambda handle-error-lambda)
  (sfmm--internal:make-process
   :type 'sync
   :command command
   :handle-success-lambda handle-success-lambda
   :handle-error-lambda handle-error-lambda))

(cl-defun sfmm--internal:make-async-process
    (&key command buffer-name handle-success-lambda handle-error-lambda)
  "Make async process"
  (sfmm--internal:make-process
   :type 'async
   :command command
   :handle-success-lambda handle-success-lambda
   :handle-error-lambda handle-error-lambda))

(cl-defun sfmm--internal:make-process
    (&key type command handle-success-lambda handle-error-lambda ignore-error)
  ""
  (when (not (member type '(async sync)))
    (error "Invalid type of process"))
  (with-environment-variables (("NODE_NO_WARNINGS" "1"))

    (let* ((process-identity "salesforce")
           (buffer-process (get-buffer-create sfmm:process-buffer))
           (buffer-stdout (get-buffer-create sfmm:process-success-buffer))
           (buffer-stderr (get-buffer-create sfmm:process-error-buffer))
           (process-error (make-pipe-process
                           :name sfmm:process-error-buffer
                           :buffer buffer-stderr
                           :sentinel
                           `(lambda (process event)
                              (unless ,ignore-error
                                (with-current-buffer ,buffer-stderr
                                 (beginning-of-buffer)

                                 (condition-case nil
                                     (json-parse-buffer)
                                   (error (cond ((= (buffer-size) 0)
                                                 nil)
                                                (t
                                                 (alert (replace-regexp-in-string "" "" (buffer-string))
                                                        :title "Salesforce Alert"
                                                        :severity 'urgent)))))
                                 (erase-buffer)))
                              (delete-process process))))
           (process
            (make-process
             :name sfmm:process-success-buffer
             :buffer buffer-process
             :filter
             (lambda (process output)
               (with-current-buffer (get-buffer-create sfmm:process-success-buffer)
                 (insert output)))
             :stderr process-error
             :command command)))

       (pcase type
         ('async
          (set-process-sentinel process
                                `(lambda (process event)
                                  (with-current-buffer (get-buffer-create ,sfmm:process-success-buffer)
                                    (beginning-of-buffer)

                                    (condition-case json-instance
                                        (json-parse-buffer)
                                      (error (cond ((= (buffer-size) 0)
                                                    nil)
                                                   ((not (member "--json" ',command))
                                                    (funcall ,handle-success-lambda process (buffer-string) ,sfmm:process-success-buffer))
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
                                                      (funcall ,handle-error-lambda process json-instance ,sfmm:process-error-buffer))
                                                     (t
                                                      (alert (gethash "message" json-instance)
                                                            :title "Salesforce Alert"
                                                            :severity 'urgent))))
                                              (0
                                               (funcall ,handle-success-lambda process json-instance ,sfmm:process-success-buffer)))))
                                    (erase-buffer)))))
         ('sync
          (when (accept-process-output process))

          (with-current-buffer (get-buffer-create sfmm:process-success-buffer)
            (beginning-of-buffer)

            (let ((data (condition-case json-instance
                            (json-parse-buffer)
                         (error
                          (cond ((= (buffer-size) 0)
                                 nil)
                                ((not (member "--json" command))
                                 (buffer-string))
                                (t
                                 (alert (buffer-string)
                                        :title "Salesforce Alert"
                                        :severity 'urgent)
                                 nil)))
                         (:success
                          (pcase (cond ((gethash "status" json-instance)
                                        (gethash "status" json-instance))
                                       ((gethash "code" json-instance)
                                        (gethash "code" json-instance)))
                            (1
                             (cond (handle-error-lambda
                                    (funcall handle-error-lambda process json-instance sfmm:process-error-buffer)
                                    nil)
                                   (t
                                    (alert (gethash "message" json-instance)
                                           :title "Salesforce Alert"
                                           :severity 'urgent)
                                    nil)))

                            (0
                             json-instance))))))
              (erase-buffer)
              data)))))))

(defun sfmm--internal:execute-command (command message-success)

  (sfmm--internal:make-sync-process
   command
   `(lambda (process output buffer)
      (unless (string= message-success "")
        (alert ,message-success :title "Salesforce Alert")))))

(cl-defun sfmm--internal:execute-async-command
    (&key command (message-success "") (message-failures ""))

  (sfmm--internal:make-async-process
   command
   `(lambda (process output buffer)
      (let* ((json (json-parse-string output))
             (is-success (sfmm--internal:get-data-hashtable "status" json)))

        (if (= is-success 1)
            (unless (string= ,message-success "")
             (alert ,message-success :title "Salesforce Alert"))
          (alert ,message-failures :title "Salesforce Alert"))))))

(cl-defun sfmm--internal:convert-hashtable-data-to-list
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

(defun sfmm--internal:recursive-list (list-data lambda-function)
  ""
  (let* ((new-list (cdr list-data))
         (first-item (car list-data))
         (remap-list '()))

    (when (length> new-list 0)
        (setq remap-list
              (append remap-list
                      (sfmm--internal:recursive-list new-list lambda-function))))

    (add-to-list 'remap-list (funcall lambda-function first-item))))

(defun sfmm--internal:get-data-hashtable (path table)
  "Get all data follow the path in hash table"
  (let* ((path-splited (split-string path "\\."))
         (key (car path-splited))
         (value (cond ((arrayp table)
                       (aref table (string-to-number key)))
                      (t
                       (gethash key table))))
         (key-remain (cdr path-splited)))

    (cond (key-remain
           (sfmm--internal:get-data-hashtable
            (string-join key-remain ".")
            value))
          (t
           value))))

(defun sfmm--internal:find-root-dir ()
  (let* ((project (project-current)))
    (cdr project)))

(defun sfmm--internal:build-full-path (&rest args)
  (mapconcat 'identity `(,(sfmm--internal:find-root-dir) ,@args) "/"))

(defun sfmm--internal:org-alias-list ()
  "Get all alias of orgs."
  (let* ((json-instance (sfmm--internal:make-process
                          :type 'sync
                          :command
                          (sfmm--internal:build-sf-command sfmm:org-command-alias "list" "--json" "--skip-connection-status")))
         (other-org-list (mapcar (lambda (data)
                                     (gethash "alias" data))
                                 (sfmm--internal:get-data-hashtable
                                  "result.other" json-instance)))
         (non-scratch-org-list (mapcar (lambda (data)
                                          (gethash "alias" data))
                                       (sfmm--internal:get-data-hashtable
                                        "result.nonScratchOrgs" json-instance))))
    (append other-org-list non-scratch-org-list)))



(provide 'salesforce-helper)
