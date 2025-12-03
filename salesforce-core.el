;;; salesforce-core.el --- Core functionality for Salesforce integration -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Commentary:
;; This package provides core functionality for Salesforce integration in Emacs,
;; including process management, configuration, and utility functions.

;;; Code:

(require 'alert)
(require 'json)
(require 'async)
(require 'consult)

;;; Variables

(defvar salesforce-debug nil
  "Enable debug mode for Salesforce operations.")

(defvar salesforce-core--org-list-cache nil
  "Cache for org list data. Format: ((timestamp . org-list-data))")

(defvar salesforce-org-name nil
  "The name of the currently active Salesforce org, displayed in the mode line.")

(defvar-local salesforce-project-root-dir ""
  "Full path to project root.")

;;; Constants

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

;;; Customization

(defcustom salesforce-tangle-on-save t
  "When t, automatically tangle Org files on save."
  :type 'boolean
  :group 'salesforce-minor-mode)

(defcustom salesforce-api-version "61.0"
  "Custom define api version for command."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-program-bin "sf"
  "Path to Salesforce CLI."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-core--org-list-cache-ttl 300000
  "Time-to-live for org list cache in seconds."
  :type 'integer
  :group 'salesforce-minor-mode)

(defcustom salesforce-metadata-define-roots '((default . "force-app/main/default"))
  "List Root Salesforce directories."
  :type 'alist
  :group 'salesforce-minor-mode)

(defcustom salesforce-org-cache-dir ".cache/"
  "Directory to store cache files relative to the project root."
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

(defcustom salesforce-prefix-keymap "M"
  "The prefix key for Salesforce commands in the keymap."
  :type 'string
  :group 'salesforce-config)

(defcustom salesforce-log-dir-path ".sfdx/tools/debug/logs/"
  "Path to the directory where Salesforce debug logs are stored."
  :type 'string
  :group 'salesforce-config)

;;; Directory Variables

(defvar salesforce-metadata-root-dir "force-app/main/default"
  "Root Salesforce directory.")

(defvar salesforce-trigger-dir "triggers"
  "Path to save apex triggers.")

(defvar salesforce-apex-dir "classes"
  "Directory path for Apex classes.")

(defvar salesforce-lwc-dir "lwc"
  "Directory path for LWC components.")

(defvar salesforce-aura-dir "aura" 
  "Directory path for Aura components.")

(defvar salesforce-vf-dir "pages"
  "Directory path for Visualforce pages.")

(defvar salesforce-vf-component-dir "components"
  "Directory path for Visualforce components.")

(defvar salesforce-test-dir "lightningTests"
  "Directory path for test components.")

(defvar salesforce-object-dir "objects"
  "Directory path for object metadata.")

(defvar salesforce-package-dir "manifest"
  "Directory path for package manifest files.")

;;; Faces

(defface salesforce-mode-line-face
  '((((type graphic) (class color) (background dark))
     :foreground "DodgerBlue1" :slant oblique :weight bold)
    (((type graphic) (class color) (background light))
     :foreground "DodgerBlue4" :slant oblique :weight bold)
    (((type tty) (class color) (background dark))
     :foreground "DodgerBlue1" :slant oblique :weight bold)
    (t (:foreground "DodgerBlue1" :slant oblique :weight bold)))
  "Font lock for salesforce minor mode on mode line."
  :group 'font-lock-rules)

;;; Path Utilities

(defun salesforce-core--find-root-dir ()
  "Return the root directory of the current project using `project-current'."
  (cdr (project-current)))

(defun salesforce-core--tools-folder ()
  "Get tools folder path in project."
  (salesforce-core--join-path salesforce-state-dir "/" salesforce-tools-dir))

(defun salesforce-core--join-path (&rest args)
  "Build a full path from root directory and additional path components.
ARGS are the path components to join."
  (expand-file-name (string-join args "/")
                    (salesforce-core--find-root-dir)))

(defun salesforce-core--metadata-path (&optional path)
  "Return the full path for the metadata directory.
If PATH is non-nil, append it to the metadata root directory."
  (salesforce-core--join-path salesforce-metadata-root-dir (or path "")))

(defun salesforce--get-cache-folder-path ()
  "Get absolute path of cache directory."
  (let ((cache-dir (salesforce-core--join-path salesforce-org-cache-dir 
                                               salesforce-org-name)))
    (unless (file-exists-p cache-dir)
      (make-directory cache-dir 'parents))
    cache-dir))

(defun salesforce--ensure-directory-exists (path)
  "Create directory at PATH if it doesn't exist.
Returns PATH after ensuring it exists."
  (unless (file-exists-p path)
    (make-directory path 'parents))
  path)

(defun salesforce--get-log-dir-path ()
  "Get absolute path of log directory.
Creates the directory if it doesn't exist."
  (salesforce--ensure-directory-exists 
   (salesforce-core--join-path salesforce-log-dir-path)))

;;; File Utilities

(defun salesforce--find-files (files directory)
  "Find FILES in DIRECTORY.
FILES is a list of file names to search for.
Returns a list of full paths to matching files."
  (directory-files-recursively directory (regexp-opt files)))

(defun salesforce--find-file (file directory)
  "Find FILE in DIRECTORY.
Returns the first matching file path, or nil if not found."
  (when-let* ((files (salesforce--find-files `(,file) directory)))
    (car files)))

(defun salesforce--get-lwc-directory ()
  "Get LWC directory path."
  (expand-file-name salesforce-default-lwc-path (salesforce-core--find-root-dir)))

(defun salesforce--find-parents (file &optional depth)
  "Find parent directory of FILE at specified DEPTH.
If DEPTH is less than 1, returns the immediate parent directory."
  (if (< depth 1)
      (file-name-directory (directory-file-name file))
    (salesforce--find-parents 
     (file-name-directory (directory-file-name file)) 
     (- depth 1))))

;;; Process Management

(defmacro salesforce-core--make-process (command)
  "Create a process macro for a specific COMMAND type.
This generates a macro that can execute Salesforce CLI commands."
  `(cl-defmacro ,(intern (format "salesforce-core--%s-process" command))
       (&rest body &key args sync &allow-other-keys)
     (let ((action ,command))
       `(let* ((callback (lambda (proc)
                           (let ((json-instance 
                                  (if (member "--json" ,args)
                                      (salesforce-core-parse-buffer-json 
                                       (process-buffer proc))
                                    (process-buffer proc))))
                             ,@body))))
          (apply #'async-start-process 
                 salesforce-process-buffer
                 salesforce-program-bin 
                 (unless ,sync (apply-partially callback))
                 (cons ,action ,args))))))

;; Generate all process macros using the factory
(salesforce-core--make-process "project")
(salesforce-core--make-process "apex") 
(salesforce-core--make-process "visualforce")
(salesforce-core--make-process "data")
(salesforce-core--make-process "org")
(salesforce-core--make-process "lightning")
(salesforce-core--make-process "config")
(salesforce-core--make-process "cmdt")

;;; API Request

(defmacro salesforce-core--api-request (service)
  "Request to tooling API, wrap around request package.
SERVICE: name of API service."
  `(defun ,(intern (format "salesforce-core-%s-request" service))
       (endpoint &rest args)
     ,(format "Call API to %s service.

ENDPOINT: services of API.
ARGS: arguments passed to `request'." service)
     (apply #'request
            (format "%s/services/data/%s/%s"
                    salesforce-project-url
                    salesforce-api-version
                    ,service
                    endpoint)
            args)))

(salesforce-core--api-request "tooling")

;;; JSON Parsing

(defun salesforce-core-parse-buffer-json (buffer)
  "Parse JSON from BUFFER and return it as a hash table.
If parsing fails, return a hash table with status 1 and the raw buffer contents."
  (condition-case err
      (with-current-buffer buffer
        (goto-char (point-min))
        (json-parse-buffer :object-type 'hash-table))
    (error 
     (let ((ht (make-hash-table :test 'equal)))
       (puthash "status" 1 ht)
       (puthash "content" 
                (with-current-buffer buffer (buffer-string)) 
                ht)
       ht))))

;;; Error Handling

(defun salesforce-process--handle-error-metadata-action (json-instance)
  "Get error messages of metadata action from JSON-INSTANCE."
  (mapconcat 
   (lambda (component-error)
     (format "Metadata name: %s\nMetadata type: %s\nLine: %s\nError: %s"
             (map-elt component-error "fileName")
             (map-elt component-error "componentType")
             (map-elt component-error "lineNumber")
             (map-elt component-error "problem")))
   (map-nested-elt json-instance '("result" "details" "componentFailures"))
   "\n=======================\n"))

(defun salesforce-process--handle-common-error (json-instance)
  "Get common error message in fail operation from JSON-INSTANCE."
  (format "Name: %s\nMessage: %s" 
          (map-elt json-instance "name")
          (map-elt json-instance "message")))

(defun salesforce-handle-process-error--json (json-instance)
  "Handle error response by salesforce process from JSON-INSTANCE."
  (let ((show-message 
         (cond 
          ;; TODO: handle error based on type of action instead of status prop
          ((not (map-elt json-instance "context")) 
           (salesforce-process--handle-error-metadata-action json-instance))
          (t 
           (salesforce-process--handle-common-error json-instance)))))
    (salesforce-core--alert show-message :severity 'urgent)
    show-message))

(defun salesforce-core--async-when-done (proc &optional _change)
  "Handle signal process return from sf package.
PROC is the process that completed."
  (when-let ((_ (> (process-exit-status proc) 0))
             (_ (string-match-p salesforce-process-buffer 
                                (buffer-name (process-buffer proc)))))
    (condition-case error
        (salesforce-handle-process-error--json 
         (salesforce-core-parse-buffer-json (process-buffer proc))))))

(advice-add 'async-when-done :after #'salesforce-core--async-when-done)

;;; Project and Org Management

(defun salesforce-core--projects (prefix)
  "List projects that start with PREFIX."
  (-filter (lambda (project)
             (s-prefix-p prefix project))
           (projectile-relevant-known-projects)))

(defun salesforce-core--orgs (prefix)
  "List orgs that start with PREFIX.
Uses cached org list if available."
  (let ((async-debug t))
    (cl-reduce 
     (lambda (result org)
       (when-let* ((alias (map-elt org "alias"))
                   (_ (s-prefix-p prefix alias)))
         (setq result (append result `(,alias))))
       (when (null prefix)
         (setq result (append result `(,(map-elt org "alias")))))
       result)
     (cond ((assoc-default 'data salesforce-core--org-list-cache)
            (assoc-default 'data salesforce-core--org-list-cache))
           (t (or (salesforce-org-list nil :sync t) '())))
     :initial-value '())))

;;; Prompts and Completion

(defun salesforce-core--prompt (candidates &rest args)
  "Prompt to select from CANDIDATES.
ARGS are additional arguments passed to `consult--read'."
  (unless (plist-member args :prompt)
    (plist-put args :prompt "read: "))
  (unless (plist-member args :category)
    (plist-put args :category 'salesforce-prompt))
  (apply #'consult--read candidates args))

(defun salesforce-core--complete-candidate (candidates category input pred action)
  "Completion table for CANDIDATES.
CATEGORY is the completion category.
INPUT, PRED, ACTION according to `completing-read' contract."
  (if (eq action 'metadata)
      `(metadata (category . ,category))
    (complete-with-action action candidates input pred)))

;;; Consult Integration

(cl-defmacro salesforce-consult--define-source (prefix &rest args)
  "Define a consult source for Salesforce.
PREFIX is the mode/package prefix.
ARGS are the source definition arguments."
  (declare (indent defun))
  (let ((var-name (salesforce-consult--source-var-name prefix args)))
    `(defvar ,var-name
       (apply #'salesforce-consult--source ',args))))

(defun salesforce-consult--source-var-name (prefix args)
  "Generate variable name for consult source.
PREFIX is the mode/package prefix.
ARGS contains the source definition including :name."
  (let ((name (plist-get args :name)))
    (intern (format "%s--consult-%s-source" prefix (downcase name)))))

(defun salesforce-consult--source (&rest args)
  "Generate source list for consult.
ARGS are arguments applied for `consult--multi'."
  (append
   `(:name ,(capitalize (plist-get args :name))
           :narrow ,(plist-get args :narrow)
           :category ,(plist-get args :category)
           :face ,(plist-get args :face)
           :items ,(plist-get args :items))
   (when (plist-get args :annotate)
     `(:annotate ,(plist-get args :annotate)))
   (when (plist-get args :action)
     `(:action ,(plist-get args :action)))
   (when (plist-get args :state)
     `(:state ,(plist-get args :state)))))

(defun salesforce-consult--imenu-annotate (cand)
  "Annotate CAND for consult source."
  (pcase-let ((`(text . marker) cand))
    (propertize (concat "@" (car cand)) 'face 'font-lock-keyword-face)))

(defun salesforce-consult--imenu-action (candidate) 
  "Action for consult source.
CANDIDATE is the selected item to act upon."
  (goto-char (cdr candidate)))

(defun salesforce-consult--search-candidates (&rest body)
  "Search candidates with tree-sitter rule in the buffer.
BODY contains (name regexp icon pred name-fn) for the search."
  (pcase-let ((`(,name ,regexp ,icon ,pred ,name-fn) body))
    (when-let* ((tree (treesit-induce-sparse-tree 
                       (treesit-buffer-root-node) regexp))
                (candidates (treesit--simple-imenu-1 tree pred name-fn)))
      (salesforce-consult--format-candidates candidates name icon))))

(defun salesforce-consult--format-candidates (candidates name &optional icon)
  "Format CANDIDATES for consult.
NAME is the category name.
ICON is an optional icon to prepend to each candidate."
  (mapcar (lambda (candidate)
            (let ((display-text (if icon
                                    (propertize (concat icon " " (car candidate)))
                                  (car candidate))))
              `(,display-text . (,name . ,(cdr candidate)))))
          candidates))

(defun salesforce-consult--imenu-state ()
  "Handle imenu state for consult preview."
  (let ((preview (consult--jump-preview)))
    (lambda (action cand) 
      (funcall preview action (cdr cand)))))

(defmacro salesforce-consult-make-multi-imenu (language &rest consult-sources)
  "Create a consult Imenu for a major mode specified by LANGUAGE.
CONSULT-SOURCES are the sources to be used in the consult multi command."
  (let ((function-name (intern (format "%s-consult-multi-imenu" language))))
    `(defun ,function-name ()
       (interactive)
       (consult--multi ',consult-sources))))

;;; Display Utilities

(defun salesforce-core--box-table (&rest rows)
  "Pretty print ROWS as a box-drawing table with headers on left."
  (let* ((width-col1 (apply #'max 
                            (mapcar (lambda (row) (string-width (car row))) 
                                    rows)))
         (width-col2 (apply #'max 
                            (mapcar (lambda (row) 
                                      (string-width (format "%s" (cdr row)))) 
                                    rows)))
         (hline (concat "╠" (make-string (+ width-col1 2) ?═) 
                        "╬" (make-string (+ width-col2 2) ?═) "╣"))
         (top   (concat "╔" (make-string (+ width-col1 2) ?═) 
                        "╦" (make-string (+ width-col2 2) ?═) "╗"))
         (bot   (concat "╚" (make-string (+ width-col1 2) ?═) 
                        "╩" (make-string (+ width-col2 2) ?═) "╝"))
         (content (mapconcat
                   (lambda (row)
                     (format "║ %s │ %s ║"
                             (string-pad (car row) width-col1)
                             (string-pad (format "%s" (cdr row)) width-col2)))
                   rows
                   (concat "\n" hline "\n"))))
    (concat top "\n" content "\n" bot)))

(defun salesforce-core--pop-box-table (&rest rows)
  "Popup ROWS as table by using `salesforce-core--box-table'."
  (with-output-to-temp-buffer "*Salesforce Box Table*"
    (insert (apply #'salesforce-core--box-table rows))))

;;; Keymap Utilities

(defun salesforce-core--make-keymap (&rest collection)
  "Return a sparse keymap built from COLLECTION.
Each element is (KEY CMD DES) where KEY is the key binding,
CMD is the command, and DES is the which-key description." 
  (let ((map (make-sparse-keymap)))
    (dolist (seq collection)
      (pcase-let* ((`(,key ,command ,which-key) seq)
                   (bind (if which-key
                             (cons which-key command)
                           command)))
        (cond
         ((stringp key) (keymap-set map key bind))
         ((vectorp key) (keymap-set map key bind))
         (t (keymap-set map key bind)))))
    map))

;;; Alert

(defun salesforce-core--alert (message &rest args)
  "Display an alert with MESSAGE and optional ARGS.
This function uses the `alert` package to show notifications."
  (unless (plist-member args :title)
    (plist-put args :title (projectile-project-name)))
  (unless (plist-member args :icon)
    (plist-put args :icon "apex"))
  (apply #'alert message args))

(provide 'salesforce-core)

;;; salesforce-core.el ends here
