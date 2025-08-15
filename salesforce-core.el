;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'alert)
(require 'cl)
(require 'json)
(require 'async)

(defvar salesforce-debug nil
  "Enable debug.")

(defconst salesforce-tools-dir "tools"
  "Tools folder name.")

(defconst salesforce-state-dir ".sfsalesforce"
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
  "The legacy command alias for Salesforce CLI (sfsalesforce)."
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

(defcustom salesforce-default-browser "qutebrowser"
  "The default browser to use for opening Salesforce URLs."
  :type 'string
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

(defcustom salesforce-process-buffer "*SALESFORCE Process*"
  "Name of the buffer used for displaying Salesforce CLI process output."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-process-success-buffer "SALESFORCE Success"
  "Name of the buffer used for displaying successful process results."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-process-error-buffer "SALESFORCE Error"
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

(defcustom salesforce-mode-line-active-connect-icon "\xf444"
  "Icon display on mode-line when current org is active.")

(defcustom salesforce-mode-line-disconnect-icon "\xf444"
  "Icon display on mode-line when current org is disconnect.")

(defcustom salesforce-mode-line-current-org-status nil
  "Icon display on mode-line when current org is active.")

(defcustom salesforce-mode-line-icon "\xf0c2"
  "`salesforce-minor-mode' icon."
  :type 'string
  :group 'salesforce-config)

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
(defcustom salesforce-log-dir-path ".sfsalesforce/tools/debug/logs/"
  "Path to the directory where Salesforce debug logs are stored."
  :type 'string
  :group 'salesforce-config)

(defun salesforce-build-sf-command (&rest args)
  `(,@args))

(cl-defun salesforce-convert-hashtable-data-to-list
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

(defun salesforce-recursive-list (list-data lambda-function)
  ""
  (let* ((new-list (cdr list-data))
         (first-item (car list-data))
         (remap-list '()))

    (when (length> new-list 0)
      (setq remap-list
            (append remap-list
                    (salesforce-recursive-list new-list lambda-function))))

    (add-to-list 'remap-list (funcall lambda-function first-item))))

(defun salesforce-core--get-json-value (table key)
  "Get value from TABLE by KEY based on data structure type."
  (cond ((plistp table)
         (plist-get table key (lambda (prop key)
                                (string= (format ":%s" key) (symbol-name prop)))))
        ((arrayp table)
         (aref table (string-to-number key)))
        (t
         (gethash key table))))

(defun salesforce-core--get-data-json (path table)
  "Get nested data from TABLE following the dot-separated PATH.
Example: (salesforce-core--get-data-json \"result.data.0.name\" table)"
  (let ((path-parts (split-string path "\\.")))
    (cl-reduce (lambda (acc key)
                 (salesforce-core--get-json-value acc key))
               path-parts
               :initial-value table)))

(defun salesforce-core--find-root-dir ()
  (cdr (project-current)))

(defun salesforce-core--tools-folder ()
  "Get tools folder path in project."
  (concat salesforce-state-dir "/" salesforce-tools-dir))

(defun salesforce-core--build-path (&rest args)
  "Build a full path from root directory and additional path components."
  (mapconcat 'identity `(,(salesforce-core--find-root-dir) ,@args)))

(defun salesforce-core--metadata-path (&optional path)
  "Get full path for metadata directory.
If PATH is provided, append it to the metadata root directory."
  (let ((base-path (expand-file-name salesforce-metadata-root-dir (salesforce-core--find-root-dir))))
    (if path
        (expand-file-name path base-path)
      base-path)))

;;;###autoload
(cl-defun salesforce-internal-current-org ()
  (let* ((root-dir (salesforce-core--find-root-dir))
         (config-path (concat root-dir ".sf/config.json"))
         (old-config-path (concat root-dir ".sfsalesforce/sfsalesforce-config.json")))

    (cond
     ;; Return empty string if config files not exist
     ((not (or (file-exists-p config-path)
             (file-exists-p old-config-path)))
      "")
     ;; Return org name var if root dir not change
     ((and (string= root-dir salesforce-project-root-dir)
         salesforce-org-name)
      salesforce-org-name)
     ;; Find org alias in root dir
     (t
      (condition-case org-name
          (string-replace "\n" ""
                          (shell-command-to-string (concat "[ -f " config-path " ] && grep -Po '(?<=\"target-org\": )\"[^\"]+\"' " config-path " | sed -E 's/\"([^\"]+)\"/\\1/' || grep -Po '(?<=\"defaultusername\": )\"[^\"]+\"' " old-config-path " | sed -E 's/\"([^\"]+)\"/\\1/'")))
        (:success org-name)
        (error
         (salesforce-core--get-data-json "result.0.value"
                                 (salesforce-core--config-process
                                  :cmd '("get" "target-org" "--json")))))))))

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
                                  (funcall callback 
                                           (if (member "--json" ,cmd)
                                               (salesforce-parse-buffer-json (process-buffer proc))
                                             (process-buffer proc))))))

          (apply #'async-start-process "salesforce-process"
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

;; Async library
(defun salesforce-start-process (&optional callback &rest params &allow-other-keys)
  "Start salesforce process."
  (when salesforce-debug
    (message "%s" params))
  (apply #'async-start-process "salesforce-process"
         salesforce-program-bin 
         callback
         params))

(defun salesforce-parse-buffer-json (buffer)
  "Parsing json on buffer."
  (condition-case data
      (with-current-buffer buffer
        (beginning-of-buffer)
        (json-parse-buffer :object-type 'plist))
    (:succes data)
    (error (with-current-buffer buffer (buffer-string)))))

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
                     (t (or (salesforce-org--list nil :sync t) '())))
               :initial-value '())))



;; Modify async package to handle signal process
(defun salesforce--async-when-done (proc &optional _change)
  "Handle signal process return from sf package."
  (when-let ((_ (eq (process-exit-status proc) 1))
             (_ (string= "salesforce-process" (process-name proc))))
    (condition-case error
        (salesforce-handle-process-error--json (salesforce-parse-buffer-json (process-buffer proc))))))

(advice-add 'async-when-done :after #'salesforce--async-when-done)

(defun salesforce-core--alert (message &rest args)
  "Display an alert with MESSAGE and optional ARGS.
This function uses the `alert` package to show notifications."
  (unless (plist-member args :title)
    (plist-put args :title (projectile-project-name)))
  (apply 'alert message args))

(provide 'salesforce-core)
