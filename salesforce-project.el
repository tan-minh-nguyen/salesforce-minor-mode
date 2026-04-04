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

(defvar salesforce-project-session nil
  "Save session of salesforce project.")

(defclass salesforce-project ()
  ((metadata-directory
    :initarg :metadata-directory
    :initform (projectile-expand-root "force-app/main/default")
    :accessor salesforce-project-source
    :type string
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
    :documentation "Access token (not persisted to dir-locals).")
   (tool-directory
    :initarg :tool-directory
    :initform ".sfdx/tools"
    :accessor salesforce-project-tool-directory
    :type string
    :documentation "Directory of tool directory."))
  :documentation "Configurations of Salesforce project.")

(defconst salesforce-project-metadata-paths
  '((class . "classes/")
    (trigger . "triggers/")
    (lwc . "lwc/")
    (aura . "aura/")
    (page . "pages/")
    (component . "components/")
    (flow . "flows/")
    (profile . "profiles/")
    (permission-set . "permissionsets/")
    (layout . "layouts/")
    (label . "labels/")
    (static-resource . "staticresources/")
    (report . "reports/")
    (dashboard . "dashboards/")
    (document . "documents/")
    (email-template . "email/")
    (sobject . "sobjects/")
    (manifest . "manifest/"))
  "Metadata type to subdirectory mapping.")

(cl-defmethod salesforce-project-source-path ((project salesforce-project) &key path)
  "Return expanded PATH under source directory in PROJECT."
  (expand-file-name path (salesforce-project-source project)))

(cl-defmethod salesforce-project-metadata-path ((project salesforce-project) type)
  "Return metadata directory for TYPE in PROJECT."
  (salesforce-project-source-path project
    :path (alist-get type salesforce-project-metadata-paths)))

(cl-defmethod salesforce-project-tool-path ((project salesforce-project) &key path)
  "Return expanded PATH under tool directory in PROJECT."
  (expand-file-name path (salesforce-project-tool-directory project)))

(cl-defmethod salesforce-project-log-dir ((project salesforce-project))
  "Return log directory of PROJECT."
  (salesforce-project-tool-path project :path "debug/logs/"))

(cl-defmethod salesforce-project-cache-dir ((project salesforce-project))
  "Return cache directory of PROJECT."
  (salesforce-project-tool-path project :path "cache/"))

;;;###autoload
(cl-defun salesforce-project-p (&key directory)
  "Determine if DIRECTORY is a Salesforce project.
  If DIR is not provided, use the current projectile project root."
  (let ((default-directory (or directory (projectile-project-root))))
    (cl-some #'projectile-verify-file-wildcard salesforce-files-test-root)))

;;;###autoload 
(defun salesforce-project-init ()
  "Initialize configuration for a Salesforce project.
  Sets up metadata and applies directory locals."
  (when (and (equal (projectile-project-type) 'salesforce)
             (not (salesforce-project--locals-p)))
    (let ((enable-local-variables :all))
      (salesforce-project--setup)
      (salesforce-project--apply-locals)
      (salesforce-project--save-locals))))

;;; Configuration Management

(defun salesforce-project--config-path (root)
  "Return the config file path for the project ROOT.
  Checks both .sf/config.json and legacy .sfdx/sfdx-config.json."
  (let ((modern-config (expand-file-name ".sf/config.json" root))
        (legacy-config (expand-file-name ".sfdx/sfdx-config.json" root)))
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
  (let* ((root (projectile-project-root))
         (config-file (salesforce-project--config-path root)))
    (and config-file (salesforce-project--config-org config-file))))

(defun salesforce-project--setup ()
  "Locate and configure the metadata directory for the current project."
  (when-let* ((root-directory (projectile-project-root))
              (project-setup (make-instance 'salesforce-project
                                            :org (salesforce-project--org-name))))
    ;;TODO: add auto update org when default org was configured
    (salesforce-project--set-local 'salesforce-project-session project-setup)))

(defun salesforce-project--locals-file ()
  "Return .dir-locals.el path if it exists, nil otherwise."
  (when-let* ((path (expand-file-name ".dir-locals.el" (projectile-project-root)))
              (_ (file-exists-p path)))
    path))

(defun salesforce-project--locals-p ()
  "Return t when .dir-locals.el exists."
  (and (salesforce-project--locals-file) t))

(defun salesforce-project--save-locals ()
  "Save config of project to dir-locals.el."
  (when-let ((file (salesforce-project--locals-file)))
    (with-current-buffer (find-file-noselect file)
      (save-buffer))))

(defun salesforce-project-local-get (symbol &optional mode)
  "Return non-nil if SYMBOL exists under MODE in project configuration.
  If MODE is nil, check the default project entry."
  (assoc symbol (alist-get mode salesforce-project-configuration)))

(defalias 'salesforce-project-local-p 
  #'salesforce-project-local-get)

(defun salesforce-project--set-local (symbol value &optional force)
  "Update project configuration for SYMBOL with VALUE.
  Configuration is stored in `salesforce-project-configuration'.
  If FORCE is non-nil, update even if value hasn't changed."
  (unless (symbolp symbol)
    (error (format "%s should be symbol" symbol)))
  (when (or (not (eq (cdr (salesforce-project-local-p symbol)) value))
           force)
    (let ((mode-entry (assoc nil salesforce-project-configuration)))
      (if mode-entry
          ;; Mode entry exists, update or add symbol
          (let ((symbol-list (cdr mode-entry)))
            (if (assoc symbol symbol-list)
                ;; Symbol exists, update its value
                (setf (alist-get symbol symbol-list) value)
              ;; Symbol doesn't exist, add it
              (setf (alist-get nil salesforce-project-configuration)
                    (cons (cons symbol value) symbol-list))))
        ;; Mode entry doesn't exist, create it
        (push (cons nil (list (cons symbol value)))
              salesforce-project-configuration)))))

(defun salesforce-project--apply-locals ()
  "Apply directory local variables for the current project."
  (dir-locals-set-class-variables 'project-configuration
                                  salesforce-project-configuration)
  (dir-locals-set-directory-class (projectile-project-root)
                                  'project-configuration)
  (hack-dir-local-variables-non-file-buffer))

(defun salesforce-project--save-session ()
  "Save session to dir-locals without token.
  Clones the session object and sets token to nil before saving
  to prevent sensitive data from being persisted to disk."
  (when salesforce-project-session
    (let ((copy (clone salesforce-project-session)))
      (setf (salesforce-project-token copy) nil)
      (salesforce-project--set-local
       'salesforce-project-session copy))))

;;; Projectile Integration
;;;###autoload
(defun salesforce-project-setup-projectile ()
  "Register Salesforce project type for Projectile."
  (projectile-register-project-type 'salesforce 
                                    salesforce-files-test-root
                                    :project-file ".forceignore"
                                    :compile "npm install && npm run build")

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
                                            '("standard" "empty" "project"))))
    (unless (file-exists-p project-dir)
      (make-directory project-dir 'parents))
    (salesforce-core--project-process
     :args (list "generate"
                 "--name" project-name
                 "--template" project-template
                 "--output-dir" project-dir
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
           "-o" org
           "--json")
   :callback
   (lambda (_)
     (salesforce-core--alert (format "Deploy %s success" buffer)))))

(cl-defun salesforce-project-retrieve (file &key (org (salesforce-project-org salesforce-project-session)))
  "Retrieve source from a Salesforce org into the specified FILE.
  Optionally specify a ORG."
  (interactive (list (buffer-file-name)))
  (declare (indent 1))
  (salesforce-core--project-process
   :args `("retrieve" "start" "-d" ,file
           "-o" org
           "--json")
   :callback
   (lambda (_)
     (salesforce-core--alert (format "Retrieve %s success" buffer)))))

;;; Cloud Metadata Operations

(cl-defun salesforce-project--pull-metadata
    (file &key (save-directory temporary-file-directory) (org (salesforce-project-org salesforce-project-session)) then)
  "Clone cloud metadata from a Salesforce org.
  METADATA-FILE specifies the file to retrieve.
  TARGET-PATH is the local path to store the metadata.
  TARGET-ORG specifies the Salesforce org.
  FINISH-FUNC is a function to call upon completion."
  (declare (indent 1))
  (salesforce-core--project-process
   :args `("retrieve" "start"
           "-d" ,file
           "-t" ,save-directory
           "--zip-file-name" ,file
           "-o" ,org
           "-z"
           "--json")
   :callback then))

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
  (let* ((file (buffer-file-name))
         (file-name (file-name-base (buffer-file-name))))
    (emacs-pp-job
     (lambda ()
       (salesforce-project--pull-metadata file-name
                                          :org org))
     (lambda ()
       (let ((pulled-file (salesforce--find-file (file-name-nondirectory file)
                                                 (expand-file-name file-name temporary-file-directory))))
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

(defun salesforce-project--user-data (username-or-alias key)
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
