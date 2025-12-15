;;; salesforce-project.el --- Salesforce SALESFORCE Project Management -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Commentary:
;; This package provides Salesforce SALESFORCE project management functionality for Emacs.

;;; Code:

(require 'projectile)
(require 'salesforce-core)
(require 'transient)
(require 'taxy)

;;; Variables

(defvar salesforce-project-ediff-help-message
  "\n=====================|===========================|=============================
    C-c C-p -push    |  C-c C-r -retrieve        |  C-c C-s -save changes
"
  "Help message for Salesforce SALESFORCE ediff actions.")

(defvar salesforce-project--mode-line-format 
  `(:eval (salesforce-project--mode-line-format))
  "Mode line Salesforce for project.")

(defvar salesforce-project-token nil
  "Token of current org.")

(defvar salesforce-project-url nil
  "URL of current org.")

;;; Customization

(defgroup salesforce-project nil
  "Salesforce project management."
  :group 'tools)

(defcustom salesforce-files-test-root '(".sf" ".sfdx" ".forceignore")
  "Files/dirs to identify Salesforce projects."
  :type 'list
  :group 'salesforce-project)

(defcustom salesforce-project-configuration 
  '((nil . ((eval . (salesforce-mode 1)))))
  "Project configuration for Salesforce projects."
  :type 'list
  :group 'salesforce-project)

(defcustom salesforce-project-mode-line-icon ""
  "`salesforce-minor-mode' icon."
  :type 'string
  :group 'salesforce-project)

;;; Project Detection and Initialization

;;;###autoload
(defun salesforce-project-p (&optional dir)
  "Determine if DIR is a Salesforce project.
If DIR is not provided, use the current projectile project root."
  (let ((default-directory (or dir (projectile-project-root))))
    (cl-some #'projectile-verify-file-wildcard salesforce-files-test-root)))

;;;###autoload 
(defun salesforce-project-init ()
  "Initialize configuration for a Salesforce project.
Sets up metadata and applies directory locals."
  (when (eq (projectile-project-type) 'salesforce)
    (let ((enable-local-variables :all))
      (salesforce-project--setup-metadata)
      (salesforce-project--apply-dir-locals))))

;;; Configuration Management

(defun salesforce-project--get-config-file-path (root)
  "Return the config file path for the project ROOT.
Checks both .sf/config.json and legacy .sfdx/sfdx-config.json."
  (let ((modern-config (expand-file-name ".sf/config.json" root))
        (legacy-config (expand-file-name ".sfdx/sfdx-config.json" root)))
    (cond
     ((file-exists-p modern-config) modern-config)
     ((file-exists-p legacy-config) legacy-config)
     (t nil))))

(defun salesforce-project--read-org-from-config (config-file)
  "Read the org alias from CONFIG-FILE using native JSON parsing."
  (when (and config-file (file-exists-p config-file))
    (condition-case nil
        (with-temp-buffer
          (insert-file-contents config-file)
          (let* ((json (json-parse-buffer :object-type 'alist))
                 (org-name (or (alist-get 'target-org json)
                               (alist-get 'defaultusername json))))
            (if (stringp org-name) org-name "")))
      (error ""))))

(defun salesforce-project--fetch-org-name ()
  "Return the current Salesforce org alias for the project.
Checks config files or falls back to cached value."
  (let* ((root (salesforce-core--find-root-dir))
         (config-file (salesforce-project--get-config-file-path root)))
    (if config-file
        (or (ignore-errors (salesforce-project--read-org-from-config config-file))
            "")
      "")))

(defun salesforce-project--ensure-org-name ()
  "Ensure salesforce-org-name is populated from config file.
Updates dir-locals if value has changed. Returns the org name or nil."
  (when-let* ((root (salesforce-core--find-root-dir))
              (org-name (salesforce-project--fetch-org-name))
              ((not (string-empty-p org-name))))
    ;; Only update if different from current value
    (unless (equal salesforce-org-name org-name)
      (salesforce-project--update-dir-local-config 'salesforce-org-name org-name)
      (salesforce-project--apply-dir-locals))
    org-name))

(defun salesforce-project--get-root-config (root)
  "Retrieve the project configuration for ROOT directory."
  (or (alist-get root salesforce-metadata-define-roots)
      (alist-get 'default salesforce-metadata-define-roots)))

(defun salesforce-project--set-local-metadata-dir (root config)
  "Set `salesforce-metadata-root-dir' by searching from ROOT for CONFIG."
  (when-let* ((metadata-dir (locate-dominating-file root config))
              (metadata-path (expand-file-name config metadata-dir)))
    (salesforce-project--update-dir-local-config 
     'salesforce-metadata-root-dir
     metadata-path)))

(defun salesforce-project--setup-metadata ()
  "Locate and configure the metadata directory for the current project."
  (when-let* ((root (projectile-project-root))
              (config (salesforce-project--get-root-config root)))
    (salesforce-project--set-local-metadata-dir root config)
    
    ;; Update all metadata directory configurations
    (salesforce-project--update-metadata-paths)))

(defun salesforce-project--update-metadata-paths ()
  "Update all metadata-related directory local configurations."
  (let ((metadata-paths
         `((salesforce-project-root-dir . ,(salesforce-core--find-root-dir))
           (salesforce-org-name . ,(salesforce-project--fetch-org-name))
           (salesforce-trigger-dir . ,(salesforce-core--metadata-path salesforce-trigger-dir))
           (salesforce-apex-dir . ,(salesforce-core--metadata-path salesforce-apex-dir))
           (salesforce-lwc-dir . ,(salesforce-core--metadata-path salesforce-lwc-dir))
           (salesforce-aura-dir . ,(salesforce-core--metadata-path salesforce-aura-dir))
           (salesforce-vf-dir . ,(salesforce-core--metadata-path salesforce-vf-dir))
           (salesforce-object-dir . ,(salesforce-core--metadata-path salesforce-object-dir)))))
    
    (dolist (config metadata-paths)
      (salesforce-project--update-dir-local-config (car config) (cdr config)))))

(defun salesforce-project-get-symbol-dir-local (symbol &optional mode)
  "Return non-nil if SYMBOL exists under MODE in project configuration.
If MODE is nil, check the default project entry."
  (assoc symbol (alist-get mode salesforce-project-configuration)))

(defalias 'salesforce-project-symbol-dir-local-p 
  #'salesforce-project-get-symbol-dir-local)

(defun salesforce-project--update-dir-local-config (symbol value &optional force)
  "Update project configuration for SYMBOL with VALUE.
Configuration is stored in `salesforce-project-configuration'.
If FORCE is non-nil, update even if value hasn't changed."
  (when (or (not (eq (cdr (salesforce-project-symbol-dir-local-p symbol)) value))
            force)
    (if (assoc nil salesforce-project-configuration)
        (setf (alist-get nil salesforce-project-configuration)
              `(,@(assoc-default nil salesforce-project-configuration)
                (,symbol . ,value)))
      (cl-pushnew 'salesforce-project-configuration 
                  `(nil . ((,symbol . ,value)))))))

(defun salesforce-project--apply-dir-locals ()
  "Apply directory local variables for the current project."
  (dir-locals-set-class-variables 'project-configuration 
                                  salesforce-project-configuration)
  (dir-locals-set-directory-class (projectile-project-root) 
                                  'project-configuration)
  (hack-dir-local-variables-non-file-buffer))

;;; Projectile Integration

(with-eval-after-load 'projectile
  (projectile-register-project-type 'salesforce 
                                    #'salesforce-project-p
                                    :project-file salesforce-files-test-root
                                    :compile "npm install")

  (add-hook 'projectile-after-switch-project-hook 
            #'salesforce-project-init))

;;; Project Operations

;;;###autoload
(defun salesforce-project-create ()
  "Create a new Salesforce project in a specified directory."
  (interactive)
  (let* ((project-dir (read-directory-name "Directory: "))
         (project-name (read-string "Project name: "))
         (project-template (completing-read "Project template: " 
                                            '("standard" "empty" "project")))
         (default-directory project-dir))
    (make-directory project-dir 'parents)
    (salesforce-core--project-process 
     :args (list "generate" "--name" project-name 
                 "--template" project-template "--json")
     (salesforce-core--alert "Create Project Success"))))

;;; Source Push/Retrieve Operations

(defun salesforce-project--build-org-args (target-org)
  "Build command line arguments for TARGET-ORG if provided."
  (when (and target-org (not (string-blank-p target-org)))
    (list "-o" target-org)))

(defun salesforce-project-source-push (buffer &optional target-org)
  "Push the specified BUFFER to a Salesforce org.
Optionally specify a TARGET-ORG."
  (interactive (list (buffer-file-name)))
  (salesforce-core--project-process 
   :args `("deploy" "start" "-d" ,buffer 
           ,@(salesforce-project--build-org-args target-org) 
           "--json")
   (salesforce-core--alert (format "Deploy %s success" buffer))))

(defun salesforce-project-source-retrieve (buffer &optional target-org)
  "Retrieve source from a Salesforce org into the specified BUFFER.
Optionally specify a TARGET-ORG."
  (interactive (list (buffer-file-name)))
  (salesforce-core--project-process 
   :args `("retrieve" "start" "-d" ,buffer 
           ,@(salesforce-project--build-org-args target-org) 
           "--json")
   (salesforce-core--alert (format "Retrieve %s success" buffer))))

;;; Cloud Metadata Operations

(cl-defun salesforce-project--clone-cloud-metadata
    (&key metadata-file target-path target-org finish-func)
  "Clone cloud metadata from a Salesforce org.
METADATA-FILE specifies the file to retrieve.
TARGET-PATH is the local path to store the metadata.
TARGET-ORG specifies the Salesforce org.
FINISH-FUNC is a function to call upon completion."
  (let ((file-name (file-name-base metadata-file)))
    (salesforce-core--project-process 
     :args `("retrieve" "start"
             "-d" ,metadata-file
             "-z"
             "-t" ,temporary-file-directory
             "--zip-file-name" ,file-name
             ,@(salesforce-project--build-org-args target-org)
             "--json")
     
     (when target-path
       (unless (file-exists-p target-path)
         (error "Path not exist"))
       (copy-file (concat temporary-file-directory file-name) target-path t))
     
     (funcall finish-func 
              (or target-path
                  (expand-file-name file-name temporary-file-directory))))))

;;; Ediff Integration

(defun salesforce-project--ediff-set-buffer-coding (buffer coding-system)
  "Set the coding system for BUFFER to CODING-SYSTEM."
  (with-current-buffer buffer
    (set-buffer-file-coding-system coding-system t t)))

(defun salesforce-project--ediff-startup-hook ()
  "Hook to run on Ediff startup, setting up additional actions."
  (let ((coding-system (with-current-buffer ediff-buffer-B
                         buffer-file-coding-system)))
    
    ;; Set coding for all buffers
    (salesforce-project--ediff-set-buffer-coding ediff-buffer-A coding-system)
    
    (when ediff-buffer-C
      (salesforce-project--ediff-set-buffer-coding ediff-buffer-C coding-system)
      (ediff-toggle-read-only ediff-buffer-C))
    
    (ediff-update-diffs)
    (salesforce-project--ediff-add-actions)))

(defun salesforce-project--ediff-help-menu ()
  "Add custom hints to the Ediff help menu."
  (concat ediff-long-help-message-head
          ediff-long-help-message-compare2 
          salesforce-project-ediff-help-message
          ediff-long-help-message-tail))

(defun salesforce-project--ediff-add-actions ()
  "Add custom actions to the Ediff control panel."
  (define-key ediff-mode-map (kbd "C-c C-p")
              (lambda () 
                (interactive)
                (salesforce-project--ediff-push-changes salesforce-org-name)))
  
  (define-key ediff-mode-map (kbd "C-c C-r")
              (lambda () 
                (interactive)
                (salesforce-project--ediff-retrieve-changes salesforce-org-name)))
  
  (define-key ediff-mode-map (kbd "C-c C-s")
              (lambda () 
                (interactive)
                (salesforce-project--ediff-save-changes ediff-buffer-A))))

(defun salesforce-project--ediff-push-changes (target-org)
  "Push changes from the Ediff buffer to TARGET-ORG."
  (interactive)
  (let ((file (buffer-file-name ediff-buffer-A)))
    (salesforce-project--ediff-save-changes ediff-buffer-A)
    (when (yes-or-no-p (format "Push changes to %s org?" target-org))
      (salesforce-project-source-push file target-org))))

(defun salesforce-project--ediff-retrieve-changes (target-org)
  "Retrieve changes from TARGET-ORG to the Ediff buffer."
  (interactive)
  (let ((file (buffer-file-name ediff-buffer-A)))
    (when (yes-or-no-p (format "Retrieve changes from %s org?" target-org))
      (salesforce-project-source-retrieve file target-org)
      (salesforce-project--ediff-save-changes ediff-buffer-A))))

(defun salesforce-project--ediff-save-changes (buffer)
  "Save changes from the Ediff BUFFER to a local file."
  (interactive)
  (let ((file (buffer-file-name buffer)))
    (if (called-interactively-p 'any)
        (when (yes-or-no-p (format "Save changes to %s file?" file))
          (with-current-buffer buffer
            (save-buffer)))
      (with-current-buffer buffer
        (save-buffer)))))

(defun salesforce-project--ediff-cleanup-buffer (buffer)
  "Cleanup and kill BUFFER with its window."
  (when buffer
    (with-current-buffer buffer
      (kill-buffer-and-window))))

(defun salesforce-project--ediff-quit-hook ()
  "Hook to run on Ediff quit, cleaning up buffers and hooks."
  (salesforce-project--ediff-cleanup-buffer ediff-buffer-A)
  (salesforce-project--ediff-cleanup-buffer ediff-buffer-C)
  
  ;; Clear hooks and keybindings
  (remove-hook 'ediff-startup-hook #'salesforce-project--ediff-startup-hook)
  (remove-hook 'ediff-quit-hook #'salesforce-project--ediff-quit-hook)
  (remove-hook 'ediff-mode-hook #'salesforce-project--ediff-add-actions))

(defun salesforce-project--setup-ediff3 (file-a file-b file-c)
  "Set up an Ediff session for three files with appropriate hooks.
FILE-A, FILE-B, and FILE-C are the files to compare."
  (ediff-files3 file-a file-b file-c
                `((lambda ()
                    (add-hook 'ediff-startup-hook 
                              #'salesforce-project--ediff-startup-hook)
                    (add-hook 'ediff-quit-hook 
                              (lambda () 
                                (salesforce-project--ediff-quit-hook)
                                (delete-directory (file-name-directory ,file-b) t)
                                (delete-directory (file-name-directory ,file-c) t)))))))

(defun salesforce-project--prepare-ediff-session (local-file cloud-file)
  "Prepare an Ediff session between LOCAL-FILE and CLOUD-FILE with proper hooks."
  (setq ediff-long-help-message-function 
        #'salesforce-project--ediff-help-menu)
  
  (ediff local-file cloud-file
         `((lambda ()
             (add-hook 'ediff-quit-hook 
                       #'salesforce-project--ediff-quit-hook)
             (add-hook 'ediff-startup-hook 
                       #'salesforce-project--ediff-startup-hook)))))

;;; Multi-Org Preview Operations

(defun salesforce-project--wait-for-files (file1-ref file2-ref callback)
  "Poll until FILE1-REF and FILE2-REF are set, then call CALLBACK.
FILE1-REF and FILE2-REF should be symbols holding file paths."
  (let ((poll-timer nil))
    (setq poll-timer 
          (run-with-timer 
           1 1
           (lambda ()
             (when (and (symbol-value file1-ref) 
                        (symbol-value file2-ref))
               (cancel-timer poll-timer)
               (funcall callback 
                        (symbol-value file1-ref) 
                        (symbol-value file2-ref))))))))

(defun salesforce-project-preview-metadata-multi-org ()
  "Diff metadata between the current file and two different orgs using Ediff."
  (interactive)
  (salesforce-org-list 
   (lambda (org-list)
     (let* ((current-file (buffer-file-name))
            (file-name (file-name-nondirectory current-file))
            (org1 (completing-read "First Org: " org-list nil 'require-match))
            (org2 (completing-read "Second Org: " org-list nil 'require-match))
            (temp-dir1 (make-temp-file "salesforce-diff-" t))
            (temp-dir2 (make-temp-file "salesforce-diff-" t))
            (file1 nil)
            (file2 nil))
       
       ;; Set up polling timer
       (salesforce-project--wait-for-files 
        'file1 'file2
        (lambda (f1 f2)
          (salesforce-project--setup-ediff3 current-file f1 f2)))
       
       ;; Clone metadata from both orgs
       (salesforce-project--clone-cloud-metadata
        :metadata-file current-file
        :target-org org1
        :target-path temp-dir1
        :finish-func (lambda (path)
                       (setq file1 (car (directory-files-recursively 
                                         path file-name)))))
       
       (salesforce-project--clone-cloud-metadata
        :metadata-file current-file
        :target-org org2
        :target-path temp-dir2
        :finish-func (lambda (path)
                       (setq file2 (car (directory-files-recursively 
                                         path file-name)))))))))

(defun salesforce-project-preview-metadata-change-other-org ()
  "Diff source between the local project and a specific Salesforce platform."
  (interactive)
  (salesforce-org-list 
   (lambda (org-list)
     (salesforce-project-preview-metadata-change 
      (completing-read "Org: " org-list)))))

(defun salesforce-project-preview-metadata-change (&optional target-org)
  "Diff source between the local project and a Salesforce platform.
Optionally specify a TARGET-ORG."
  (interactive (list salesforce-org-name))
  (let ((full-file-name (buffer-file-name)))
    (salesforce-project--clone-cloud-metadata
     :metadata-file full-file-name
     :target-org target-org
     :finish-func
     (lambda (clone-directory)
       (condition-case error
           (salesforce-project--prepare-ediff-session
            (salesforce--find-file (file-name-nondirectory full-file-name) 
                                   clone-directory)
            full-file-name)
         (error
          (salesforce-core--alert (format "%s" error)
                                  :severity 'urgent)))))))

;;; Multi-Source Operations

(defun salesforce-project--process-multi-sources (files command)
  "Process multiple metadata FILES with the specified COMMAND."
  (async-start 
   `(lambda ()
      (setq default-directory ,(projectile-project-root))
      ,(async-inject-variables "\\`load-path\\'")
      (require 'async nil t)
      (require 'salesforce-project nil t)
      (require 'salesforce-core nil t)
      (require 'cl-macs nil t)
      (setq async-debug t)
      (let ((proc (apply #'salesforce-core--project-process
                         :args ,(apply #'append 
                                       (list command "start" "--json")
                                       (cl-loop for file in files
                                                collect `("-d" ,file)))
                         :sync t)))
        (async-wait proc)
        (if (eq (process-exit-status proc) 1)
            (list :status 1
                  :error (salesforce--async-when-done proc))
          (list :status 0
                :json-instance (salesforce-core-parse-buffer-json
                                (process-buffer proc))))))
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

;;; Selection Deploy Operations

(defun salesforce-project--get-relative-path (file-name)
  "Get the relative path of FILE-NAME within the project."
  (file-name-directory (file-relative-name file-name (projectile-project-root))))

(defun salesforce-project--create-temp-project-folder (temp-dir relative-path)
  "Create a temporary folder structure matching the project layout.
TEMP-DIR is the base directory for the temporary structure.
RELATIVE-PATH is the path within the project to replicate."
  (let* ((temp-dir (salesforce--ensure-directory-exists temp-dir))
         (dest-dir (file-name-directory 
                    (expand-file-name relative-path temp-dir)))
         (salesforce-project-file 
          (expand-file-name "sfdx-project.json" (projectile-project-root))))
    
    ;; Create destination directory structure
    (unless (file-exists-p dest-dir)
      (make-directory dest-dir t))
    
    ;; Copy sfdx-project.json to project temp
    (unless (file-exists-p (expand-file-name "sfdx-project.json" temp-dir))
      (copy-file salesforce-project-file 
                 (expand-file-name "sfdx-project.json" temp-dir) 
                 t))
    
    dest-dir))

(defun salesforce-project--copy-file-to-temp (file dest-path)
  "Copy FILE and its metadata to the temporary directory DEST-PATH."
  (let* ((file-directory (file-name-directory file))
         (meta-file (expand-file-name (concat file "-meta.xml") file-directory))
         (copy-files (list file meta-file)))
    
    ;; Copy the files
    (dolist (source-file copy-files)
      (let ((dest-file (concat dest-path 
                               (file-name-base source-file) 
                               "." 
                               (file-name-extension source-file))))
        (copy-file source-file dest-file t)))
    
    dest-path))

(defun salesforce-project--initialize-file-temp (current-file relative-path)
  "Initialize a temporary project for section deployment.
Copy CURRENT-FILE to a temp folder with the same path structure as project root."
  (when current-file
    (let* ((project-name (projectile-project-name))
           (temp-dir (expand-file-name project-name temporary-file-directory)))
      
      (salesforce-project--create-temp-project-folder temp-dir relative-path)
      (salesforce-project--copy-file-to-temp 
       current-file 
       (expand-file-name relative-path temp-dir)))))

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
   :finish-func 
   (lambda (cloned-path)
     (let* ((backup-file (salesforce--find-file 
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

;;; User Management

(defun salesforce-project--users ()
  "List stale users that connected."
  (let ((alias-file (expand-file-name "~/.sfdx/alias.json")))
    (when (file-exists-p alias-file)
      (let ((json (with-current-buffer (find-file-noselect alias-file)
                    (json-parse-string (buffer-string) 
                                       :object-type 'hash-table))))
        (map-elt json "orgs")))))

(defun salesforce-project--resolve-username (username-or-alias table)
  "Resolve USERNAME-OR-ALIAS to an actual username using TABLE.
TABLE should be a hash table mapping aliases to usernames."
  (let ((alias (hash-table-keys table))
        (user-names (hash-table-values table)))
    (cond 
     ((member username-or-alias user-names) username-or-alias)
     ((member username-or-alias alias) (map-elt table username-or-alias))
     (t nil))))

(defun salesforce-project--get-user-data (username-or-alias key)
  "Get Salesforce user authentication data using USERNAME-OR-ALIAS and KEY."
  (when-let* ((table (salesforce-project--users))
              (user-name (salesforce-project--resolve-username 
                          username-or-alias table))
              (json-file (format "~/.sfdx/%s.json" user-name))
              (_ (file-exists-p (expand-file-name json-file)))
              (data (with-current-buffer 
                        (find-file-noselect (expand-file-name json-file))
                      (json-parse-string (buffer-string) 
                                         :object-type 'hash-table))))
    (map-elt data key)))

(defun salesforce-project--connected-user-p (username-or-alias)
  "Check if USERNAME-OR-ALIAS exists as a connected user."
  (when-let ((table (salesforce-project--users)))
    (or (member username-or-alias (hash-table-keys table))
        (member username-or-alias (hash-table-values table)))))

;;; Mode Line

(defun salesforce-project--mode-line-format ()
  "Compose the mode-line for Salesforce mode."
  (when (bound-and-true-p salesforce-mode)
    ;; Ensure org name is populated (won't update if already correct)
    (when (or (null salesforce-org-name)
              (string-empty-p salesforce-org-name))
      (salesforce-project--ensure-org-name))
    
    (when (and salesforce-org-name 
               (not (string-empty-p salesforce-org-name)))
      (concat (propertize (concat salesforce-project-mode-line-icon 
                                  " " 
                                  salesforce-org-name)
                          'face 'salesforce-mode-line-face)
              salesforce-mode-line-current-org-status))))

;;; Utility Functions

(defun salesforce-project--remove-xml-suffix (original-name)
  "Remove the '-meta.xml' suffix from ORIGINAL-NAME for display."
  (string-replace "-meta.xml" "" original-name))

(defun salesforce-project-open-note ()
  "Open the note associated with the current project."
  (interactive)
  (if-let ((note-file 
            (plist-get 
             (cl-find-if 
              (lambda (el)
                (string= (expand-file-name (plist-get el :project)) 
                         salesforce-project-root-dir))
              salesforce-project-config)
             :note-file)))
      (display-buffer-in-side-window 
       (find-file-noselect (expand-file-name note-file))
       '((side . right)
         (window-width . 0.4)))
    (error "Note file not found")))

;;; Transient Menu Definitions

(transient-define-prefix salesforce-project--transient:custom-metadata-field-menu ()
  "Menu configuration generate custom field Salesforce."
  ["Attributes"
   [""
    (salesforce-data--transient:--name)
    (salesforce-data--transient:--label)
    (salesforce-project--transient:--field-type)]
   [""
    (salesforce-project--transient:--picklist-values)
    (salesforce-project--transient:--decimal-places)
    (salesforce--transient-menu:-d)]]
  [""
   ("RET" "Generate Field" salesforce-data--transient:import-bulk)])

(transient-define-argument salesforce-project--transient:--name ()
  :class 'transient-option
  :description "Unique name for the field"
  :key "-n"
  :shortarg "-n"
  :argument "--name="
  :reader #'salesforce--transient-menu:read-string)

(transient-define-argument salesforce-project--transient:--label ()
  :class 'transient-option
  :description "Label for the field"
  :key "-l"
  :shortarg "-l"
  :argument "--label="
  :reader #'salesforce--transient-menu:read-string)

(transient-define-argument salesforce-project--transient:--field-type ()
  :class 'transient-switches
  :description "Type of the field"
  :key "-f"
  :argument-format "--type=%s"
  :argument-regexp "\\(Checkbox\\|Date\\|DateTime\\|Email\\|Number\\|Percent\\|Phone\\|Picklist\\|Text\\|TextArea\\)"
  :choices '("Checkbox" "Date" "DateTime" "Email" "Number" 
             "Percent" "Phone" "Picklist" "Text" "TextArea")
  :reader #'salesforce--transient-menu:read-string)

(transient-define-argument salesforce-project--transient:--picklist-values ()
  :class 'transient-option
  :description "Picklist values; required for picklist fields"
  :key "-p"
  :shortarg "-p"
  :argument "--picklist-values="
  :if (lambda ()
        (string= (transient-arg-value 
                  "--type=" 
                  (transient-args salesforce-project--transient:custom-metadata-field-menu)) 
                 "Picklist"))
  :reader #'salesforce--transient-menu:read-string)

(transient-define-argument salesforce-project--transient:--decimal-places ()
  :class 'transient-option
  :description "Decimal places for numeric fields"
  :key "-s"
  :shortarg "-s"
  :argument "--decimal-places="
  :reader #'salesforce--transient-menu:read-number)

(defun salesforce-project-create-cmdt-field ()
  "Create custom field on Custom Metadata object."
  (interactive)
  (let ((args (transient-args 'salesforce-project--transient:custom-metadata-field-menu)))
    (salesforce-core--cmdt-process
     :args `("generate" "field" ,@args)
     (salesforce-core--alert "Create field on custom metadata succeeded"))))

(provide 'salesforce-project)

;;; salesforce-project.el ends here
