;;; salesforce-project.el --- Salesforce SALESFORCE Project Management -*- lexical-binding: t; no-byte-compile: t; -*-

;; Copyright (C) 2024 Your Name

;; Author: Your Name <your@email.com>
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (projectile "0.14.0") (transient "0.1.0") (taxy "0.10.2"))
;; Keywords: salesforce, salesforce, project
;; URL: https://github.com/your/repo

;;; Commentary:
;; This package provides Salesforce SALESFORCE project management functionality for Emacs.

;;; Code:

(require 'projectile)
(require 'salesforce-core)
(require 'transient)
(require 'taxy)

(defvar salesforce-project-ediff-help-message
  "\n=====================|===========================|=============================
    C-c C-p -push    |  C-c C-r -retrieve        |  C-c C-s -save changes
"
  "Help message for Salesforce SALESFORCE ediff actions.")

(defvar salesforce-project--mode-line-format `(:eval (salesforce-project--mode-line-format))
  "Mode line Salesforce for project.")

;;; Customization
(defgroup salesforce-project nil
  "Salesforce project management."
  :group 'tools)

(defcustom salesforce-files-test-root '(".sf" ".sfdx" ".forceignore")
  "Files/dirs to identify Salesforce projects."
  :type 'list
  :group 'salesforce-project)

(defcustom salesforce-project-configuration '((nil . ((eval . (salesforce-mode 1)))))
  "Project configuration for Salesforce projects."
  :type 'list
  :group 'salesforce-project)

(defcustom salesforce-project-mode-line-icon ""
  "`salesforce-minor-mode' icon."
  :type 'string
  :group 'salesforce-project)

(defvar salesforce-project-token nil
  "Token of current org.")

(defvar salesforce-project-url nil
  "URL of current org.")

;;;###autoload
(defun salesforce-project-p (&optional dir)
  "Determine if the given DIR is a Salesforce project.
If DIR is not provided, use the current projectile project root."
  (let ((default-directory (or dir (projectile-project-root))))
    (cl-some #'projectile-verify-file-wildcard salesforce-files-test-root)))

;;;###autoload 
(defun salesforce-project-init ()
  "Initialize the configuration for a Salesforce project.
This includes setting up metadata and applying directory locals."
  (when (eq (projectile-project-type) 'salesforce)
    (let ((enable-local-variables :all))
      (salesforce-project--setup-metadata)
      (salesforce-project--apply-dir-locals))))

(defun salesforce-project--setup-metadata ()
  "Locate and configure the metadata directory for the current project."
  (when-let* ((root (projectile-project-root))
              (config (salesforce-project--get-root-config root)))
    (salesforce-project--set-local-metadata-dir root config)
    (salesforce-project--update-dir-local-config 'salesforce-project-root-dir
                                                 (salesforce-core--find-root-dir))
    (salesforce-project--update-dir-local-config 'salesforce-org-name
                                                 (salesforce-project--fetch-org-name))))

(defun salesforce-project--fetch-org-name ()
  "Return the current Salesforce org alias for the project.
Checks `.sf/config.json` or legacy `.sfdx/sfsalesforce-config.json`.
Falls back to cached `salesforce-org-name` or `sfdx` CLI if needed."
  (let* ((root (salesforce-core--find-root-dir))
         (config (concat root ".sf/config.json"))
         (legacy (concat root ".sfdx/sfdx-config.json")))

    (cond
     ;; No config files present → return empty string
     ((not (or (file-exists-p config)
             (file-exists-p legacy)))
      "")

     ;; Otherwise, try reading org from config or fallback to CLI
     (t
      (ignore-errors
        (when-let* ((command-string (concat "[ -f %s ] && grep -Po '(?<=\"target-org\": )\"[^\"]+\"' %s"
                                            "| sed -E 's/\"([^\"]+)\"/\\1/'"
                                            "|| grep -Po '(?<=\"defaultusername\": )\"[^\"]+\"' %s"
                                            "| sed -E 's/\"([^\"]+)\"/\\1/'")))
          (string-trim
           (shell-command-to-string (format command-string config config legacy)))))))))

(defun salesforce-project--get-root-config (root)
  "Retrieve the project configuration for the given ROOT directory."
  (or (alist-get root salesforce-metadata-define-roots)
     (alist-get 'default salesforce-metadata-define-roots)))

(defun salesforce-project--set-local-metadata-dir (root config)
  "Search from ROOT for CONFIG and set `salesforce-metadata-root-dir' to its path."
  (when-let* ((metadata-dir (locate-dominating-file root config))
              (metadata-path (expand-file-name config metadata-dir)))
    (salesforce-project--update-dir-local-config 'salesforce-metadata-root-dir
                                                 metadata-path)))

(defun salesforce-project-get-symbol-dir-local (symbol &optional mode)
  "Return non-nil if SYMBOL exists under MODE in `salesforce-project-configuration'.
If MODE is nil, check the default project entry."
  (assoc symbol (alist-get mode salesforce-project-configuration)))

(defalias 'salesforce-project-symbol-dir-local-p #'salesforce-project-get-symbol-dir-local)

(defun salesforce-project--update-dir-local-config (symbol value &optional force)
  "Update project configuration for SYMBOL with VALUE.
Configuration is stored in `salesforce-project-configuration'."
  (when (or (not (salesforce-project-symbol-dir-local-p symbol))
           force)
    (if (assoc nil salesforce-project-configuration)
        (setf (alist-get nil salesforce-project-configuration)
              `(,@(assoc-default nil salesforce-project-configuration)
                (,symbol . ,value)))
      (cl-pushnew 'salesforce-project-configuration 
                  `(nil . ((,symbol . ,value)))))))

(defun salesforce-project--apply-dir-locals ()
  "Apply directory local variables for the current project."
  (dir-locals-set-class-variables 'project-configuration salesforce-project-configuration)
  (dir-locals-set-directory-class (projectile-project-root) 'project-configuration)
  (hack-dir-local-variables-non-file-buffer))

;; Define own projectile
(with-eval-after-load 'projectile
  (projectile-register-project-type 'salesforce #'salesforce-project-p
                                    :project-file salesforce-files-test-root
                                    :compile "npm install")

  ;; Add initialize salesforce for projectile
  (add-hook 'projectile-after-switch-project-hook #'salesforce-project-init))


(defun salesforce-project-create ()
  "Create a new Salesforce project in a specified directory."
  (interactive)
  (let* ((project-dir (read-directory-name "Directory: "))
         (project-name (read-string "Project name: "))
         (project-template (completing-read "Project template: " (list "standard" "empty" "project")))
         (default-directory project-dir))

    (make-directory project-dir 'parents)

    (salesforce-core--project-process 
     :cmd (list "generate" "--name" project-name "--template" project-template "--json")
     (salesforce-core--alert "Create Project Success"))))

(defun salesforce-project-source-push (buffer &optional target-org)
  "Push the specified BUFFER to a Salesforce org.
Optionally specify a TARGET-ORG."
  (interactive (list (buffer-file-name)))
  (salesforce-core--project-process 
   :cmd `("deploy" "start" "-d" ,buffer ,@(when target-org (list "-o" target-org)) "--json")
   (salesforce-core--alert (format "Deploy %s success" buffer))))

(defun salesforce-project-source-retrieve (buffer &optional target-org)
  "Retrieve source from a Salesforce org into the specified BUFFER.
Optionally specify a TARGET-ORG."
  (interactive (list (buffer-file-name)))
  (salesforce-core--project-process 
   :cmd `("retrieve" "start" "-d" ,buffer ,@(when target-org (list "-o" target-org)) "--json")
   (salesforce-core--alert (format "Retrieve %s success" buffer))))

(cl-defun salesforce-project--clone-cloud-metadata
    (&key metadata-file target-path target-org finish-func)
  "Clone cloud metadata from a Salesforce org.
METADATA-FILE specifies the file to retrieve.
TARGET-PATH is the local path to store the metadata.
TARGET-ORG specifies the Salesforce org.
FINISH-FUNC is a function to call upon completion."
  (let* ((file-name (file-name-base metadata-file)))

    (salesforce-core--project-process 
     :cmd `("retrieve"
            "start"
            "-d" ,metadata-file
            "-z"
            "-t" ,temporary-file-directory
            "--zip-file-name" ,file-name
            ,@(when (and target-org (not (string-blank-p target-org)))
                (list "-o" target-org))
            "--json")
     ;; rename backup directory to new directory containing the last modified id
     ;; and the last modified date
     (when target-path
       (unless (file-exists-p target-path)
         (error "Path not exist"))
       (copy-file (concat temporary-file-directory file-name) target-path) t)
     (funcall finish-func (or target-path
                             (expand-file-name file-name temporary-file-directory))))))

(defun salesforce-project--ediff-startup-hook ()
  "Hook to run on Ediff startup, setting up additional actions."
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
    (salesforce-project--ediff-add-actions)))

(defun salesforce-project--ediff-help-menu ()
  "Add custom hints to the Ediff help menu."
  ;; Add our help message to ediff's help system
  (concat ediff-long-help-message-head
          ediff-long-help-message-compare2 
          salesforce-project-ediff-help-message
          ediff-long-help-message-tail))

(defun salesforce-project--ediff-add-actions ()
  "Add custom actions to the Ediff control panel."
  ;; TODO: add logic handle help menu for compare 3 files
  (define-key ediff-mode-map (kbd "C-c C-p") #'(lambda () (interactive) (salesforce-project--ediff-push-changes salesforce-org-name)))
  (define-key ediff-mode-map (kbd "C-c C-r") #'(lambda () (interactive) (salesforce-project--ediff-retrieve-changes salesforce-org-name)))
  (define-key ediff-mode-map (kbd "C-c C-s") #'(lambda () (interactive) (salesforce-project--ediff-save-changes ediff-buffer-A))))

(defun salesforce-project--ediff-push-changes (target-org)
  "Push changes from the Ediff buffer to the specified TARGET-ORG."
  (interactive)
  (let ((file (buffer-file-name ediff-buffer-A)))
    (salesforce-project--ediff-save-changes)
    (when (yes-or-no-p "Push changes to %s org?" target-org)
      (salesforce-project-source-push file target-org))))

(defun salesforce-project--ediff-retrieve-changes (target-org)
  "Retrieve changes from the specified TARGET-ORG to the Ediff buffer."
  (interactive)
  (let ((file (buffer-file-name ediff-buffer-A)))
    (when (yes-or-no-p "Retrieve changes from %s org?" target-org)
      (salesforce-project-source-retrieve file target-org)
      (salesforce-project--ediff-save-changes ediff-buffer-A))))

(defun salesforce-project--ediff-save-changes (buffer)
  "Save changes from the Ediff buffer to a local file."
  (interactive)
  (let ((file (buffer-file-name buffer)))
    (if (interactive-p)
        (when (yes-or-no-p "Save changes to %s file?" file)
          (save-buffer file))
      (save-buffer file))))

(defun salesforce-project--ediff-quit-hook ()
  "Hook to run on Ediff quit, cleaning up buffers and hooks."
  (with-current-buffer ediff-buffer-A
    (kill-buffer-and-window))
  (when ediff-buffer-C
    (with-current-buffer ediff-buffer-C
      (kill-buffer-and-window)))

  ;; Clear hooks and keybindings
  (remove-hook 'ediff-startup-hook #'salesforce-project--ediff-startup-hook)
  (remove-hook 'ediff-quit-hook #'salesforce-project--ediff-quit-hook)
  (remove-hook 'ediff-mode-hook #'salesforce-project--ediff-add-actions))

(defun salesforce-project-preview-metadata-multi-org ()
  "Diff metadata between the current file and two different orgs using Ediff."
  (interactive)
  (salesforce-org--list (lambda (org-list)
                         (let* ((current-file (buffer-file-name))
                                (file-name (file-name-nondirectory current-file))
                                (org1 (completing-read "First Org: " org-list nil 'require-match))
                                (org2 (completing-read "Second Org: " org-list nil 'require-match))
                                (temp-dir1 (make-temp-file "salesforce-diff-" t))
                                (temp-dir2 (make-temp-file "salesforce-diff-" t))
                                (file1 nil)
                                (file2 nil)
                                (poll-timer nil))

                           ;; Set up polling timer
                           (setq poll-timer (run-with-timer 
                                             1 1 ; start after 1s, repeat every 1s
                                             (lambda ()
                                               (when (and file1 file2)
                                                 (cancel-timer poll-timer)
                                                 (salesforce-project--setup-ediff3 current-file file1 file2)))))

                           ;; Clone metadata from first org
                           (salesforce-project--clone-cloud-metadata
                            :metadata-file current-file
                            :target-org org1
                            :target-path temp-dir1
                            :finish-func (lambda (path)
                                           (setq file1 (car (directory-files-recursively path file-name)))))

                           ;; Clone metadata from second org
                           (salesforce-project--clone-cloud-metadata
                            :metadata-file current-file
                            :target-org org2
                            :target-path temp-dir2
                            :finish-func (lambda (path)
                                           (setq file2 (car (directory-files-recursively path file-name)))))))))

(defun salesforce-project--setup-ediff3 (file-a file-b file-c)
  "Set up an Ediff session for three files with appropriate hooks."
  (ediff-files3 file-a file-b file-c
                `((lambda ()
                    (add-hook 'ediff-startup-hook #'salesforce-project--ediff-startup-hook)
                    (add-hook 'ediff-quit-hook 
                              (lambda () 
                                (salesforce-project--ediff-quit-hook)
                                (delete-directory (file-name-directory file-b) t)
                                (delete-directory (file-name-directory file-c) t)))))))
  ;; (salesforce-project--ediff-add-actions)
  

(defun salesforce-source-tracker ()
  "Track changes in Salesforce source files."
  (interactive)
  (let* ((folder-name (file-name-base buffer-file-name))
         (file-name (file-name-nondirectory buffer-file-name))
         (salesforce-dedicated-window-right "*Org Tracker*")
         (source-list (salesforce--find-backup-files (format "%s$" file-name)))
         (model
          (salesforce-table--make-table-mode
           :column-header
           `((:title "Backup DateTime")
             (:title "User Modified Id")
             (:title "Last Modified"))
           :data
           (cl-remove-if 'nil
                         (mapcar (lambda (file)
                                   ;; format files show on buffer
                                   (when-let* ((source-dir (file-name-base (salesforce--find-parents file 3)))
                                               (data (string-split source-dir "_"))
                                               (date-time (format-time-string "%Y/%m/%d %H:%M:%S" (string-to-number (nth 0 data))))
                                               (user-id (nth 1 data))
                                               (last-modified-date (format-time-string "%Y/%m/%d %H:%M:%S" (string-to-number (nth 2 data)))))

                                     `(,date-time ,user-id ,last-modified-date ,(concat (nth 3 data) "_" (nth 0 data) "_" user-id "_" (nth 2 data)))))
                                 ;; list of file names
                                 source-list))))
         (component
          (salesforce-table--create-table
           :model model
           :buffer salesforce-dedicated-window-right)))

    (ctbl:cp-add-click-hook component
                            `(lambda ()
                               (when-let* ((data (ctbl:cp-get-selected-data-row ,component))
                                           (cache-dir (concat (salesforce--get-cache-folder-path)
                                                              (nth 3 data)))))
                               (ediff (car (directory-files-recursively cache-dir ,file-name))
                                      ,buffer-file-name
                                      '((lambda ()
                                          (add-hook 'ediff-startup-hook #'salesforce-project--ediff-startup-hook)
                                          (add-hook 'ediff-quit-hook #'salesforce-project--ediff-quit-hook))))))

    (pop-to-buffer (ctbl:cp-get-buffer component))))

(defun salesforce-project--process-multi-sources (files command)
  "Process multiple metadata FILES with the specified COMMAND."
  (async-start `(lambda ()
                  (setq default-directory ,(projectile-project-root))
                  ,(async-inject-variables "\\`load-path\\'")
                  (require 'async nil t)
                  (require 'salesforce-project nil t)
                  (require 'salesforce-core nil t)
                  (require 'cl-macs nil t)
                  (setq async-debug t)
                  (let ((proc (apply #'salesforce-core--project-process
                                     :cmd ,(apply #'append (list command "start" "--json")
                                                  (cl-loop for file in files
                                                           collect `("-d" ,file)))
                                     :sync t)))
                    (async-wait proc)
                    (if (eq (process-exit-status proc) 1)
                        `(
                          :status 1
                          :error ,(salesforce--async-when-done proc))
                      `(
                        :status 0
                        :json-instance ,(salesforce-parse-buffer-json (process-buffer proc))))))
               (lambda (result)
                 (when (eq (plist-get result :status) 0)
                   (salesforce-core--alert (concat "Success " command " files"))))))

(defun salesforce-project--push-multi-sources (files)
  "Push multiple metadata FILES to a Salesforce org."
  (interactive (list (transient-args 'salesforce-project--deploy-files-menu)))
  (salesforce-project--process-multi-sources files "deploy"))

(defun salesforce-project--retrieve-multi-sources (files)
  "Retrieve multiple metadata FILES from a Salesforce org."
  (interactive (list (transient-args 'salesforce-project--deploy-files-menu)))
  (salesforce-project--process-multi-sources files "retrieve"))

;;FIXME: use taxy package
(defun salesforce-project--group-files-menu (files)
  "Group FILES for display on the transient menu."
  (cl-loop for file in files
           if (and (string-match-p (regexp-quote salesforce-default-apex-class-path) file)
                 (not (member (salesforce-project--remove-xml-suffix file) classes)))
           collect (salesforce-project--remove-xml-suffix file) into classes
           else if (and (string-match-p (regexp-quote salesforce-default-vf-path) file)
                      (not (member (salesforce-project--remove-xml-suffix file) pages)))
           collect (salesforce-project--remove-xml-suffix file) into pages
           else if (string-match-p (concat salesforce-default-object-path "/[A-Za-z_]+/fields") file)
           collect file into fields
           else if (string-match-p (regexp-quote salesforce-default-object-path) file)
           collect (salesforce-project--remove-xml-suffix file) into objects
           ;; else 
           ;; collect file into other
           finally return (list (cons "classes" classes) 
                        (cons "pages" pages)
                        (cons "objects" objects)
                        (cons "fields" fields))))
                        ;; (cons "Misc" other)
                        

(defun salesforce-project--remove-xml-suffix (original-name)
  "Remove the '-meta.xml' suffix from ORIGINAL-NAME for display."
  (string-replace "-meta.xml" "" original-name))

(defun salesforce-project--generate-files-menu (prefix-name files &rest sections)
  "Configure the deploy files change menu with PREFIX-NAME and FILES.
Additional SECTIONS can be specified."
  `(transient-define-prefix ,(intern (concat "salesforce-project--" prefix-name)) ()
     "Files deploy menu."
     ,@(cl-loop for (name . items) in (salesforce-project--group-files-menu files)
                as section = (vconcat (list (capitalize name))
                                      (cl-loop for chunk in (salesforce-project--generate-files-section items (substring name 0 1))
                                               as col = (vconcat "" chunk)
                                               vconcat col))
                collect section)
     ,@sections))

(defun salesforce-project--generate-files-section (files prefix &optional max-row)
  "Generate a column display for FILES with PREFIX.
Optionally limit the number of rows with MAX-ROW."
  (seq-split (cl-loop for index from 1
                      for file in files
                      as file-name = (file-name-base file)
                      as file-name-ext = (concat file-name (file-name-extension file))
                      when (not (string= file-name ""))
                      collect (list (format "%s%s" prefix index) file-name file :transient t)) 
             (or max-row 5)))

(defun salesforce-project--git-change-source-1 ()
  "Deploy changed sources from local to a Salesforce org."
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

(defun salesforce-project-git-change-source ()
  "View all sources changed in version control."
  (interactive)
  (salesforce-project--git-change-source-1))

(defun salesforce-project-open-note ()
  "Open the note associated with the current project."
  (interactive)
  (if-let ((note-file (plist-get (cl-find-if (lambda (el)
                                               (string= (expand-file-name (plist-get el :project)) salesforce-project-root-dir))
                                             salesforce-project-config)
                                 :note-file)))

      (display-buffer-in-side-window (find-file-noselect
                                      (expand-file-name note-file))
                                     '((side . right)
                                       (window-width . 0.4)))
    (error "note file not found.")))

(defun salesforce-project--prepare-ediff-session (local-file cloud-file)
  "Prepare an Ediff session between LOCAL-FILE and CLOUD-FILE with proper hooks."
  (setq ediff-long-help-message-function #'salesforce-project--ediff-help-menu)

  (ediff local-file cloud-file
         `((lambda ()
             (add-hook 'ediff-quit-hook #'salesforce-project--ediff-quit-hook)
             (add-hook 'ediff-startup-hook #'salesforce-project--ediff-startup-hook)))))

(defun salesforce-project--get-relative-path (file-name)
  "Get the relative path of FILE-NAME within the project."
  (file-name-directory (file-relative-name file-name (projectile-project-root))))

(defun salesforce-project-selection-deploy (file-name)
  "Backup metadata and select section to deploy.
FILE-NAME is the path to the file being deployed.

This function:
1. Clones the metadata from a Salesforce org.
2. Creates a temporary project structure.
3. Sets up an Ediff session to compare local and cloud versions."
  (interactive (list (buffer-file-name)))
  
  (salesforce-project--clone-cloud-metadata
   :metadata-file file-name
   :finish-func (lambda (cloned-path)
                  (let* ((backup-file (salesforce--find-backup-file 
                                       (file-name-nondirectory file-name)
                                       cloned-path))
                         (relative-path (salesforce-project--get-relative-path file-name))
                         (project-temp (salesforce-project--initialize-file-temp 
                                        backup-file 
                                        relative-path))
                         (cloud-file-path (concat project-temp 
                                                  (file-name-base file-name) 
                                                  "." 
                                                  (file-name-extension file-name))))
                    
                    (salesforce-project--prepare-ediff-session cloud-file-path file-name)))))

(defun salesforce-project--create-temp-project-folder (temp-dir relative-path)
  "Create a temporary folder structure matching the project layout.
TEMP-DIR is the base directory for the temporary structure.
RELATIVE-PATH is the path within the project to replicate."
  (let ((dest-dir (file-name-directory (expand-file-name relative-path temp-dir)))
        (temp-dir (salesforce--ensure-directory-exists temp-dir)))
    
    ;; Create destination directory structure
    (unless (file-exists-p dest-dir)
      (make-directory dest-dir t))
    
    ;; Copy sfdx-project.json file to project temp
    (let ((salesforce-project-file (expand-file-name "sfdx-project.json" (projectile-project-root))))
      (unless (file-exists-p (expand-file-name "sfdx-project.json" temp-dir))
        (copy-file salesforce-project-file (expand-file-name "sfdx-project.json" temp-dir) t)))
    
    dest-dir))

(defun salesforce-project--copy-file-to-temp (file dest-path)
  "Copy FILE and its metadata to the temporary directory DEST-PATH."
  (let* ((file-directory (file-name-directory file))
         (copy-files `(,file ,(expand-file-name (concat file "-meta.xml") file-directory)))
         (file-name (concat (file-name-base file) "." (file-name-extension file))))
    
    ;; Copy the files
    (cl-loop for file in copy-files
             do (copy-file file (concat dest-path (file-name-base file) "." (file-name-extension file)) t))
    ;; Return the destination path
    dest-path))

(defun salesforce-project--initialize-file-temp (current-file relative-path)
  "Initialize a temporary project for section deployment.
Copy CURRENT-FILE to a temp folder with the same path structure as the project root."
  (when current-file
    (let* ((project-name (projectile-project-name))
           (temp-dir (expand-file-name project-name temporary-file-directory)))
      
      ;; Create folder
      (salesforce-project--create-temp-project-folder temp-dir relative-path)
      
      ;; Copy files
      (salesforce-project--copy-file-to-temp current-file (expand-file-name relative-path temp-dir)))))

(defun salesforce-project-preview-metadata-change-other-org ()
  "Diff source between the local project and a specific Salesforce platform."
  (interactive)
  (salesforce-org--list (lambda (org-list)
                          (salesforce-project-preview-metadata-change (completing-read "Org: " org-list)))))

(defun salesforce-project-preview-metadata-change (&optional target-org)
  "Diff source between the local project and a Salesforce platform.
Optionally specify a TARGET-ORG."
  (interactive (list salesforce-org-name))
  (let ((full-file-name (buffer-file-name)))
    (salesforce-project--clone-cloud-metadata
     :metadata-file full-file-name
     :target-org target-org
     :finish-func (lambda (new-dir-name)
                    (condition-case error
                        (salesforce-project--prepare-ediff-session (salesforce--find-backup-file (file-name-nondirectory full-file-name)
                                                                                                 new-dir-name)
                                                                   full-file-name)
                      (error
                       (salesforce-core--alert (format "%s" error)
                                               :severity 'urgent)))))))

(defun salesforce-project--mode-line-format ()
  "Compose the mode-line for Salesforce mode."
  (when (and (bound-and-true-p salesforce-mode)
           salesforce-org-name)
    (concat (propertize (concat salesforce-project-mode-line-icon " " salesforce-org-name)
                        'face 'salesforce-mode-line-face)
            salesforce-mode-line-current-org-status)))

(provide 'salesforce-project)
