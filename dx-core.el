;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'alert)
(require 'cl)
(require 'json)
(require 'async)

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
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-legacy-alias "force"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-command-alias "project"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-data-command-alias "data"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-visualforce-command-alias "visualforce"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-apex-command-alias "apex"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-org-command-alias "org"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-lightning-command-alias "lightning"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-deploy-command
  (concat dx-project-command-alias " " "deploy")
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-retrieve-command
  (concat dx-project-command-alias " " "retrieve")
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-default-browser "qutebrowser"
  "Browser use for open url"
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-metadata-root-dir "force-app/main/default"
  "Root Salesforce directory"
  :type 'string
  :group 'dx-minor-mode)

(defvar dx-trigger-dir "force-app/main/default/triggers"
  "Path save apex classes")

(defvar dx-default-apex-class-path "force-app/main/default/classes"
  "Path save apex classes")

(defvar dx-default-lwc-path "force-app/main/default/lwc"
  "Path save lwc components")

(defvar dx-default-aura-path "force-app/main/default/aura"
  "Path save aura components")

(defvar dx-default-vf-path "force-app/main/default/pages"
  "Path save visualforce page")

(defvar dx-default-vf-components-path "force-app/main/default/components"
  "Path save visualforce page")

(defvar dx-default-test-path "force-app/main/default/lightningTests"
  "Path save test components")

(defvar dx-default-object-path "force-app/main/default/objects"
  "Path save object metadata.")

(defvar dx-package-dir "manifest"
  "Custom define api version for command")

(defcustom dx-org-cache-dir ".cache/"
  "Directory to store cache files."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-dedicated-window-right "*List View*"
  "Name of dedicated window buffer on right."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-tracking-time-format "%Y-%m-%d %H:%M:%S"
  "format of time show on tracking metadata buffer."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-process-buffer "*DX Process*"
  "name of process buffer."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-process-success-buffer "DX Success"
  "name of process success buffer."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-process-error-buffer "DX Error"
  "name of process error buffer."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-config '()
  "List of config in project
   Ex: ((:project \"test\" :note-file \"org\" ))"
  :type 'list
  :group 'dx-minor-mode)

(defcustom dx-org-name ""
  "org name showing on mode line."
  :type 'string)

(defcustom dx-prefix-keymap "M"
  "Prefix for salesforce dx commands."
  :type 'string
  :group 'dx-config)

(defvar-local dx-project-root-dir ""
  "Full path project root.")

(defvar dx-mode-line `(:eval (when (bound-and-true-p dx-minor-mode)
                               (propertize (concat dx-mode-line-icon " "
                                                   (cond ((string-blank-p dx-org-name) "")
                                                         (t dx-org-name)))
                                           'face 'dx-mode-line-face)))
  "Salesfoce mode line.")

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
  "Path of directory log."
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

(defun dx-core--get-data-json (path table)
  "Get all data follow the path in hash table"
  (let* ((path-splited (split-string path "\\."))
         (key (car path-splited))
         (value (cond
                 ((plistp table)
                  (plist-get table key (lambda (prop key)
                                         (string= (format ":%s" key) (symbol-name prop)))))
                 ((arrayp table)
                  (aref table (string-to-number key)))
                 (t
                  (gethash key table))))
         (key-remain (cdr path-splited)))

    (cond (key-remain
           (dx-core--get-data-json
            (string-join key-remain ".")
            value))
          (t
           value))))

(defun dx-find-root-dir ()
  (cdr (project-current)))

(defun dx-core--build-path (&rest args)
  (mapconcat 'identity `(,(dx-find-root-dir) ,@args)))

;;;###autoload
(cl-defun dx-internal-current-org ()
  (let* ((root-dir (dx-find-root-dir))
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
                                 (dx-make-process-json-sync
                                  :cmd (dx-build-sf-command "config" "get" "target-org" "--json")))))))))

(defun dx--get-cache-folder-path ()
  "Get absolute path of cache directory."
  (let ((cache-dir (expand-file-name (concat dx-org-cache-dir dx-org-name "/") (dx-find-root-dir))))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir 'parents))

    cache-dir))

(defun dx--get-log-dir-path ()
  "Get absolute path of log directory."
  (let ((cache-dir (expand-file-name (concat dx-log-dir-path "/") (dx-find-root-dir))))

    (unless (file-exists-p cache-dir)
      (make-directory cache-dir 'parents))

    cache-dir))

(defmacro dx--find-backup-files (file-name &optional dir)
  "Find backup files."
  `(when-let* ((org-name dx-org-name)
               (default-directory (or ,dir (dx--get-cache-folder-path))))

     (directory-files-recursively default-directory
                                  ,file-name)))

(defmacro dx--find-backup-file (file-name &optional dir)
  "Find backup file."
  `(car (dx--find-backup-files ,file-name ,dir)))

(defun dx--org-status (&optional org)
  "Check current org status."
  (let ((json-instance (dx-make-process-json-sync
                        :cmd (append (dx-build-sf-command dx-org-command-alias "display" "--json")
                                     (when org (list "-o" org))))))
    (cond ((= (plist-get json-instance :status) 0)
           (dx-core--get-data-json "result.connectedStatus" json-instance))
          (t (funcall #'dx-handle-process-error--json json-instance)))))

(defun dx--get-lwc-directory ()
  "Get lwc directory."
  (expand-file-name dx-default-lwc-path (dx-find-root-dir)))

(defun dx--find-parents (file &optional depth)
  "Find parents of directory."
  (if (< depth 1)
      (file-name-directory (directory-file-name file))
    (dx--find-parents (file-name-directory (directory-file-name file)) (- depth 1))))

(cl-defmacro dx-core--project-process (&rest body &key cmd &allow-other-keys)
  "Start project process."
  `(let* ((callback (lambda (json-instance)
                      ,@body))
          (handle-callback (lambda (proc)
                             (funcall callback (dx-parse-buffer-json (process-buffer proc))))))
     (apply #'dx-start-process handle-callback (cons dx-project-command-alias ,cmd))))

(cl-defmacro dx-core--apex-process (&rest body &key cmd &allow-other-keys)
  "Start apex process."
  `(let* ((callback (lambda (json-instance)
                      ,@body))
          (handle-callback (lambda (proc)
                             (funcall callback (dx-parse-buffer-json (process-buffer proc))))))
     (apply #'dx-start-process handle-callback (cons dx-apex-command-alias ,cmd))))

(cl-defmacro dx-core--visualforce-process (&rest body &key cmd &allow-other-keys)
  "Start apex process."
  `(let* ((callback (lambda (json-instance)
                      ,@body))
          (handle-callback (lambda (proc)
                             (funcall callback (dx-parse-buffer-json (process-buffer proc))))))
     (apply #'dx-start-process handle-callback (cons dx-visualforce-command-alias ,cmd))))

(cl-defmacro dx-core--data-process (&rest body &key cmd &allow-other-keys)
  "Start data process."
  `(let* ((callback (lambda (json-instance)
                      ,@body))
          (handle-callback (lambda (proc)
                             (funcall callback (if (member "--json" ,cmd)
                                                   (dx-parse-buffer-json (process-buffer proc))
                                                 (process-buffer proc))))))
     (apply #'dx-start-process handle-callback (cons dx-data-command-alias ,cmd))))

(cl-defmacro dx-core--org-process (&rest body &key cmd &allow-other-keys)
  "Start org process."
  `(let* ((callback (lambda (json-instance)
                      ,@body))
          (handle-callback (lambda (proc)
                             (funcall callback (dx-parse-buffer-json (process-buffer proc))))))
     (apply #'dx-start-process handle-callback (cons dx-org-command-alias ,cmd))))

(cl-defmacro dx-core--lightning-process (&rest body &key cmd &allow-other-keys)
  "Start lightning process."
  `(let* ((callback (lambda (json-instance)
                      ,@body))
          (handle-callback (lambda (proc)
                             (funcall callback (dx-parse-buffer-json (process-buffer proc))))))
     (apply #'dx-start-process handle-callback (cons dx-lightning-command-alias ,cmd))))

(cl-defmacro dx-core--config-process (&rest body &key cmd &allow-other-keys)
  "Start lightning process."
  `(let* ((callback (lambda (json-instance)
                      ,@body))
          (handle-callback (lambda (proc)
                             (funcall callback (dx-parse-buffer-json (process-buffer proc))))))
     (apply #'dx-start-process handle-callback (cons "config" ,cmd))))

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

(cl-defmacro dx-process--make-handle-json (&rest body &key cmd &allow-other-keys)
  "Execute async dx cli command and return json result."
  `(let* ((callback (lambda (json-instance)
                      ,@body))
          (handle-callback (lambda (proc)
                             (funcall callback (dx-parse-buffer-json (process-buffer proc))))))
     (apply #'dx-start-process handle-callback ,cmd)))

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
  (message "%s" params)
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

;; Modify async package to handle signal process
(defun dx--async-when-done (proc &optional _change)
  "Handle signal process return from sf package."
  (when-let ((_ (eq (process-exit-status proc) 1))
             (_ (string= "dx-process" (process-name proc))))
    (condition-case error
        (dx-handle-process-error--json (dx-parse-buffer-json (process-buffer proc))))))

(advice-add 'async-when-done :after #'dx--async-when-done)

(provide 'dx-core)
