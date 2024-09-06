;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
;;; Code
(require 'projectile)
(require 'dx-config)
(require 'dx-process)
(require 'dx-core)

(defcustom dx-files-test-root '(".forceignore")
  "The list of files to determine a project is Salesforce project."
  :type 'list
  :group 'salesforce-project)

(defcustom dx-project-configuration '((nil . ((eval . (dx-minor-mode 1)))))
  "The list of configuration for Salesforce project."
  :type 'list
  :type 'salesforce-project)

(defun dx-project-p (&optional dir)
  "Check root is Salesforce project."
  (let ((default-directory (or dir (projectile-project-root)))
        (project-pass nil))

    (dolist (file dx-files-test-root)
      (setq project-pass (or project-pass (projectile-verify-file-wildcard file))))
    project-pass))

;;;###autoload
(defun dx-project-init ()
  "Initialize configuarion for Salesforce project."
  (when (eq (projectile-project-type) 'dx)
    (dir-locals-set-class-variables 'project-configuration dx-project-configuration)
    (dir-locals-set-directory-class (projectile-project-root) 'project-configuration)))

;; Define own projectile
(projectile-register-project-type 'dx #'dx-project-p
                                  :project-file "package.json"
                                  :compile "npm install")

;; Add initialize salesforce for projectile
;; (eval-after-load 'projectile
;;   (add-hook 'projectile-after-switch-hook #'dx-project-init))

(defun dx-project-create ()
  "Create dx project"
  (interactive)
  (let* ((project-path (read-directory-name "project path: "))
         (package-dir (read-string "package dir: ")))

    (make-directory project-path 'parents)

    (dx-make-process-json-async
     :cmd (dx-build-sf-command
           dx-project-command-alias
           "generate"
           "--name" project-path
           "--default-package-dir" package-dir
           "--json")
     (let ((project-output (dx-get-data-json "result.outputDir" json-instance)))

       (alert "Create Project Success"
              :title "DX Alert")))))

(defun dx-source-push (buffer)
  "Push file to salesforce org."
  (interactive (list (buffer-file-name)))

  (if (file-in-directory-p buffer (dx-build-full-path dx-default-apex-class-path))
      (dx-source-backup
       (dx-make-process-json-async
        :cmd (dx-build-sf-command "force" "source" "deploy" "-p" buffer "--json")
        (cond ((and (plist-member json-instance :code)
                  (= (plist-get json-instance :code) 1)
                  (string= (plist-get json-instance :name) "RefreshTokenAuthError"))
               (alert (plist-get json-instance :message)
                      :title "DX Alert"))
              ((= (plist-get json-instance :status) 0)
               (alert (format "Deploy %s success" buffer)
                      :title "DX Alert"))
              (t (funcall #'dx-handle-process-error--json json-instance)))))

    (dx-make-process-json-async
     :cmd (dx-build-sf-command "force" "source" "deploy" "-p" buffer "--json")
     (cond ((and (plist-member json-instance :code)
               (= (plist-get json-instance :code) 1)
               (string= (plist-get json-instance :name) "RefreshTokenAuthError"))
            (alert (plist-get json-instance :message)
                   :title "DX Alert"))
           ((= (plist-get json-instance :status) 0)
            (alert (format "Deploy %s success" buffer)
                   :title "DX Alert"))
           (t (funcall #'dx-handle-process-error--json json-instance))))))

(defun dx-source-backup-sync ()
  "Backup the current buffer to the source directory."
  (let* ((buffer (buffer-file-name))
         (file-name (file-name-base buffer))
         (cache-dir (dx--get-cache-folder-path))
         (backup-file-name (concat file-name "_" (format "%s" (time-convert (current-time) 'integer))))
         (json-instance))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir 'parents))

    (setq json-instance (dx-make-process-json-sync
                         :cmd (append (dx-build-sf-command dx-project-command-alias
                                                           "retrieve"
                                                           "start"
                                                           "-d" buffer
                                                           "-z"
                                                           "-t" cache-dir
                                                           "--zip-file-name" backup-file-name
                                                           "--json"))))
    (unless json-instance
      (error (concat "Backup " file-name " Failure")))
    ;; rename backup directory to new directory containing the last modified id
    ;; and the last modified date

    (when-let ((new-dir-name (concat cache-dir "/" backup-file-name "_"
                                     (dx-get-data-json "result.fileProperties.0.lastModifiedById"
                                                       json-instance)
                                     "_"
                                     (format "%s"
                                             (time-convert
                                              (date-to-time
                                               (dx-get-data-json "result.fileProperties.0.lastModifiedDate"
                                                                 json-instance))
                                              'integer)))))
      (rename-file (concat cache-dir "/" backup-file-name)
                   new-dir-name))))

(defun dx-source-push-chain-test-1 ()
  "Test 1"
  (dx--execute-asynchronous-process (list #'dx-source-backup-sync #'dx-source-retrieve)))

(defun dx-source-push-chain-test (buffer)
  "Push file to Salesforce org."
  (interactive (list (buffer-file-name)))
  (let* ((file-name (file-name-base buffer))
         (cache-dir (dx--get-cache-folder-path))
         (backup-file-name (concat file-name "_" (format "%s" (time-convert (current-time) 'integer)))))

    (dx-make-chain-process
     (list :cmd (dx-build-sf-command dx-project-command-alias
                                     "retrieve"
                                     "start"
                                     "-d" buffer
                                     "-z"
                                     "-t" cache-dir
                                     "--zip-file-name" backup-file-name
                                     "--json")
           :callback (lambda (content params)
                       (let ((json-instance (dx--process-parse-json content)))

                         (unless json-instance
                           (error (concat "Backup " file-name " Failure")))
                         ;; rename backup directory to new directory containing the last modified id
                         ;; and the last modified date

                         (when-let ((new-dir-name (concat cache-dir "/" backup-file-name "_"
                                                          (dx-get-data-json "result.fileProperties.0.lastModifiedById"
                                                                            json-instance)
                                                          "_"
                                                          (format "%s"
                                                                  (time-convert
                                                                   (date-to-time
                                                                    (dx-get-data-json "result.fileProperties.0.lastModifiedDate"
                                                                                      json-instance))
                                                                   'integer)))))
                           (rename-file (concat cache-dir "/" backup-file-name)
                                        new-dir-name)))))
     ;; Push source 
     (list :cmd (dx-build-sf-command "force"
                                     "source"
                                     "deploy"
                                     "-p"
                                     buffer
                                     "--json")
           :callback (lambda (content params)
                       (let ((json-instance (dx--process-parse-json content)))
                         (cond ((and (plist-member json-instance :code)
                                     (= (plist-get json-instance :code) 1)
                                     (string= (plist-get json-instance :name) "RefreshTokenAuthError"))
                                (alert (plist-get json-instance :message)
                                       :title "DX Alert"))
                               ((= (plist-get json-instance :status) 0)
                                (alert (format "Deploy %s success" buffer)
                                       :title "DX Alert"))
                               (t (funcall #'dx-handle-process-error--json json-instance)))))))))

(defun dx-source-retrieve (buffer)
  "Retrieve source salesforce form org"
  (interactive (list (buffer-file-name)))
  (dx-make-process-json-async
   :cmd (dx-build-sf-command "force" "source" "retrieve" "-p" buffer "--json")
   (cond ((and (plist-member json-instance :code)
             (= (plist-get json-instance :code) 1)
             (string= (plist-get json-instance :name) "RefreshTokenAuthError"))
          (alert (plist-get json-instance :message)
                 :title "DX Alert"))
         ((= (plist-get json-instance :status) 0)
          (alert (format "Retrieve %s success" (dx-get-data-json "result.inboundFiles.0.filePath" json-instance))
                 :title "DX Alert"))
         (t (funcall #'dx-handle-process-error--json json-instance)))))

(cl-defmacro dx-source-backup (&rest body &key target-org &allow-other-keys)
  "Backup the current buffer to the source directory."
  `(let* ((buffer (buffer-file-name))
          (file-name (file-name-base buffer))
          (cache-dir (dx--get-cache-folder-path))
          (backup-file-name (concat file-name "_" (format "%s" (time-convert (current-time) 'integer)))))

     (unless (file-exists-p cache-dir)
       (make-directory cache-dir 'parents))

     (dx-make-process-json-async
      :cmd (append (dx-build-sf-command dx-project-command-alias
                                        "retrieve"
                                        "start"
                                        "-d" buffer
                                        "-z"
                                        "-t" cache-dir
                                        "--zip-file-name" backup-file-name
                                        "--json")
                   (when ,target-org (list "-o" ,target-org)))
      (unless json-instance
        (error (concat "Backup " file-name " Failure")))
      ;; rename backup directory to new directory containing the last modified id
      ;; and the last modified date

      (when-let ((new-dir-name (concat cache-dir "/" backup-file-name "_"
                                       (dx-get-data-json "result.fileProperties.0.lastModifiedById"
                                                         json-instance)
                                       "_"
                                       (format "%s"
                                               (time-convert
                                                (date-to-time
                                                 (dx-get-data-json "result.fileProperties.0.lastModifiedDate"
                                                                   json-instance))
                                                'integer)))))
        (rename-file (concat cache-dir "/" backup-file-name)
                     new-dir-name)
        ,@body))))

(defun dx-ediff-startup-hook ()
  "Ediff hook on startup."
  (let* ((coding-system (with-current-buffer ediff-buffer-B
                          buffer-file-coding-system)))

    ;; Set coding for buffer A
    (with-current-buffer ediff-buffer-A
      (set-buffer-file-coding-system coding-system t t))
    (ediff-toggle-read-only ediff-buffer-A)

    (when ediff-buffer-C
      ;; Set coding for buffer C
      (with-current-buffer ediff-buffer-C
        (set-buffer-file-coding-system coding-system t t))

      (ediff-toggle-read-only ediff-buffer-C))

    (ediff-update-diffs)))

(defun dx-ediff-quit-hook ()
  "Hook on quit."
  (with-current-buffer ediff-buffer-A
    (kill-buffer-and-window))
  (when ediff-buffer-C
    (with-current-buffer ediff-buffer-C
      (kill-buffer-and-window)))

  ;; Clear hooks
  (remove-hook 'ediff-startup-hook #'dx-ediff-startup-hook)
  (remove-hook 'ediff-quit-hook #'dx-ediff-quit-hook))

(defun dx-diff-metadata ()
  "diff metadata between local and cloud."
  (interactive)
  (let ((full-file-name (buffer-file-name)))

    (dx-source-backup
     (condition-case error
         (ediff (dx--find-backup-file (file-name-nondirectory full-file-name)
                                      new-dir-name)
                full-file-name
                `((lambda ()
                    (add-hook 'ediff-quit-hook #'dx-ediff-quit-hook)
                    (add-hook 'ediff-startup-hook #'dx-ediff-startup-hook))))
       (error
        (alert (format "%s" error)
               :title "DX Alert"
               :severity 'urgent))))))

(defun dx-diff-metadata-other-org ()
  "diff metadata between local and cloud."
  (interactive)
  (dx-org-alias-list
   (let* ((full-file-name (buffer-file-name))
          (org (completing-read "Target Org: " org-list nil 'require-match))
          (org-status (dx--org-status org)))

     (unless (string= org-status "Connected"))
     ;;(dx-authen))

     (dx-source-backup
      :target-org org
      (condition-case error
          (ediff (dx--find-backup-file (file-name-nondirectory full-file-name)
                                       new-dir-name)
                 full-file-name
                 '((lambda ()
                     (add-hook 'ediff-startup-hook #'dx-ediff-startup-hook)
                     (add-hook 'ediff-quit-hook #'dx-ediff-quit-hook))))
        (error
         (alert (format "%s" error)
                :title "DX Alert"
                :severity 'urgent)))))))

(defun dx-diff3-metadata ()
  "diff metadata between three enviroments."
  (interactive)
  (let* ((minibuffer-history (dx-org-alias-list))
         (file-name (buffer-file-name))
         (target-org (read-from-minibuffer "Target Org: "))
         (bk-file-org (dx-source-backup))
         (bk-file-target-org (dx-source-backup
                              :target-org target-org)))

    (condition-case error
        (ediff3 (car (directory-files-recursively (concat bk-file-org "/") (file-name-nondirectory file-name))) file-name (car (directory-files-recursively (concat bk-file-target-org "/") (file-name-nondirectory file-name)))
                '((lambda ())
                  (add-hook 'ediff-startup-hook #'dx-ediff-startup-hook)
                  (add-hook 'ediff-quit-hook #'dx-ediff-quit-hook)))
      (error
       (alert error
              :title "DX Alert"
              :severity 'urgent)))))

(defun dx-source-tracker ()
  (interactive)
  (let* ((folder-name (file-name-base buffer-file-name))
         (file-name (file-name-nondirectory buffer-file-name))
         (dx-dedicated-window-right "*Org Tracker*")
         (source-list (dx--find-backup-files (format "%s$" file-name)))
         (model
          (dx-table--make-table-mode
           :column-header
           `((:title "Backup DateTime")
             (:title "User Modified Id")
             (:title "Last Modified"))
           :data
           (cl-remove-if 'nil
                         (mapcar (lambda (file)
                                   ;; format files show on buffer
                                   (when-let* ((source-dir (file-name-base (dx--find-parents file 3)))
                                               (data (string-split source-dir "_"))
                                               (date-time (format-time-string "%Y/%m/%d %H:%M:%S" (string-to-number (nth 0 data))))
                                               (user-id (nth 1 data))
                                               (last-modified-date (format-time-string "%Y/%m/%d %H:%M:%S" (string-to-number (nth 2 data)))))

                                     `(,date-time ,user-id ,last-modified-date ,(concat (nth 3 data) "_" (nth 0 data) "_" user-id "_" (nth 2 data)))))
                                 ;; list of file names
                                 source-list))))
         (component
          (dx-table--create-table
           :model model
           :buffer dx-dedicated-window-right)))

    (ctbl:cp-add-click-hook component
                            `(lambda ()
                               (when-let* ((data (ctbl:cp-get-selected-data-row ,component))
                                           (cache-dir (concat (dx--get-cache-folder-path)
                                                              (nth 3 data)))))
                               (ediff (car (directory-files-recursively cache-dir ,file-name))
                                      ,buffer-file-name
                                      '((lambda ()
                                          (add-hook 'ediff-startup-hook #'dx-ediff-startup-hook)
                                          (add-hook 'ediff-quit-hook #'dx-ediff-quit-hook))))))

    (pop-to-buffer (ctbl:cp-get-buffer component))))

(provide 'dx-project)
