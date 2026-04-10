;;; salesforce-core.el --- Core functionality for Salesforce integration -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Commentary:
;; This package provides core functionality for Salesforce integration in Emacs,
;; including process management, configuration, and utility functions.

;;; Code:

(require 'alert)
(require 'json)
(require 'consult)
(require 'emacs-pipeline-process)

;;; Variables

(defvar salesforce-debug nil
  "Enable debug mode for Salesforce operations.")

(defvar-local salesforce-project-root-dir nil
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

(defcustom salesforce-api-version "61.0"
  "Custom define api version for command."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom salesforce-program-bin "sf"
  "Path to Salesforce CLI."
  :type 'string
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

(defcustom salesforce-prefix-keymap "M"
  "The prefix key for Salesforce commands in the keymap."
  :type 'string
  :group 'salesforce-config)

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

(defun salesforce-core--parse-json (process)
  "Parse result return from PROCESS."
  (let ((json-object-type 'hash-table)
        (json-null nil))
    (emacs-pp-parser-json process)))

(defun salesforce--ensure-directory-exists (path)
  "Create directory at PATH if it doesn't exist.
Returns PATH after ensuring it exists."
  (unless (file-exists-p path)
    (make-directory path 'parents))
  path)

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

(defun salesforce--find-parents (file &optional depth)
  "Find parent directory of FILE at specified DEPTH.
If DEPTH is less than 1, returns the immediate parent directory."
  (if (< depth 1)
      (file-name-directory (directory-file-name file))
    (salesforce--find-parents 
     (file-name-directory (directory-file-name file)) 
     (- depth 1))))

;;; Process Management

(cl-defun salesforce-core-run-process (&key args parser callback)
  "Run Salesforce CLI COMMAND with ARGS.
CALLBACK receives parsed JSON (or raw output) on completion.
If SYNC is non-nil, wait for process to complete and return result."
  (emacs-pp-make-process-wrap
   (make-process
    :name salesforce-process-buffer
    :buffer (generate-new-buffer
             (format "*%s*" salesforce-process-buffer)))
   :cmd (cons salesforce-program-bin args)
   :parser parser
   :then
   (cl-function
    (lambda (&key data &allow-other-keys)
      (if callback
          (funcall callback data)
        data)))
   :catch #'salesforce-core--handle-process-error))

(defun salesforce-core--handle-process-error (err)
  "Handle process error ERR."
  (salesforce-core--alert (format "Process error: %s" err) :severity 'urgent))

(cl-defun salesforce-core--project-process
    (&key args callback (parser #'salesforce-core--parse-json))
  "Run Salesforce project CLI command with ARGS."
  (salesforce-core-run-process :args (cons "project" args)
                               :callback callback))

(cl-defun salesforce-core--apex-process
    (&key args callback (parser #'salesforce-core--parse-json))
  "Run Salesforce apex CLI command with ARGS."
  (salesforce-core-run-process :args (cons "apex" args)
                               :parser parser
                               :callback callback))

(cl-defun salesforce-core--visualforce-process
    (&key args callback (parser #'salesforce-core--parse-json))
  "Run Salesforce visualforce CLI command with ARGS."
  (salesforce-core-run-process :args (cons "visualforce" args)
                               :parser parser
                               :callback callback))

(cl-defun salesforce-core--data-process
    (&key args callback (parser #'salesforce-core--parse-json))
  "Run Salesforce data CLI command with ARGS."
  (salesforce-core-run-process :args (cons "data" args)
                               :parser parser
                               :callback callback))

(cl-defun salesforce-core--org-process
    (&key args callback (parser #'salesforce-core--parse-json))
  "Run Salesforce org CLI command with ARGS."
  (salesforce-core-run-process :args (cons "org" args)
                               :parser parser
                               :callback callback))

(cl-defun salesforce-core--lightning-process
    (&key args callback (parser #'salesforce-core--parse-json))
  "Run Salesforce lightning CLI command with ARGS."
  (salesforce-core-run-process :args (cons "lightning" args)
                               :parser parser
                               :callback callback))

(cl-defun salesforce-core--config-process
    (&key args callback (parser #'salesforce-core--parse-json))
  "Run Salesforce config CLI command with ARGS."
  (salesforce-core-run-process :args (cons "config" args)
                               :parser parser
                               :callback callback))

(cl-defun salesforce-core--cmdt-process
    (&key args callback (parser #'salesforce-core--parse-json))
  "Run Salesforce cmdt CLI command with ARGS."
  (salesforce-core-run-process :args (cons "cmdt" args)
                               :parser parser
                               :callback callback))

(cl-defun salesforce-core--sobject-process
    (&key args callback (parser #'salesforce-core--parse-json))
  "Run Salesforce sobject CLI command with ARGS."
  (salesforce-core-run-process :args (cons "sobject" args)
                               :parser parser
                               :callback callback))

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

;;; Get Org Name

;;; JSON Parsing

(defun salesforce-core-parse-buffer-json (buffer)
  "Parse JSON from BUFFER and return it as a hash table.
If parsing fails, return a hash table with status 1 and the raw buffer contents. (obsolete)"
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

;;; Project and Org Management

(defun salesforce-core--projects (prefix)
  "List projects that start with PREFIX."
  (-filter (lambda (project)
             (s-prefix-p prefix project))
           (projectile-relevant-known-projects)))

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
BODY contains (name regexp icon pred name-fn) for the search. (obsolete)"
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
  (unless (string-empty-p message)
    (apply #'alert message args)))

(provide 'salesforce-core)

;;; salesforce-core.el ends here
