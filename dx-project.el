;;; dx-project.el --- Salesforce DX Project Management -*- lexical-binding: t; no-byte-compile: t; -*-

;; Copyright (C) 2024 Your Name

;; Author: Your Name <your@email.com>
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (projectile "0.14.0") (transient "0.1.0"))
;; Keywords: salesforce, dx, project
;; URL: https://github.com/your/repo

;;; Commentary:
;; This package provides Salesforce DX project management functionality for Emacs.

;;; Code:

(require 'projectile)
(require 'dx-core)
(require 'transient)

(defvar dx-project-ediff-help-message
  "\n=====================|===========================|=============================
    C-c C-p -push    |  C-c C-r -retrieve        |  C-c C-s -save changes
"
  "Help message for Salesforce DX ediff actions.")

;;; Customization
(defgroup salesforce-project nil
  "Salesforce DX project management."
  :group 'tools)

(defcustom dx-files-test-root '(".forceignore")
  "Files/dirs to identify Salesforce projects."
  :type 'list
  :group 'salesforce-project)

(defcustom dx-project-configuration '((nil . ((eval . (dx-minor-mode 1)))))
  "Project configuration for Salesforce projects."
  :type 'list
  :group 'salesforce-project)

;;;###autoload
(defun dx-project-p (&optional dir)
  "Check if DIR is a Salesforce project."
  (let ((default-directory (or dir (projectile-project-root))))
    (cl-some #'projectile-verify-file-wildcard dx-files-test-root)))

;;;###autoload 
(defun dx-project-init ()
  "Initialize Salesforce project configuration."
  (when (eq (projectile-project-type) 'dx)
    (let ((enable-local-variables :all))
      (dx-project--setup-metadata)
      (dx-project--apply-dir-locals))))

(defun dx-project--setup-metadata ()
  "Find and set metadata directory."
  (when-let* ((root (projectile-project-root))
              (config (dx-project--get-root-config root)))
    (dx-project--update-config-with-metadata root config)))

(defun dx-project--get-root-config (root)
  "Get project configuration for ROOT directory."
  (or (alist-get root dx-metadata-define-roots)
      (alist-get 'default dx-metadata-define-roots)))

(defun dx-project--update-config-with-metadata (root config)
  "Update project CONFIG with metadata path for ROOT."
  (when-let ((metadata-dir (locate-dominating-file root config)))
    (let ((metadata-path (expand-file-name config metadata-dir)))
      (if (assoc nil dx-project-configuration)
          (setf (alist-get nil dx-project-configuration)
                `(,@(assoc-default nil dx-project-configuration)
                  (dx-metadata-root-dir . ,metadata-path)))
        (add-to-list 'dx-project-configuration 
                    `(nil . ((dx-metadata-root-dir . ,metadata-path))))))))

(defun dx-project--apply-dir-locals ()
  "Apply directory local variables for project."
  (dir-locals-set-class-variables 'project-configuration dx-project-configuration)
  (dir-locals-set-directory-class (projectile-project-root) 'project-configuration)
  (hack-dir-local-variables-non-file-buffer))

;; Define own projectile
(with-eval-after-load 'projectile
  (projectile-register-project-type 'dx #'dx-project-p
                                    :project-file "package.json"
                                    :compile "npm install")

  ;; Add initialize salesforce for projectile
  (add-hook 'projectile-after-switch-project-hook #'dx-project-init))


(defun dx-project-create ()
  "Create dx project"
  (interactive)
  (let* ((project-dir (read-directory-name "Directory: "))
         (project-name (read-string "Project name: "))
         (project-template (completing-read "Project template: " (list "standard" "empty" "project")))
         (default-directory project-dir))

    (make-directory project-dir 'parents)

    (dx-core--project-process 
     :cmd (list "generate" "--name" project-name "--template" project-template "--json")
     (alert "Create Project Success"
            :title "DX Alert"))))

(defun dx-project-source-push (buffer &optional target-org)
  "Push file to salesforce org."
  (interactive (list (buffer-file-name)))
  (dx-core--project-process 
   :cmd `("deploy" "start" "-d" ,buffer ,@(when target-org (list "-o" target-org)) "--json")
   (alert (format "Deploy %s success" buffer)
          :title "DX Alert")))

(defun dx-project-source-retrieve (buffer &optional target-org)
  "Retrieve source salesforce form org"
  (interactive (list (buffer-file-name)))
  (dx-core--project-process 
   :cmd `("retrieve" "start" "-d" ,buffer ,@(when target-org (list "-o" target-org)) "--json")
   (alert (format "Retrieve %s success" buffer)
          :title "DX Alert")))

(cl-defun dx-project--clone-cloud-metadata (&key metadata-file target-path target-org finish-func)
  "Backup the current buffer to the source directory."
  (let* ((file-name (file-name-base metadata-file)))

    (dx-core--project-process 
     :cmd `("retrieve"
            "start"
            "-d" ,metadata-file
            "-z"
            "-t" ,temporary-file-directory
            "--zip-file-name" ,file-name
            ,@(when (and target-org (not (string-blank-p target-org))) (list "-o" target-org))
            "--json")
     ;; rename backup directory to new directory containing the last modified id
     ;; and the last modified date
     (when target-path
       (unless (file-exists-p target-path)
         (error "Path not exist"))
       (copy-file (concat temporary-file-directory file-name) target-path) t)
     (funcall finish-func (or target-path (concat temporary-file-directory file-name))))))

(cl-defmacro dx-source-backup (&rest body &key target-org &allow-other-keys)
  "Backup the current buffer to the source directory."
  `(let* ((buffer (buffer-file-name))
          (file-name (file-name-base buffer))
          (cache-dir (dx--get-cache-folder-path))
          (backup-file-name (concat file-name "_" (format "%s" (time-convert (current-time) 'integer)))))

     (unless (file-exists-p cache-dir)
       (make-directory cache-dir 'parents))

     (dx-core--project-process 
      :cmd (list "retrieve"
              "start"
              "-d" buffer
              "-z"
              "-t" cache-dir
              "--zip-file-name" backup-file-name
              "-o" (or ,target-org dx-org-name)
              "--json")
      (unless json-instance
        (error (concat "Backup " file-name " Failure")))
      ;; rename backup directory to new directory containing the last modified id
      ;; and the last modified date

      (when-let ((new-dir-name (concat cache-dir "/" backup-file-name "_"
                                       (dx-core--get-data-json "result.fileProperties.0.lastModifiedById"
                                                               json-instance)
                                       "_"
                                       (format "%s" (time-convert (date-to-time (dx-core--get-data-json "result.fileProperties.0.lastModifiedDate" json-instance))
                                                                  'integer)))))
        (rename-file (concat cache-dir "/" backup-file-name)
                     new-dir-name)
        ,@body))))

(defun dx-project--ediff-startup-hook ()
  "Ediff hook on startup with additional actions."
  (let* ((coding-system (with-current-buffer ediff-buffer-B
                          buffer-file-coding-system)))

    ;; Set coding for buffer A
    (with-current-buffer ediff-buffer-A
      (set-buffer-file-coding-system coding-system t t))
    ;; (ediff-toggle-read-only ediff-buffer-A)

    (when ediff-buffer-C
      ;; Set coding for buffer C
      (with-current-buffer ediff-buffer-C
        (set-buffer-file-coding-system coding-system t t))

      (ediff-toggle-read-only ediff-buffer-C))

    (ediff-update-diffs)
    ;; Add custom ediff actions
    (dx-project--ediff-add-actions)))

(defun dx-project--ediff-help-menu ()
  "Add hints to ediff help menu."
  ;; Add our help message to ediff's help system
  (concat ediff-long-help-message-head
          ediff-long-help-message-compare2 
          dx-project-ediff-help-message
          ediff-long-help-message-tail))

(defun dx-project--ediff-add-actions ()
  "Add custom actions to ediff control panel."
  ;; TODO: add logic handle help menu for compare 3 files
  (define-key ediff-mode-map (kbd "C-c C-p") #'(lambda () (interactive) (dx-project--ediff-push-changes dx-org-name)))
  (define-key ediff-mode-map (kbd "C-c C-r") #'(lambda () (interactive) (dx-project--ediff-retrieve-changes dx-org-name)))
  (define-key ediff-mode-map (kbd "C-c C-s") #'(lambda () (interactive) (dx-project--ediff-save-changes ediff-buffer-A))))

(defun dx-project--ediff-push-changes (target-org)
  "Push changes from ediff buffer to TARGET-ORG."
  (interactive)
  (let ((file (buffer-file-name ediff-buffer-A)))
    (dx-project--ediff-save-changes)
    (when (yes-or-no-p "Push changes to %s org?" target-org)
      (dx-project-source-push file target-org))))

(defun dx-project--ediff-retrieve-changes (target-org)
  "Retrieve changes from TARGET-ORG to ediff buffer."
  (interactive)
  (let ((file (buffer-file-name ediff-buffer-A)))
    (when (yes-or-no-p "Retrieve changes from %s org?" target-org)
      (dx-project-source-retrieve file target-org)
      (dx-project--ediff-save-changes ediff-buffer-A))))

(defun dx-project--ediff-save-changes (buffer)
  "Save changes from ediff buffer to local file."
  (interactive)
  (let ((file (buffer-file-name buffer)))
    (if (interactive-p)
        (when (yes-or-no-p "Save changes to %s file?" file)
          (save-buffer file))
      (save-buffer file))))

(defun dx-project--ediff-quit-hook ()
  "Hook on quit."
  (with-current-buffer ediff-buffer-A
    (kill-buffer-and-window))
  (when ediff-buffer-C
    (with-current-buffer ediff-buffer-C
      (kill-buffer-and-window)))

  ;; Clear hooks and keybindings
  (remove-hook 'ediff-startup-hook #'dx-project--ediff-startup-hook)
  (remove-hook 'ediff-quit-hook #'dx-project--ediff-quit-hook)
  (remove-hook 'ediff-mode-hook #'dx-project--ediff-add-actions))

(defun dx-project-preview-metadata-multi-org ()
  "Diff metadata between current file and two different orgs using ediff."
  (interactive)
  (dx-org--list (lambda (org-list)
                  (let* ((current-file (buffer-file-name))
                         (file-name (file-name-nondirectory current-file))
                         (org1 (completing-read "First Org: " org-list nil 'require-match))
                         (org2 (completing-read "Second Org: " org-list nil 'require-match))
                         (temp-dir1 (make-temp-file "dx-diff-" t))
                         (temp-dir2 (make-temp-file "dx-diff-" t))
                         (file1 nil)
                         (file2 nil)
                         (poll-timer nil))

                    ;; Set up polling timer
                    (setq poll-timer (run-with-timer 
                                      1 1 ; start after 1s, repeat every 1s
                                      (lambda ()
                                        (when (and file1 file2)
                                          (cancel-timer poll-timer)
                                          (dx-project--setup-ediff3 current-file file1 file2)))))

                    ;; Clone metadata from first org
                    (dx-project--clone-cloud-metadata
                     :metadata-file current-file
                     :target-org org1
                     :target-path temp-dir1
                     :finish-func (lambda (path)
                                    (setq file1 (car (directory-files-recursively path file-name)))))

                    ;; Clone metadata from second org
                    (dx-project--clone-cloud-metadata
                     :metadata-file current-file
                     :target-org org2
                     :target-path temp-dir2
                     :finish-func (lambda (path)
                                    (setq file2 (car (directory-files-recursively path file-name)))))))))

(defun dx-project--setup-ediff3 (file-a file-b file-c)
  "Setup ediff session for three files with proper hooks."
  (ediff-files3 file-a file-b file-c
                `((lambda ()
                    (add-hook 'ediff-startup-hook #'dx-project--ediff-startup-hook)
                    (add-hook 'ediff-quit-hook 
                              (lambda () 
                                (dx-project--ediff-quit-hook)
                                (delete-directory (file-name-directory file-b) t)
                                (delete-directory (file-name-directory file-c) t))))))
  ;; (dx-project--ediff-add-actions)
  )

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
                                          (add-hook 'ediff-startup-hook #'dx-project--ediff-startup-hook)
                                          (add-hook 'ediff-quit-hook #'dx-project--ediff-quit-hook))))))

    (pop-to-buffer (ctbl:cp-get-buffer component))))

(defun dx-project--push-multi-sources (files)
  "Push multi metadata files to org."
  (interactive (list (transient-args 'dx-project--deploy-files-menu)))
  (async-start `(lambda ()
                  ;; set default directory run command
                  (setq default-directory ,(projectile-project-root))
                  ;; loading library
                  ,(async-inject-variables "\\`load-path\\'")
                  (require 'async nil t)
                  (require 'dx-project nil t)
                  (require 'cl-macs nil t)
                  (setq async-debug t)
                  (let ((proc (apply #'dx-start-process nil 
                                     (append '(,dx-project-command-alias "deploy" "start" "--json") 
                                             (cons "-d" ',files)))))
                    (async-wait proc)
                    (if (eq (process-exit-status proc) 1)
                        (list :status 1 :error (dx--async-when-done proc))
                      (list :status 0 :json-instance (dx-parse-buffer-json (process-buffer proc))))))
               (lambda (result)
                 (when (eq (plist-get result :status) 0)
                   (alert (concat "Success deploy files:\n"
                                  (string-join files "\n"))
                          :title "DX Alert")))))

(defun dx-project--retrieve-multi-sources (files)
  "Push multi metadata files to org."
  (interactive (list (transient-args 'dx-project--deploy-files-menu)))
  (async-start `(lambda ()
                  ;; set default directory run command
                  (setq default-directory ,(projectile-project-root))
                  ;; loading library
                  ,(async-inject-variables "\\`load-path\\'")
                  (require 'async nil t)
                  (require 'dx-project nil t)
                  (require 'cl-macs nil t)
                  (let ((proc (apply #'dx-start-process nil 
                                     (append '(,dx-project-command-alias "retrieve" "start" "--json") 
                                             (cons "-d" ',files)))))
                    (async-wait proc)
                    (if (eq (process-exit-status proc) 1)
                        (list :status 1 :error (dx--async-when-done proc))
                      (list :status 0 :json-instance (dx-parse-buffer-json (process-buffer proc))))))
               (lambda (result)
                 (when (eq (plist-get result :status) 0)
                   (alert (concat "Success retrieve files:\n"
                                  (string-join files "\n"))
                          :title "DX Alert")))))

(defun dx-project--group-files-menu (files)
  "Group files on transient menu."
  (cl-loop for file in files
           if (and (string-match-p (regexp-quote dx-default-apex-class-path) file)
                 (not (member (dx-project--remove-xml-suffix file) classes)))
           collect (dx-project--remove-xml-suffix file) into classes
           else if (and (string-match-p (regexp-quote dx-default-vf-path) file)
                      (not (member (dx-project--remove-xml-suffix file) pages)))
           collect (dx-project--remove-xml-suffix file) into pages
           else if (string-match-p (concat dx-default-object-path "/[A-Za-z_]+/fields") file)
           collect file into fields
           else if (string-match-p (regexp-quote dx-default-object-path) file)
           collect (dx-project--remove-xml-suffix file) into objects
           ;; else 
           ;; collect file into other
           finally return (list (cons "classes" classes) 
                        (cons "pages" pages)
                        (cons "objects" objects)
                        (cons "fields" fields)
                        ;; (cons "Misc" other)
                        )))

(defun dx-project--remove-xml-suffix (original-name)
  "Format name of item display on transient menu."
  (string-replace "-meta.xml" "" original-name))

(defun dx-project--generate-files-menu (prefix-name files &rest sections)
  "Configuration deploy files change menu."
  `(transient-define-prefix ,(intern (concat "dx-project--" prefix-name)) ()
     "Files deploy menu."
     ,@(cl-loop for (name . items) in (dx-project--group-files-menu files)
                as section = (vconcat (list (capitalize name))
                                      (cl-loop for chunk in (dx-project--generate-files-section items (substring name 0 1))
                                               as col = (vconcat "" chunk)
                                               vconcat col))
                collect section)
     ,@sections))

(defun dx-project--generate-files-section (files prefix &optional max-row)
  "Generate column dilay files."
  (seq-split (cl-loop for index from 1
                      for file in files
                      as file-name = (file-name-base file)
                      as file-name-ext = (concat file-name (file-name-extension file))
                      when (not (string= file-name ""))
                      collect (list (format "%s%s" prefix index) file-name file :transient t)) 
             (or max-row 5)))

(defun dx-project--git-change-source-1 ()
  "Deploy changed sources on local to org."
  (require 'magit nil t)
  (let ((start-point-branch (magit-read-local-branch "Start point" (magit-local-branch-at-point)))
        (end-point-branch (magit-read-local-branch "End point" (magit-local-branch-at-point))))
    (async-start 
     `(lambda ()
        ;;,(async-inject-variables "\\`load-path\'")
        (setq default-directory ,(projectile-project-root))
        (shell-command-to-string (format "git diff $(git reflog --date=local %s | tail -n 1 | cut -d' ' -f 1) %s --stat" ,start-point-branch ,end-point-branch)))
     (lambda (output)
       (let ((buffer (get-buffer-create "*git diff*")))
         ;;FIXME: show files changed on buffer
         ;;feature: show change line and can view changed section also as deploy file or change section
         (with-current-buffer buffer
           (let ((inhibit-read-only t))
             (replace-region-contents (point-min) (point-max)
                                      (lambda ()
                                        output))
             (read-only-mode 1)))
         (pop-to-buffer buffer))))))

(defun dx-project-git-change-source ()
  "View all sources changed on version control."
  (interactive)
  (dx-project--git-change-source-1))

(defun dx-project-open-note ()
  "Open note for current project."
  (interactive)
  (if-let ((note-file (plist-get (cl-find-if (lambda (el)
                                               (string= (expand-file-name (plist-get el :project)) dx-project-root-dir))
                                             dx-project-config)
                                 :note-file)))

      (display-buffer-in-side-window (find-file-noselect
                                      (expand-file-name note-file))
                                     '((side . right)
                                       (window-width . 0.4)))
    (error "note file not found.")))

(defun dx-project--prepare-ediff-session (local-file cloud-file)
  "Prepare ediff session with proper hooks and settings."
  (setq ediff-long-help-message-function #'dx-project--ediff-help-menu)

  (ediff local-file cloud-file
         `((lambda ()
             (add-hook 'ediff-quit-hook #'dx-project--ediff-quit-hook)
             (add-hook 'ediff-startup-hook #'dx-project--ediff-startup-hook)))))

(defun dx-project--get-relative-path (file-name)
  "Get relative path of file within project."
  (file-name-directory (file-relative-name file-name (projectile-project-root))))

(defun dx-project-selection-deploy (file-name)
  "Backup metadata and select section to deploy.
FILE-NAME is the path to the file being deployed.

This function:
1. Clones the metadata from Salesforce org
2. Creates a temporary project structure
3. Sets up an ediff session to compare local and cloud versions"
  (interactive (list (buffer-file-name)))
  
  (dx-project--clone-cloud-metadata
   :metadata-file file-name
   :finish-func (lambda (cloned-path)
                  (let* ((backup-file (dx--find-backup-file 
                                       (file-name-nondirectory file-name)
                                       cloned-path))
                         (relative-path (dx-project--get-relative-path file-name))
                         (project-temp (dx-project--initialize-file-temp 
                                        backup-file 
                                        relative-path))
                         (cloud-file-path (concat project-temp 
                                                  (file-name-base file-name) 
                                                  "." 
                                                  (file-name-extension file-name))))
                    
                    (dx-project--prepare-ediff-session cloud-file-path file-name)))))

(defun dx-project--create-temp-project-folder (temp-dir relative-path)
  "Create temporary folder structure matching project layout."
  (let ((dest-dir (file-name-directory (expand-file-name relative-path temp-dir)))
        (temp-dir (dx--ensure-directory-exists temp-dir)))
    
    ;; Create destination directory structure
    (unless (file-exists-p dest-dir)
      (make-directory dest-dir t))
    
    ;; Copy sfdx-project.json file to project temp
    (let ((dx-project-file (expand-file-name "sfdx-project.json" (projectile-project-root))))
      (unless (file-exists-p (expand-file-name "sfdx-project.json" temp-dir))
        (copy-file dx-project-file (expand-file-name "sfdx-project.json" temp-dir) t)))
    
    dest-dir))

(defun dx-project--copy-file-to-temp (file dest-path)
  "Copy file and metadata to temporary directory."
  (let* ((file-directory (file-name-directory file))
         (copy-files `(,file ,(expand-file-name (concat file "-meta.xml") file-directory)))
         (file-name (concat (file-name-base file) "." (file-name-extension file))))
    
    ;; Copy the files
    (cl-loop for file in copy-files
             do (copy-file file (concat dest-path (file-name-base file) "." (file-name-extension file)) t))
    ;; Return the destination path
    dest-path))

(defun dx-project--initialize-file-temp (current-file relative-path)
  "Initialize temporary project for section deploy.
Copies current file to temp folder with same path structure as project root."
  (when current-file
    (let* ((project-name (projectile-project-name))
           (temp-dir (expand-file-name project-name temporary-file-directory)))
      
      ;; Create folder structure
      (dx-project--create-temp-project-folder temp-dir relative-path)
      
      ;; Copy files
      (dx-project--copy-file-to-temp current-file (expand-file-name relative-path temp-dir)))))

(defun dx-project-preview-metadata-change-other-org ()
  "diff source between local project and specific salesforce platform."
  (interactive)
  (dx-org--list (lambda (org-list)
                  (dx-project-preview-metadata-change (completing-read "Org: " org-list)))))

(defun dx-project-preview-metadata-change (&optional target-org)
  "diff source between local project and salesforce platform."
  (interactive)
  (let ((full-file-name (buffer-file-name)))
    (dx-project--clone-cloud-metadata
     :metadata-file full-file-name
     :target-org (or target-org dx-org-name)
     :finish-func (lambda (new-dir-name)
                    (condition-case error
                        (dx-project--prepare-ediff-session (dx--find-backup-file (file-name-nondirectory full-file-name)
                                                                                 new-dir-name)
                                                           full-file-name)
                      (error
                       (alert (format "%s" error)
                              :title "DX Alert"
                              :severity 'urgent)))))))

;;IDEA

(provide 'dx-project)
