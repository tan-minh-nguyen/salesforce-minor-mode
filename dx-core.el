;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-config)
(require 'dx-process)

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

(provide 'dx-core)
