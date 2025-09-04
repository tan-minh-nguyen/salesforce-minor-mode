;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'alert)
(require 'cl)
(require 'json)
(require 'async)

(defvar salesforce-debug nil
  "Enable debug.")

(defconst salesforce-tools-dir "tools"
  "Tools folder name.")

(defconst salesforce-state-dir ".sfdx"
  "Folder contains information of project.")

(defconst salesforce-custom-objects-dir "customObjects"
  "Directory contains custom sobjects.")

(defconst salesforce-standard-objects-dir "standardObjects"
  "Directory contains standard sobjects.")

(defconst salesforce-sobjects-dir "sobjects"
  "Directory contains sobjects.")

(defconst salesforce-soql-metadata-dir "soqlMetadata"
  "Directory contains soql metadata.")

(defcustom salesforce-tangle-on-save t
  "When t, automatically tangle Org files on save."
  :type 'boolean
  :group 'salesforce-minor-mode)

(defcustom salesforce-api-version "61.0"
  "Custom define api version for command."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-org-list-header-display
  '("username" "instanceUrl" "orgId" "isDevHub" "instanceApiVersion" "alias" "lastUsed" "connectedStatus")
  "Custom define header display on table non scratch orgs"
  :type 'list
  :group 'salesforce-minor-mode)

(defcustom salesforce-program-bin "sf"
  "Path to Salesforce CLI."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-legacy-alias "force"
  "The legacy command alias for Salesforce CLI (sfdx)."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-project-command-alias "project"
  "The command alias for project-related Salesforce CLI commands."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-data-command-alias "data"
  "The command alias for data-related Salesforce CLI commands."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-visualforce-command-alias "visualforce"
  "The command alias for Visualforce-related Salesforce CLI commands."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-apex-command-alias "apex"
  "The command alias for Apex-related Salesforce CLI commands."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-org-command-alias "org"
  "The command alias for org-related Salesforce CLI commands."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-lightning-command-alias "lightning"
  "The command alias for Lightning-related Salesforce CLI commands."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-config-command-alias "config"
  "The command alias for configuration-related Salesforce CLI commands."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-whatsnew-command-alias "whatsnew"
  "The command alias for configuration-related Salesforce CLI commands."
  :type 'string
  :group 'salesforce-minor-mode)

(defvar salesforce-core--org-list-cache nil
  "Cache for org list data. Format: ((timestamp . org-list-data))")

(defcustom salesforce-core--org-list-cache-ttl 300000
  "Time-to-live for org list cache in seconds."
  :type 'integer
  :group 'salesforce-minor-mode)

(defcustom salesforce-metadata-define-roots '((default . "force-app/main/default"))
  "List Root Salesforce directories."
  :type 'alist
  :group 'salesforce-minor-mode)

(defvar salesforce-metadata-root-dir "force-app/main/default"
  "Root Salesforce directory.")

(defvar salesforce-trigger-dir "triggers"
  "Path save apex classes")

(defvar salesforce-apex-dir "classes"
  "Directory path for Apex classes")

(defvar salesforce-lwc-dir "lwc"
  "Directory path for LWC components")

(defvar salesforce-aura-dir "aura" 
  "Directory path for Aura components")

(defvar salesforce-vf-dir "pages"
  "Directory path for Visualforce pages")

(defvar salesforce-vf-component-dir "components"
  "Directory path for Visualforce components")

(defvar salesforce-test-dir "lightningTests"
  "Directory path for test components")

(defvar salesforce-object-dir "objects"
  "Directory path for object metadata")

(defvar salesforce-package-dir "manifest"
  "Custom define api version for command")

(defcustom salesforce-org-cache-dir ".cache/"
  "Directory to store cache files relative to the project root."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-dedicated-window-right "*List View*"
  "Name of the dedicated window buffer displayed on the right side."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-tracking-time-format "%Y-%m-%d %H:%M:%S"
  "Format string for displaying timestamps in the metadata tracking buffer."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-process-buffer "salesforce process"
  "Name of the buffer used for displaying Salesforce CLI process output."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-process-success-buffer "salesforce success"
  "Name of the buffer used for displaying successful process results."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-process-error-buffer "salesforce error"
  "Name of the buffer used for displaying process error messages."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-project-config '()
  "List of project configurations.
Each element should be a plist with :project and :note-file keys.
Example: ((:project \"test\" :note-file \"org\"))"
  :type 'list
  :group 'salesforce-minor-mode)

(defvar salesforce-org-name nil
  "The name of the currently active Salesforce org, displayed in the mode line.")

(defcustom salesforce-prefix-keymap "M"
  "The prefix key for Salesforce SALESFORCE commands in the keymap."
  :type 'string
  :group 'salesforce-config)

(defvar-local salesforce-project-root-dir ""
  "Full path project root.")

(defface salesforce-mode-line-face
  '((((type praphic) (class color) (background dark))
     :foreground "DodgerBlue1" :slant oblique :weight bold)
    (((type praphic) (class color) (background light))
     :foreground "DodgerBlue4" :slant oblique :weight bold)
    (((type tty) (class color) (background dark))
     :foreground "DodgerBlue1" :slant oblique :weight bold)
    (t (:foreground "DodgerBlue1" :slant oblique :weight bold)))
  "Font lock for salesfoce minor mode on mode line."
  :group 'font-lock-rules)

;; salesforce-log.el configurations
(defcustom salesforce-log-dir-path ".sfdx/tools/debug/logs/"
  "Path to the directory where Salesforce debug logs are stored."
  :type 'string
  :group 'salesforce-config)

(defun salesforce-build-sf-command (&rest args)
  `(,@args))

(defun salesforce-recursive-list (list-data lambda-function)
  "Recursively apply LAMBDA-FUNCTION to each element in LIST-DATA."
  (if (null list-data)
      nil
    (cons (funcall lambda-function (car list-data))
          (salesforce-recursive-list (cdr list-data) lambda-function))))


(defun salesforce-core--get-json-value (table key)
  "Get value from TABLE by KEY based on data structure type."
  (cond ((plistp table)
         (plist-get table key (lambda (prop key)
                                (string= (format ":%s" key) (symbol-name prop)))))
        ((arrayp table)
         (aref table (string-to-number key)))
        ((hash-table-p table)
         (gethash key table))
        (t nil)))

(defun salesforce-core--get-data-json (path table)
  "Get nested data from TABLE following the dot-separated PATH.
Example: (salesforce-core--get-data-json \"result.data.0.name\" table)"
  (let ((path-parts (split-string path "\\.")))
    (cl-reduce (lambda (acc key)
                 (salesforce-core--get-json-value acc key))
               path-parts
               :initial-value table)))

(defun salesforce-core--find-root-dir ()
  "Return the root directory of the current project using `project-current'."
  (cdr (project-current)))

(defun salesforce-core--tools-folder ()
  "Get tools folder path in project."
  (salesforce-core--build-path salesforce-state-dir "/" salesforce-tools-dir))

(defun salesforce-core--build-path (&rest args)
  "Build a full path from root directory and additional path components."
  (mapconcat 'identity `(,(salesforce-core--find-root-dir) ,@args)))

(defun salesforce-core--metadata-path (&optional path)
  "Return the full path for the metadata directory.
If PATH is non-nil, append it to the metadata root directory."
  (let ((base (expand-file-name
               salesforce-metadata-root-dir
               (salesforce-core--find-root-dir))))
    (expand-file-name (or path "") base)))

(defun salesforce--get-cache-folder-path ()
  "Get absolute path of cache directory."
  (let ((cache-dir (expand-file-name (concat salesforce-org-cache-dir salesforce-org-name "/") (salesforce-core--find-root-dir))))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir 'parents))

    cache-dir))

(defun salesforce--ensure-directory-exists (path)
  "Create directory at PATH if it doesn't exist."
  (unless (file-exists-p path)
    (make-directory path 'parents))
  path)

(defun salesforce--get-log-dir-path ()
  "Get absolute path of log directory.
Creates the directory if it doesn't exist."
  (let ((log-dir (expand-file-name salesforce-log-dir-path (salesforce-core--find-root-dir))))
    (salesforce--ensure-directory-exists log-dir)))

(defmacro salesforce--find-backup-files (file-name &optional dir)
  "Find backup files."
  `(when-let* ((org-name salesforce-org-name)
               (default-directory (or ,dir (salesforce--get-cache-folder-path))))

     (directory-files-recursively default-directory
                                  ,file-name)))

(defmacro salesforce--find-backup-file (file-name &optional dir)
  "Find backup file."
  `(car (salesforce--find-backup-files ,file-name ,dir)))

(defun salesforce--get-lwc-directory ()
  "Get lwc directory."
  (expand-file-name salesforce-default-lwc-path (salesforce-core--find-root-dir)))

(defun salesforce--find-parents (file &optional depth)
  "Find parents of directory."
  (if (< depth 1)
      (file-name-directory (directory-file-name file))
    (salesforce--find-parents (file-name-directory (directory-file-name file)) (- depth 1))))

(defmacro salesforce-core--make-process (command-alias)
  "Create a process macro for a specific command type.
COMMAND-ALIAS is the command prefix (e.g. salesforce-project-command-alias).
BODY contains the process handling code."
  `(cl-defmacro ,(intern (format "salesforce-core--%s-process" (symbol-value command-alias)))
       (&rest body &key cmd sync &allow-other-keys)
     (let ((alias ,(symbol-value command-alias)))
       `(let* ((callback (lambda (json-instance)
                           ,@body))
               (handle-callback (lambda (proc)
                                  (when-let* ((data (if (member "--json" ,cmd)
                                                        (salesforce-core-parse-buffer-json (process-buffer proc))
                                                      (process-buffer proc)))
                                              (_ (if (plistp data)
                                                     (= (salesforce-core--get-data-json "status" data) 0)
                                                   (not (string-blank-p data)))))
                                    (funcall callback data)))))

          (apply #'async-start-process salesforce-process-buffer
                 salesforce-program-bin 
                 (unless ,sync handle-callback)
                 (cons ,alias ,cmd))))))

;; Generate all process macros using the factory
(salesforce-core--make-process salesforce-project-command-alias)
(salesforce-core--make-process salesforce-apex-command-alias) 
(salesforce-core--make-process salesforce-visualforce-command-alias)
(salesforce-core--make-process salesforce-data-command-alias)
(salesforce-core--make-process salesforce-org-command-alias)
(salesforce-core--make-process salesforce-lightning-command-alias)
(salesforce-core--make-process salesforce-config-command-alias)
(salesforce-core--make-process salesforce-whatsnew-command-alias)

(defun salesforce-core-parse-buffer-json (buffer)
  "Parse JSON from BUFFER and return it as a plist.
If parsing fails, return the raw buffer contents as a string."
  (condition-case err
      (with-current-buffer buffer
        (beginning-of-buffer)
        (json-parse-buffer :object-type 'plist))
    (error `(:status 1 :content ,(with-current-buffer buffer
                                   (buffer-string))))))

(defun salesforce-process--handle-error-metadata-action (json-instance)
  "Get error messages of metadata action."
  (mapconcat (lambda (component-error)
               (format "Metadata name: %s\nMetadata type: %s\nLine: %s\nError: %s"
                       (plist-get component-error :fileName)
                       (plist-get component-error :componentType)
                       (plist-get component-error :lineNumber)
                       (plist-get component-error :problem)))
             ;; List of error messages
             (salesforce-core--get-data-json "result.details.componentFailures" json-instance)
             ;; Separator for each failed components
             "\n=======================\n"))


(defun salesforce-process--handle-common-error (json-instance)
  "Get common error message in fail operation."
  (format "Name: %s\nMessage: %s" 
          (plist-get json-instance :name)
          (plist-get json-instance :message)))

(defun salesforce-handle-process-error--json (json-instance)
  "Handle error response by salesforce process."
  (let ((show-message (cond 
                       ;; TODO: handle error base on type of action instead of status prop
                       ((not (plist-member json-instance :context)) 
                        (salesforce-process--handle-error-metadata-action json-instance))
                       (t (salesforce-process--handle-common-error json-instance)))))

    (salesforce-core--alert show-message
                            :severity 'urgent)
    show-message))

(defun salesforce-core--projects (prefix)
  "List projects."
  (-filter (lambda (project)
             (s-prefix-p prefix project))
           (projectile-relevant-known-projects)))

(defun salesforce-core--orgs (prefix)
  "List orgs."
  (let ((async-debug t))
    (cl-reduce (lambda (result org)
                 (when-let* ((alias (plist-get org :alias))
                             (_ (s-prefix-p prefix alias)))
                   (setq result (append result `(,alias))))
                 (when (null prefix)
                   (setq result (append result `(,(plist-get org :alias)))))
                 result)
               (cond ((assoc-default 'data salesforce-core--org-list-cache)
                      (assoc-default 'data salesforce-core--org-list-cache))
                     (t (or (salesforce-org-list nil :sync t) '())))
               :initial-value '())))



;; Modify async package to handle signal process
(defun salesforce-core--async-when-done (proc &optional _change)
  "Handle signal process return from sf package."
  (when-let ((_ (eq (process-exit-status proc) 1))
             (_ (string= salesforce-process-buffer (process-buffer proc))))
    (condition-case error
        (salesforce-handle-process-error--json (salesforce-core-parse-buffer-json (process-buffer proc))))))

(advice-add 'async-when-done :after #'salesforce-core--async-when-done)

(defun salesforce-core--alert (message &rest args)
  "Display an alert with MESSAGE and optional ARGS.
This function uses the `alert` package to show notifications."
  (unless (plist-member args :title)
    (plist-put args :title (projectile-project-name)))
  (apply #'alert message args))

(provide 'salesforce-core)
