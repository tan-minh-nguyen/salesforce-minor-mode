;;; salesforce-project.el --- Salesforce SALESFORCE Project Management -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Commentary:
;; This package provides Salesforce SALESFORCE project management functionality for Emacs.

;;; Code:

(require 'salesforce-core)
(require 'transient)
(require 'eieio-base)
(require 'project)

(defun salesforce-project-root ()
  "Return the root directory of the current project.
Use projectile if available, otherwise fall back to project.el."
  (if (and (featurep 'projectile) (fboundp 'projectile-project-root))
      (projectile-project-root)
    (when-let ((proj (project-current)))
      (project-root proj))))

;;; Variables

(defvar salesforce-project-ediff-help-message
  "\n=====================|===========================|=============================
    C-c C-p -push    |  C-c C-r -retrieve        |  C-c C-s -save changes
"
  "Help message for Salesforce SALESFORCE ediff actions.")

(defvar salesforce-project--mode-line-format 
  `(:eval (salesforce-project--mode-line-format))
  "Mode line Salesforce for project.")

;;; Customization

(defgroup salesforce-project nil
  "Salesforce project management."
  :group 'tools)

(defcustom salesforce-project-mode-line-icon ""
  "`salesforce-minor-mode' icon."
  :type 'string
  :group 'salesforce-project)

(defun salesforce-project-persistent-file ()
  "Return path to project settings file."
  (expand-file-name ".project-settings.el" (salesforce-project-root)))

;;; Project Detection and Initialization

(defvar salesforce-project-session nil
  "Save session of salesforce project.")

(defclass salesforce-project (eieio-persistent)
  ((metadata-directory
    :initarg :metadata-directory
    :initform nil
    :accessor salesforce-project-source
    :type (or null string)
    :documentation "Path to sources metadata.")
   (org
    :initarg :org
    :initform nil
    :accessor salesforce-project-org
    :type (or null string)
    :documentation "Org connection of current project.")
   (url
    :initarg :url
    :initform nil
    :accessor salesforce-project-url
    :type (or null string)
    :documentation "Instance URL of the connected org.")
   (token
    :initarg :token
    :initform nil
    :accessor salesforce-project-token
    :type (or null string)
    :documentation "Access token (not persisted to dir-locals)."))
  :documentation "Configurations of Salesforce project.")

(cl-defmethod initialize-instance :after ((obj salesforce-project) &rest _)
  "Set default metadata-directory if not provided."
  (unless (oref obj metadata-directory)
    (oset obj metadata-directory
          (expand-file-name "force-app/main/default"
                            (salesforce-project-root)))))

(defcustom salesforce-project-metadata-types
  '((class           :directory "classes/"              :api "ApexClass")
    (trigger         :directory "triggers/"             :api "ApexTrigger")
    (lwc             :directory "lwc/"                  :api "LightningComponentBundle")
    (aura            :directory "aura/"                 :api "AuraDefinitionBundle")
    (page            :directory "pages/"                :api "ApexPage")
    (component       :directory "components/"           :api "ApexComponent")
    (flow            :directory "flows/"                :api "Flow")
    (profile         :directory "profiles/"             :api "Profile")
    (permission-set  :directory "permissionsets/"       :api "PermissionSet")
    (layout          :directory "layouts/"              :api "Layout")
    (label           :directory "labels/"               :api "CustomLabels")
    (static-resource :directory "staticresources/"      :api "StaticResource")
    (report          :directory "reports/"              :api "Report")
    (dashboard       :directory "dashboards/"           :api "Dashboard")
    (document        :directory "documents/"            :api "Document")
    (email-template  :directory "email/"                :api "EmailTemplate")
    (sobject         :directory "objects/"              :api "CustomObject")
    (flexipage       :directory "flexipages/"           :api "FlexiPage")
    (quick-action    :directory "quickActions/"         :api "QuickAction")
    (tab             :directory "tabs/"                 :api "CustomTab")
    (app             :directory "applications/"         :api "CustomApplication")
    (manifest        :directory "manifest/"             :api nil)
    ;; Tool directories (relative to project root)
    (tool            :directory ".sfdx/tools/"          :base root)
    (log             :directory ".sfdx/tools/logs/"     :base root)
    (cache           :directory ".sfdx/tools/cache/"    :base root))
  "Unified metadata type registry.
Each entry: (SYMBOL :directory DIRECTORY :api API-NAME :base BASE)
- SYMBOL: internal identifier
- :directory: subdirectory path
- :api: Salesforce API metadata type name (optional)
- :base: `root' for project root, nil for metadata source directory"
  :type '(alist :key-type symbol
                :value-type (plist :key-type keyword
                                   :value-type (choice string symbol (const nil))))
  :group 'salesforce-project)

(cl-defmethod salesforce-project-source-path ((project salesforce-project) &key path)
  "Return expanded PATH under source directory in PROJECT."
  (declare (indent 1))
  (expand-file-name path (salesforce-project-source project)))

(defun salesforce-project-metadata-get (type property)
  "Get PROPERTY for metadata TYPE from registry."
  (plist-get (alist-get type salesforce-project-metadata-types) property))

(defun salesforce-project-metadata-find-by (property value)
  "Find metadata entry where PROPERTY equals VALUE."
  (cl-find-if (lambda (entry)
                (equal value (plist-get (cdr entry) property)))
              salesforce-project-metadata-types))

(defun salesforce-project-metadata-api-type (type)
  "Get SF API type name for internal TYPE symbol."
  (salesforce-project-metadata-get type :api))

(defun salesforce-project-metadata-type-from-file (file)
  "Determine Salesforce API metadata type from FILE path by directory."
  (let ((dir (file-name-nondirectory
              (directory-file-name (file-name-directory file)))))
    (when-let ((entry (salesforce-project-metadata-find-by
                       :directory (concat dir "/"))))
      (plist-get (cdr entry) :api))))

(cl-defmethod salesforce-project-metadata-path ((project salesforce-project) type)
  "Return directory for TYPE in PROJECT.
If TYPE has `:base root', path is relative to project root.
Otherwise, path is relative to metadata source directory."
  (let ((directory (salesforce-project-metadata-get type :directory))
        (base (salesforce-project-metadata-get type :base)))
    (if (eq base 'root)
        (expand-file-name directory (salesforce-project-root))
      (salesforce-project-source-path project :path directory))))

(cl-defmethod salesforce-project-log-dir ((project salesforce-project))
  "Return log directory of PROJECT."
  (salesforce-project-metadata-path project 'log))

(cl-defmethod salesforce-project-cache-dir ((project salesforce-project))
  "Return cache directory of PROJECT."
  (salesforce-project-metadata-path project 'cache))

;;;###autoload
(cl-defun salesforce-project-p (&key directory)
  "Determine if DIRECTORY is a Salesforce project.
  If DIR is not provided, use the current projectile project root."
  (when-let ((default-directory (or directory (salesforce-project-root))))
    (cl-some #'projectile-verify-file-wildcard salesforce-files-test-root)))

;;;###autoload 
(defun salesforce-project-init ()
  "Initialize configuration for a Salesforce project.
  Sets up metadata and applies directory locals."
  (when (and (salesforce-project-p)
           (not salesforce-project-session))
    (let ((enable-local-variables :all))
      (salesforce-project--setup)
      ;;TODO: replace by projectile-add-dir-local-variabl
      (salesforce-project--session-persistent))))

;;; Configuration Management

(defun salesforce-project--get-config-file ()
  "Return the config file path for the project ROOT.
  Checks both .sf/config.json and legacy .sfdx/sfdx-config.json."
  (let ((modern-config (expand-file-name ".sf/config.json" (salesforce-project-root)))
        (legacy-config (expand-file-name ".sfdx/sfdx-config.json" (salesforce-project-root))))
    (cond
     ((file-exists-p modern-config) modern-config)
     ((file-exists-p legacy-config) legacy-config)
     (t nil))))

(defun salesforce-project--config-org (config-file)
  "Read the org alias from CONFIG-FILE using native JSON parsing."
  (when (and config-file (file-exists-p config-file))
    (condition-case nil
        (with-temp-buffer
          (insert-file-contents config-file)
          (let* ((json (json-parse-buffer :object-type 'alist)))
            (or (alist-get 'target-org json)
                (alist-get 'defaultusername json))))
      (error nil))))

(defun salesforce-project--org-name ()
  "Return the current Salesforce org alias for the project.
  Checks config files or falls back to cached value."
  (let ((config-file (salesforce-project--get-config-file)))
    (and config-file (salesforce-project--config-org config-file))))

(defun salesforce-project--setup ()
  "Locate and configure the metadata directory for the current project."
  (when-let* ((project-setup
               (if (file-exists-p (salesforce-project-persistent-file))
                   (eieio-persistent-read (salesforce-project-persistent-file) 'salesforce-project)
                 (make-instance 'salesforce-project
                                :file (salesforce-project-persistent-file)
                                :org (salesforce-project--org-name)))))
    ;;TODO: add auto update org when default org was configured
    (projectile-add-dir-local-variable nil 'salesforce-project-session project-setup)
    (projectile-add-dir-local-variable nil 'eval '(salesforce-mode 1))))

(defun salesforce-project--session-persistent ()
  "Save project session to persistent file."
  (eieio-persistent-save salesforce-project-session))

(defun salesforce-project--save-session ()
  "Update in-memory configuration with session (without token)."
  (when salesforce-project-session
    (let ((copy (clone salesforce-project-session)))
      (setf (salesforce-project-token copy) nil)
      (salesforce-project--set-local
       'salesforce-project-session copy))))

(cl-defun salesforce-project-get-sfdx-config (&key path)
  "Read sfdx-config.json file from PATH."
  (let ((sfdx-file (expand-file-name (or path "/sfdx-config.json")
                                     (salesforce-project-root))))
    (with-temp-buffer
      (insert-file-contents (find-file-noselect sfdx-file))
      (json-parse-string (buffer-string)))))

(defun salesforce-project-read-sfdx-config ()
  "Sync config in sfdx-config.json to `salesforce-project-session'."
  (let* ((json-object-type 'hash-table)
         (sfdx-config (salesforce-project-get-sfdx-config))
         (project-session (or salesforce-project-session
                             (salesforce-project--setup))))

    ;; (setf (salesforce-project-source project-session)
    ;;       (map-nested-elt sfdx-config '("packageDirectories" "0" "path")))

    (setq salesforce-project-session project-session
          salesforce-api-version (map-nested-elt sfdx-config '("sourceApiVersion")))))


(defun salesforce-project-cleanup ()
  "Cleanup project before switch."
  (when (salesforce-project-p)
    (salesforce-project--save-session)
    (setq salesforce-project-session nil)))

;;; Project Operations

;;;###autoload
(defun salesforce-project-create ()
  "Create a new Salesforce project in a specified directory."
  (interactive)
  (let* ((project-directory (read-directory-name "Directory: "))
         (project-name (read-string "Project name: "))
         (project-template (completing-read "Project template: " 
                                            '("standard" "empty" "project"))))
    (unless (file-exists-p project-dir)
      (make-directory project-dir 'parents))
    (salesforce-core--project-process
     :args `("generate"
             "--name" ,project-name
             "--template" ,project-template
             ,@(when project-directory
                 (list "--output-dir" project-directory))
             "--manifest"
             "--json")
     :callback
     (lambda (_)
       (salesforce-core--alert "Create Project Success")))))

;;; Source Push/Retrieve Operations

(defun salesforce-project--org-args (target-org)
  "Build command line arguments for TARGET-ORG if provided."
  (when (and target-org (not (string-blank-p target-org)))
    (list "-o" target-org)))

(cl-defun salesforce-project-push (file &key (org (salesforce-project-org salesforce-project-session)))
  "Push the specified FILE to a Salesforce org.
  Optionally specify a ORG."
  (interactive (list (buffer-file-name)))
  (declare (indent 1))
  (salesforce-core--project-process
   :args `("deploy" "start" "-d" ,file
           "-o" ,org
           "--json")
   :callback
   (lambda (_)
     (salesforce-core--alert (format "Deploy %s success" file)))))

(cl-defun salesforce-project-retrieve (file &key (org (salesforce-project-org salesforce-project-session)))
  "Retrieve source from a Salesforce org into the specified FILE.
  Optionally specify a ORG."
  (interactive (list (buffer-file-name)))
  (declare (indent 1))
  (salesforce-core--project-process
   :args `("retrieve" "start" "-d" ,file
           "-o" ,org
           "--json")
   :callback
   (lambda (_)
     (salesforce-core--alert (format "Retrieve %s success" file)))))

;;; Cloud Metadata Operations

(cl-defun salesforce-project--pull-metadata
    (file &key (save-directory temporary-file-directory) (org (salesforce-project-org salesforce-project-session)) then)
  "Clone cloud metadata from a Salesforce org.
  METADATA-FILE specifies the file to retrieve.
  TARGET-PATH is the local path to store the metadata.
  TARGET-ORG specifies the Salesforce org.
  FINISH-FUNC is a function to call upon completion."
  (declare (indent 1))
  (let* ((file-name (file-name-base file))
         (metadata-api (salesforce-project-metadata-type-from-file file)))
    (salesforce-core--project-process
     :args `("retrieve" "start"
             "--metadata" ,(concat metadata-api ":" file-name)
             "-t" ,save-directory
             "--zip-file-name" ,file-name
             "-o" ,org
             "-z"
             "--json")
     :callback then)))

;;; Ediff Integration

(defun salesforce-project--ediff-coding (buffer coding-system)
  "Set the coding system for BUFFER to CODING-SYSTEM."
  (with-current-buffer buffer
    (set-buffer-file-coding-system coding-system t t)))

(defun salesforce-project--ediff-start ()
  "Hook to run on Ediff startup, setting up additional actions."
  (let ((coding-system (with-current-buffer ediff-buffer-B
                         buffer-file-coding-system)))
    
    ;; Set coding for all buffers
    (salesforce-project--ediff-coding ediff-buffer-A coding-system)
    
    (when ediff-buffer-C
      (salesforce-project--ediff-coding ediff-buffer-C coding-system)
      (ediff-toggle-read-only ediff-buffer-C))
    
    (ediff-update-diffs)
    (salesforce-project--ediff-keys)))

(defun salesforce-project--ediff-help ()
  "Add custom hints to the Ediff help menu."
  (concat ediff-long-help-message-head
          ediff-long-help-message-compare2 
          salesforce-project-ediff-help-message
          ediff-long-help-message-tail))

(defun salesforce-project--ediff-keys ()
  "Add custom actions to the Ediff control panel."
  (define-key ediff-mode-map (kbd "C-c C-p")
              (lambda ()
                (interactive)
                (salesforce-project--ediff-push
                 (salesforce-project-org salesforce-project-session))))

  (define-key ediff-mode-map (kbd "C-c C-r")
              (lambda ()
                (interactive)
                (salesforce-project--ediff-pull
                 (salesforce-project-org salesforce-project-session))))

  (define-key ediff-mode-map (kbd "C-c C-s")
              (lambda ()
                (interactive)
                (salesforce-project--ediff-save ediff-buffer-A))))

(defun salesforce-project--ediff-push (target-org)
  "Push changes from the Ediff buffer to TARGET-ORG."
  (interactive)
  (let ((file (buffer-file-name ediff-buffer-A)))
    (salesforce-project--ediff-save ediff-buffer-A)
    (when (yes-or-no-p (format "Push changes to %s org?" target-org))
      (salesforce-project-push file target-org))))

(defun salesforce-project--ediff-pull (target-org)
  "Retrieve changes from TARGET-ORG to the Ediff buffer."
  (interactive)
  (let ((file (buffer-file-name ediff-buffer-A)))
    (when (yes-or-no-p (format "Retrieve changes from %s org?" target-org))
      (salesforce-project-retrieve file target-org)
      (salesforce-project--ediff-save ediff-buffer-A))))

(defun salesforce-project--ediff-save (buffer)
  "Save changes from the Ediff BUFFER to a local file."
  (interactive)
  (let ((file (buffer-file-name buffer)))
    (if (called-interactively-p 'any)
        (when (yes-or-no-p (format "Save changes to %s file?" file))
          (with-current-buffer buffer
            (save-buffer)))
      (with-current-buffer buffer
        (save-buffer)))))

(defun salesforce-project--ediff-cleanup (buffer)
  "Cleanup and kill BUFFER with its window."
  (when buffer
    (with-current-buffer buffer
      (kill-buffer-and-window))))

(defun salesforce-project--ediff-quit ()
  "Hook to run on Ediff quit, cleaning up buffers and hooks."
  (salesforce-project--ediff-cleanup ediff-buffer-A)
  (salesforce-project--ediff-cleanup ediff-buffer-C)
  
  ;; Clear hooks and keybindings
  (remove-hook 'ediff-startup-hook #'salesforce-project--ediff-start)
  (remove-hook 'ediff-quit-hook #'salesforce-project--ediff-quit)
  (remove-hook 'ediff-mode-hook #'salesforce-project--ediff-keys))

(defun salesforce-project--ediff-3way (file-a file-b file-c)
  "Set up an Ediff session for three files with appropriate hooks.
  FILE-A, FILE-B, and FILE-C are the files to compare."
  (ediff-files3 file-a file-b file-c
                `((lambda ()
                    (add-hook 'ediff-startup-hook 
                              #'salesforce-project--ediff-start)
                    (add-hook 'ediff-quit-hook 
                              (lambda () 
                                (salesforce-project--ediff-quit)
                                (delete-directory (file-name-directory ,file-b) t)
                                (delete-directory (file-name-directory ,file-c) t)))))))

(defun salesforce-project--ediff-setup (local-file cloud-file)
  "Prepare an Ediff session between LOCAL-FILE and CLOUD-FILE with proper hooks."
  (setq ediff-long-help-message-function 
        #'salesforce-project--ediff-help)
  
  (ediff local-file cloud-file
         `((lambda ()
             (add-hook 'ediff-quit-hook 
                       #'salesforce-project--ediff-quit)
             (add-hook 'ediff-startup-hook 
                       #'salesforce-project--ediff-start)))))

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

;;TODO: support multi org
(defun salesforce-project-diff-org ()
  "Diff source between the local project and a specific Salesforce platform."
  (interactive)
  (salesforce-org-read
   (pcase-lambda (`(,org . ,data))
     (salesforce-project-diff org))
   :prompt "Org: "
   :require-match t))

(defun salesforce-project-diff (&optional org)
  "Diff source between the local project and a Salesforce platform.
  Optionally specify a TARGET-ORG."
  (interactive (list (salesforce-project-org salesforce-project-session)))
  (let* ((file (buffer-file-name)))
    (emacs-pp-job
     (lambda ()
       (salesforce-project--pull-metadata file
         :org org))
     (lambda ()
       (let ((pulled-file (salesforce--find-file (file-name-base file)
                                                 temporary-file-directory)))
         (salesforce-project--ediff-setup pulled-file file)))
     :catch
     (lambda (error)
       (salesforce-core--alert (format "%s" error)
                               :severity 'urgent)))))

;;; Multi-Source Operations

(defun salesforce-project--process-multi-sources (files command)
  "Process multiple metadata FILES with the specified COMMAND."
  (let ((args (apply #'append
                     (list command "start" "--json")
                     (cl-loop for file in files
                              collect (list "-d" file)))))
    (salesforce-core--project-process
     :args args
     :callback (lambda (json-instance)
                 (if (and json-instance (eq (map-elt json-instance "status") 0))
                     (salesforce-core--alert (concat "Success " command " files"))
                   (salesforce-core--alert
                    (format "Failed to %s files" command)
                    :severity 'urgent))))))

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
  (file-name-directory (file-relative-name file-name (salesforce-project-root))))

(defun salesforce-project--create-temp-project-folder (temp-dir relative-path)
  "Create a temporary folder structure matching the project layout.
  TEMP-DIR is the base directory for the temporary structure.
  RELATIVE-PATH is the path within the project to replicate."
  (let* ((temp-dir (salesforce--ensure-directory-exists temp-dir))
         (dest-dir (file-name-directory 
                    (expand-file-name relative-path temp-dir)))
         (salesforce-project-file 
          (expand-file-name "sfdx-project.json" (salesforce-project-root))))
    
    ;; Create destination directory structure
    (unless (file-exists-p dest-dir)
      (make-directory dest-dir t))
    
    ;; Copy sfdx-project.json to project temp
    (unless (file-exists-p (expand-file-name "sfdx-project.json" temp-dir))
      (copy-file salesforce-project-file 
                 (expand-file-name "sfdx-project.json" temp-dir) 
                 t))
    
    dest-dir))

;; Unused functions

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

;;TODO: refactor maybe this will useful in some case
(defun salesforce-project-deploy-select (file-name)
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
       
       (salesforce-project--ediff-setup cloud-file-path file-name)))))

;;; User Management

(defun salesforce-project--users ()
  "List stale users that connected."
  (let ((alias-file (expand-file-name "~/.sfdx/alias.json")))
    (when (file-exists-p alias-file)
      (let ((json
             (with-temp-buffer
               (insert-file-contents alias-file)
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

(defun salesforce-project--user-data (username-or-alias key)
  "Get Salesforce user authentication data using USERNAME-OR-ALIAS and KEY."
  (when-let* ((table (salesforce-project--users))
              (user-name (salesforce-project--resolve-username 
                          username-or-alias table))
              (json-file (format "~/.sfdx/%s.json" user-name))
              (_ (file-exists-p (expand-file-name json-file)))
              (data (with-temp-buffer
                      (insert-file-contents (expand-file-name json-file))
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
  (when (and (bound-and-true-p salesforce-mode)
             salesforce-project-session)
    (let ((org-name (salesforce-project-org salesforce-project-session)))
      ;; Lazy load org name if empty
      (when (or (null org-name) (string-empty-p org-name))
        (setq org-name (salesforce-project--org-name))
        (when org-name
          (setf (salesforce-project-org salesforce-project-session) org-name)))
      (when (and org-name (not (string-empty-p org-name)))
        (concat (propertize (concat salesforce-project-mode-line-icon " " org-name)
                            'face 'salesforce-mode-line-face)
                salesforce-mode-line-current-org-status)))))

;;; Utility Functions

(defun salesforce-project--strip-meta (original-name)
  "Remove the '-meta.xml' suffix from ORIGINAL-NAME for display."
  (string-replace "-meta.xml" "" original-name))

;;; Create Field Menu (WIP)

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

(defun salesforce-project-cmdt-field ()
  "Create custom field on Custom Metadata object."
  (interactive)
  (let ((args (transient-args 'salesforce-project--transient:custom-metadata-field-menu)))
    (salesforce-core--cmdt-process
     :args `("generate" "field" ,@args)
     :callback (lambda (_)
                 (salesforce-core--alert "Create field on custom metadata succeeded")))))

(provide 'salesforce-project)

;;; salesforce-project.el ends here
