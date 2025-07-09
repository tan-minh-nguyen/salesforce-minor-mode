;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'alert)
(require 'cl)
(require 'json)
(require 'async)

(defvar dx-debug nil
  "Enable debug.")

(defconst dx-tools-dir "tools"
  "Tools folder name.")

(defconst dx-state-dir ".sfdx"
  "Folder contains information of project.")

(defconst dx-custom-objects-dir "customObjects"
  "Directory contains custom sobjects.")

(defconst dx-stardard-objects-dir "standardObjects"
  "Directory contains standard sobjects.")

(defconst dx-sobjects-dir "sobjects"
  "Directory contains sobjects.")

(defconst dx-soql-metadata-dir "soqlMetadata"
  "Directory contains soql metadata.")

(defcustom dx-tangle-on-save t
  "When t, automatically tangle Org files on save."
  :type 'boolean
  :group 'dx-minor-mode)

(defcustom dx-api-version "53.0"
  "Custom define api version for command."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-org-list-header-display
  '("username" "instanceUrl" "orgId" "isDevHub" "instanceApiVersion" "alias" "lastUsed" "connectedStatus")
  "Custom define header display on table non scratch orgs"
  :type 'list
  :group 'dx-minor-mode)

(defcustom dx-lib-alias "sf"
  "The command alias for the Salesforce CLI."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-legacy-alias "force"
  "The legacy command alias for Salesforce CLI (sfdx)."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-command-alias "project"
  "The command alias for project-related Salesforce CLI commands."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-data-command-alias "data"
  "The command alias for data-related Salesforce CLI commands."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-visualforce-command-alias "visualforce"
  "The command alias for Visualforce-related Salesforce CLI commands."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-apex-command-alias "apex"
  "The command alias for Apex-related Salesforce CLI commands."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-org-command-alias "org"
  "The command alias for org-related Salesforce CLI commands."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-lightning-command-alias "lightning"
  "The command alias for Lightning-related Salesforce CLI commands."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-config-command-alias "config"
  "The command alias for configuration-related Salesforce CLI commands."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-whatsnew-command-alias "whatsnew"
  "The command alias for configuration-related Salesforce CLI commands."
  :type 'string
  :group 'dx-minor-mode)

(defvar dx-core--org-list-cache nil
  "Cache for org list data. Format: ((timestamp . org-list-data))")

(defcustom dx-core--org-list-cache-ttl 300000
  "Time-to-live for org list cache in seconds."
  :type 'integer
  :group 'dx-minor-mode)

(defcustom dx-default-browser "qutebrowser"
  "The default browser to use for opening Salesforce URLs."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-metadata-define-roots '((default . "force-app/main/default"))
  "List Root Salesforce directories."
  :type 'alist
  :group 'dx-minor-mode)

(defvar dx-metadata-root-dir "force-app/main/default"
  "Root Salesforce directory.")

(defvar dx-trigger-dir "triggers"
  "Path save apex classes")

(defvar dx-apex-dir "classes"
  "Directory path for Apex classes")

(defvar dx-lwc-dir "lwc"
  "Directory path for LWC components")

(defvar dx-aura-dir "aura" 
  "Directory path for Aura components")

(defvar dx-vf-dir "pages"
  "Directory path for Visualforce pages")

(defvar dx-vf-component-dir "components"
  "Directory path for Visualforce components")

(defvar dx-test-dir "lightningTests"
  "Directory path for test components")

(defvar dx-object-dir "objects"
  "Directory path for object metadata")

(defvar dx-package-dir "manifest"
  "Custom define api version for command")

(defcustom dx-org-cache-dir ".cache/"
  "Directory to store cache files relative to the project root."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-dedicated-window-right "*List View*"
  "Name of the dedicated window buffer displayed on the right side."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-tracking-time-format "%Y-%m-%d %H:%M:%S"
  "Format string for displaying timestamps in the metadata tracking buffer."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-process-buffer "*DX Process*"
  "Name of the buffer used for displaying Salesforce CLI process output."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-process-success-buffer "DX Success"
  "Name of the buffer used for displaying successful process results."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-process-error-buffer "DX Error"
  "Name of the buffer used for displaying process error messages."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-config '()
  "List of project configurations.
Each element should be a plist with :project and :note-file keys.
Example: ((:project \"test\" :note-file \"org\"))"
  :type 'list
  :group 'dx-minor-mode)

(defvar dx-org-name nil
  "The name of the currently active Salesforce org, displayed in the mode line.")

(defcustom dx-prefix-keymap "M"
  "The prefix key for Salesforce DX commands in the keymap."
  :type 'string
  :group 'dx-config)

(defvar-local dx-project-root-dir ""
  "Full path project root.")

(defvar dx-mode-line `(:eval (when (bound-and-true-p dx-minor-mode)
                               (if (string-blank-p dx-org-name) ""
                                 (concat (propertize (concat dx-mode-line-icon " " dx-org-name)
                                                     'face 'dx-mode-line-face)
                                         dx-mode-line-current-org-status))))
  "Salesfoce mode line.")

(defcustom dx-mode-line-active-connect-icon "\xf444"
  "Icon display on mode-line when current org is active.")

(defcustom dx-mode-line-disconnect-icon "\xf444"
  "Icon display on mode-line when current org is disconnect.")

(defcustom dx-mode-line-current-org-status nil
  "Icon display on mode-line when current org is active.")

(defvar dx-mode-line-icon "\xf0c2"
  "`dx-minor-mode' icon.")

(defface dx-mode-line-face
  '((((type praphic) (class color) (background dark))
     :foreground "DodgerBlue1" :slant oblique :weight bold)
    (((type praphic) (class color) (background light))
     :foreground "DodgerBlue4" :slant oblique :weight bold)
    (((type tty) (class color) (background dark))
     :foreground "DodgerBlue1" :slant oblique :weight bold)
    (t (:foreground "DodgerBlue1" :slant oblique :weight bold)))
  "Font lock for salesfoce minor mode on mode line."
  :group 'font-lock-rules)

;; dx-log.el configurations
(defcustom dx-log-dir-path ".sfdx/tools/debug/logs/"
  "Path to the directory where Salesforce debug logs are stored."
  :type 'string
  :group 'dx-config)

(defun dx-build-sf-command (&rest args)
  `(,@args))

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

(defun dx-core--get-json-value (table key)
  "Get value from TABLE by KEY based on data structure type."
  (cond ((plistp table)
         (plist-get table key (lambda (prop key)
                                (string= (format ":%s" key) (symbol-name prop)))))
        ((arrayp table)
         (aref table (string-to-number key)))
        (t
         (gethash key table))))

(defun dx-core--get-data-json (path table)
  "Get nested data from TABLE following the dot-separated PATH.
Example: (dx-core--get-data-json \"result.data.0.name\" table)"
  (let ((path-parts (split-string path "\\.")))
    (cl-reduce (lambda (acc key)
                 (dx-core--get-json-value acc key))
               path-parts
               :initial-value table)))

(defun dx-core--find-root-dir ()
  (cdr (project-current)))

(defun dx-core--tools-folder ()
  "Get tools folder path in project."
  (concat dx-state-dir "/" dx-tools-dir))

(defun dx-core--build-path (&rest args)
  "Build a full path from root directory and additional path components."
  (mapconcat 'identity `(,(dx-core--find-root-dir) ,@args)))

(defun dx-core--metadata-path (&optional path)
  "Get full path for metadata directory.
If PATH is provided, append it to the metadata root directory."
  (let ((base-path (expand-file-name dx-metadata-root-dir (dx-core--find-root-dir))))
    (if path
        (expand-file-name path base-path)
      base-path)))

;;;###autoload
(cl-defun dx-internal-current-org ()
  (let* ((root-dir (dx-core--find-root-dir))
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
         (dx-core--get-data-json "result.0.value"
                                 (dx-core--config-process
                                  :cmd '("get" "target-org" "--json")))))))))

(defun dx--get-cache-folder-path ()
  "Get absolute path of cache directory."
  (let ((cache-dir (expand-file-name (concat dx-org-cache-dir dx-org-name "/") (dx-core--find-root-dir))))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir 'parents))

    cache-dir))

(defun dx--ensure-directory-exists (path)
  "Create directory at PATH if it doesn't exist."
  (unless (file-exists-p path)
    (make-directory path 'parents))
  path)

(defun dx--get-log-dir-path ()
  "Get absolute path of log directory.
Creates the directory if it doesn't exist."
  (let ((log-dir (expand-file-name dx-log-dir-path (dx-core--find-root-dir))))
    (dx--ensure-directory-exists log-dir)))

(defmacro dx--find-backup-files (file-name &optional dir)
  "Find backup files."
  `(when-let* ((org-name dx-org-name)
               (default-directory (or ,dir (dx--get-cache-folder-path))))

     (directory-files-recursively default-directory
                                  ,file-name)))

(defmacro dx--find-backup-file (file-name &optional dir)
  "Find backup file."
  `(car (dx--find-backup-files ,file-name ,dir)))

(defun dx--get-lwc-directory ()
  "Get lwc directory."
  (expand-file-name dx-default-lwc-path (dx-core--find-root-dir)))

(defun dx--find-parents (file &optional depth)
  "Find parents of directory."
  (if (< depth 1)
      (file-name-directory (directory-file-name file))
    (dx--find-parents (file-name-directory (directory-file-name file)) (- depth 1))))

(defmacro dx-core--make-process (command-alias)
  "Create a process macro for a specific command type.
COMMAND-ALIAS is the command prefix (e.g. dx-project-command-alias).
BODY contains the process handling code."
  `(cl-defmacro ,(intern (format "dx-core--%s-process" (symbol-value command-alias)))
       (&rest body &key cmd sync &allow-other-keys)
     (let ((alias ,(symbol-value command-alias)))
       `(let* ((callback (lambda (json-instance)
                           ,@body))
               (handle-callback (lambda (proc)
                                  (funcall callback 
                                           (if (member "--json" ,cmd)
                                               (dx-parse-buffer-json (process-buffer proc))
                                             (process-buffer proc))))))
          (apply #'dx-start-process
                 (unless ,sync handle-callback)
                 (cons ,alias ,cmd))))))

;; Generate all process macros using the factory
(dx-core--make-process dx-project-command-alias)
(dx-core--make-process dx-apex-command-alias) 
(dx-core--make-process dx-visualforce-command-alias)
(dx-core--make-process dx-data-command-alias)
(dx-core--make-process dx-org-command-alias)
(dx-core--make-process dx-lightning-command-alias)
(dx-core--make-process dx-config-command-alias)
(dx-core--make-process dx-whatsnew-command-alias)

(defun dx-make-chain-process (&rest process-list &key params &allow-other-keys)
  "Chain all processes."
  (let ((proc (pop process-list)))
    (dx-make-process
     :cmd (plist-get proc :cmd)
     :type 'async
     :callback (lambda (content)
                 (let ((result-proc (condition-case error
                                        (funcall (plist-get proc :callback) content params)
                                      (error (alert (format "%s" error)
                                                    :title "DX Alert"
                                                    :severity 'urgent)))))
                   (dx-make-chain-process (car process-list) :params result-proc))))))

(cl-defmacro dx-make-process-json-sync (&key cmd)
  "Execute sync dx cli command and return json result."
  `(condition-case json-instance
       (json-parse-string (dx-make-process :cmd ,cmd :type 'sync) :object-type 'plist)
     (:success json-instance)
     (error (cond ((string-match-p "json-parse-error" (symbol-name (car json-instance)))
                   (alert "something wrong with JSON result."
                          :title "DX Alert"
                          :severity 'urgent))
                  (t (alert json-instance
                            :title "DX Alert"
                            :severity 'urgent))))))

;; Async library
(defun dx-start-process (&optional callback &rest params &allow-other-keys)
  "Start dx process."
  (when dx-debug
    (message "%s" params))
  (apply #'async-start-process "dx-process"
         dx-lib-alias 
         callback
         params))


(defun dx-parse-buffer-json (buffer)
  "Parsing json on buffer."
  (condition-case data
      (with-current-buffer buffer
        (beginning-of-buffer)
        (json-parse-buffer :object-type 'plist))
    (:succes data)
    (error (with-current-buffer buffer (buffer-string)))))

(defun dx-process--handle-error-metadata-action (json-instance)
  "Get error messages of metadata action."
  (mapconcat (lambda (component-error)
               (format "Metadata name: %s\nMetadata type: %s\nLine: %s\nError: %s"
                       (plist-get component-error :fileName)
                       (plist-get component-error :componentType)
                       (plist-get component-error :lineNumber)
                       (plist-get component-error :problem)))
             ;; List of error messages
             (dx-core--get-data-json "result.details.componentFailures" json-instance)
             ;; Separator for each failed components
             "\n=======================\n"))


(defun dx-process--handle-common-error (json-instance)
  "Get common error message in fail operation."
  (format "Name: %s\nMessage: %s" 
          (plist-get json-instance :name)
          (plist-get json-instance :message)))

(defun dx-handle-process-error--json (json-instance)
  "Handle error response by dx process."
  (let ((show-message (cond 
                       ;; TODO: handle error base on type of action instead of status prop
                       ((not (plist-member json-instance :context)) 
                        (dx-process--handle-error-metadata-action json-instance))
                       (t (dx-process--handle-common-error json-instance)))))

    (alert show-message
           :title "DX Alert"
           :category 'error
           :severity 'urgent)
    show-message))

(defun dx-core--projects (prefix)
  "List projects."
  (-filter (lambda (project)
             (s-prefix-p prefix project))
           (projectile-relevant-known-projects)))

(defun dx-core--orgs (prefix)
  "List orgs."
  (let ((async-debug t))
    (cl-reduce (lambda (result org)
                 (when-let* ((alias (plist-get org :alias))
                             (_ (s-prefix-p prefix alias)))
                   (setq result (append result `(,alias))))
                 (when (null prefix)
                   (setq result (append result `(,(plist-get org :alias)))))
                 result)
               (cond ((assoc-default 'data dx-core--org-list-cache)
                      (assoc-default 'data dx-core--org-list-cache))
                     (t (or (dx-org--list nil :sync t) '())))
               :initial-value '())))



;; Modify async package to handle signal process
(defun dx--async-when-done (proc &optional _change)
  "Handle signal process return from sf package."
  (when-let ((_ (eq (process-exit-status proc) 1))
             (_ (string= "dx-process" (process-name proc))))
    (condition-case error
        (dx-handle-process-error--json (dx-parse-buffer-json (process-buffer proc))))))

(advice-add 'async-when-done :after #'dx--async-when-done)

(provide 'dx-core)
