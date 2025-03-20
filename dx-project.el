;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
;;; Code
(require 'projectile)

(require 'dx-core)
(require 'dx-core)
(require 'transient)

(defcustom dx-files-test-root '(".forceignore")
  "The list of files to determine a project is Salesforce project."
  :type 'list
  :group 'salesforce-project)

(defcustom dx-project-configuration '((nil . ((eval . (dx-minor-mode 1)))))
  "The list of configuration for Salesforce project."
  :type 'list
  :type 'salesforce-project)

;;;###autoload
(defun dx-project-p (&optional dir)
  "Check root is Salesforce project."
  (let ((default-directory (or dir (projectile-project-root)))
        (project-pass nil))

    (dolist (file dx-files-test-root)
      (setq project-pass (or project-pass (projectile-verify-file-wildcard file))))
    project-pass))

;;;###autoload
(defun dx-project-init ()
  "Initialize configuarion for Salesforce project."
  (when (eq (projectile-project-type) 'dx)
    (dir-locals-set-class-variables 'project-configuration dx-project-configuration)
    (dir-locals-set-directory-class (projectile-project-root) 'project-configuration)))

;; Define own projectile
(with-eval-after-load 'projectile
  (projectile-register-project-type 'dx #'dx-project-p
                                    :project-file "package.json"
                                    :compile "npm install")

  ;; Add initialize salesforce for projectile
  (add-hook 'projectile-after-switch-project-hook #'dx-project-init))


(defun dx-project-create ()
  "Create dx project"
  (interactive)
  (let* ((project-dir (read-directory-name "Directory: "))
         (project-name (read-string "Project name: "))
         (project-template (completing-read "Project template: " (list "standard" "empty" "project")))
         (default-directory project-dir))

    (make-directory project-dir 'parents)

    (dx-core--project-process 
     :cmd (list "generate" "--name" project-name "--template" project-template "--json")
     (alert "Create Project Success"
            :title "DX Alert"))))

(defun dx-project-source-push (buffer)
  "Push file to salesforce org."
  (interactive (list (buffer-file-name)))
  (dx-core--project-process 
   :cmd (list "deploy" "start" "-d" buffer "--json")
   (alert (format "Deploy %s success" buffer)
          :title "DX Alert")))

(defun dx-project-source-retrieve (buffer)
  "Retrieve source salesforce form org"
  (interactive (list (buffer-file-name)))
  (dx-core--project-process 
   :cmd (list "retrieve" "start" "-d" buffer "--json")
   (alert (format "Retrieve %s success" buffer)
          :title "DX Alert")))


(cl-defmacro dx-source-backup (&rest body &key target-org &allow-other-keys)
  "Backup the current buffer to the source directory."
  `(let* ((buffer (buffer-file-name))
          (file-name (file-name-base buffer))
          (cache-dir (dx--get-cache-folder-path))
          (backup-file-name (concat file-name "_" (format "%s" (time-convert (current-time) 'integer)))))

     (unless (file-exists-p cache-dir)
       (make-directory cache-dir 'parents))

     (dx-core--project-process 
      :cmd (list "retrieve"
              "start"
              "-d" buffer
              "-z"
              "-t" cache-dir
              "--zip-file-name" backup-file-name
              "-o" (or ,target-org dx-org-name)
              "--json")
      (unless json-instance
        (error (concat "Backup " file-name " Failure")))
      ;; rename backup directory to new directory containing the last modified id
      ;; and the last modified date

      (when-let ((new-dir-name (concat cache-dir "/" backup-file-name "_"
                                       (dx-core--get-data-json "result.fileProperties.0.lastModifiedById"
                                                               json-instance)
                                       "_"
                                       (format "%s" (time-convert (date-to-time (dx-core--get-data-json "result.fileProperties.0.lastModifiedDate" json-instance))
                                                                  'integer)))))
        (rename-file (concat cache-dir "/" backup-file-name)
                     new-dir-name)
        ,@body))))

(defun dx-project--ediff-startup-hook ()
  "Ediff hook on startup."
  (let* ((coding-system (with-current-buffer ediff-buffer-B
                          buffer-file-coding-system)))

    ;; Set coding for buffer A
    (with-current-buffer ediff-buffer-A
      (set-buffer-file-coding-system coding-system t t))
    (ediff-toggle-read-only ediff-buffer-A)

    (when ediff-buffer-C
      ;; Set coding for buffer C
      (with-current-buffer ediff-buffer-C
        (set-buffer-file-coding-system coding-system t t))

      (ediff-toggle-read-only ediff-buffer-C))

    (ediff-update-diffs)))

(defun dx-project--ediff-quit-hook ()
  "Hook on quit."
  (with-current-buffer ediff-buffer-A
    (kill-buffer-and-window))
  (when ediff-buffer-C
    (with-current-buffer ediff-buffer-C
      (kill-buffer-and-window)))

  ;; Clear hooks
  (remove-hook 'ediff-startup-hook #'dx-project--ediff-startup-hook)
  (remove-hook 'ediff-quit-hook #'dx-project--ediff-quit-hook))

(defun dx-diff-metadata-other-org ()
  "diff metadata between local and cloud."
  (interactive)
  (dx-org--fetch-org-list
   (let* ((full-file-name (buffer-file-name))
          (org (completing-read "Target Org: " org-list nil 'require-match))
          (org-status (dx--org-status org)))

     (unless (string= org-status "Connected"))
     ;;(dx-authen))

     (dx-source-backup
      :target-org org
      (condition-case error
          (ediff (dx--find-backup-file (file-name-nondirectory full-file-name)
                                       new-dir-name)
                 full-file-name
                 '((lambda ()
                     (add-hook 'ediff-startup-hook #'dx-project--ediff-startup-hook)
                     (add-hook 'ediff-quit-hook #'dx-project--ediff-quit-hook))))
        (error
         (alert (format "%s" error)
                :title "DX Alert"
                :severity 'urgent)))))))

(defun dx-diff3-metadata ()
  "diff metadata between three enviroments."
  (interactive)
  (let* ((minibuffer-history (dx-org--fetch-org-list))
         (file-name (buffer-file-name))
         (target-org (read-from-minibuffer "Target Org: "))
         (bk-file-org (dx-source-backup))
         (bk-file-target-org (dx-source-backup
                              :target-org target-org)))

    (condition-case error
        (ediff3 (car (directory-files-recursively (concat bk-file-org "/") (file-name-nondirectory file-name))) file-name (car (directory-files-recursively (concat bk-file-target-org "/") (file-name-nondirectory file-name)))
                '((lambda ())
                  (add-hook 'ediff-startup-hook #'dx-project--ediff-startup-hook)
                  (add-hook 'ediff-quit-hook #'dx-project--ediff-quit-hook)))
      (error
       (alert error
              :title "DX Alert"
              :severity 'urgent)))))

(defun dx-source-tracker ()
  (interactive)
  (let* ((folder-name (file-name-base buffer-file-name))
         (file-name (file-name-nondirectory buffer-file-name))
         (dx-dedicated-window-right "*Org Tracker*")
         (source-list (dx--find-backup-files (format "%s$" file-name)))
         (model
          (dx-table--make-table-mode
           :column-header
           `((:title "Backup DateTime")
             (:title "User Modified Id")
             (:title "Last Modified"))
           :data
           (cl-remove-if 'nil
                         (mapcar (lambda (file)
                                   ;; format files show on buffer
                                   (when-let* ((source-dir (file-name-base (dx--find-parents file 3)))
                                               (data (string-split source-dir "_"))
                                               (date-time (format-time-string "%Y/%m/%d %H:%M:%S" (string-to-number (nth 0 data))))
                                               (user-id (nth 1 data))
                                               (last-modified-date (format-time-string "%Y/%m/%d %H:%M:%S" (string-to-number (nth 2 data)))))

                                     `(,date-time ,user-id ,last-modified-date ,(concat (nth 3 data) "_" (nth 0 data) "_" user-id "_" (nth 2 data)))))
                                 ;; list of file names
                                 source-list))))
         (component
          (dx-table--create-table
           :model model
           :buffer dx-dedicated-window-right)))

    (ctbl:cp-add-click-hook component
                            `(lambda ()
                               (when-let* ((data (ctbl:cp-get-selected-data-row ,component))
                                           (cache-dir (concat (dx--get-cache-folder-path)
                                                              (nth 3 data)))))
                               (ediff (car (directory-files-recursively cache-dir ,file-name))
                                      ,buffer-file-name
                                      '((lambda ()
                                          (add-hook 'ediff-startup-hook #'dx-project--ediff-startup-hook)
                                          (add-hook 'ediff-quit-hook #'dx-project--ediff-quit-hook))))))

    (pop-to-buffer (ctbl:cp-get-buffer component))))

(defun dx-project--push-multi-sources (files)
  "Push multi metadata files to org."
  (interactive (list (transient-args 'dx-project--deploy-files-menu)))
  (async-start `(lambda ()
                  ;; set default directory run command
                  (setq default-directory ,(projectile-project-root))
                  ;; loading library
                  ,(async-inject-variables "\\`load-path\\'")
                  (require 'async nil t)
                  (require 'dx-project nil t)
                  (require 'cl-macs nil t)
                  (setq async-debug t)
                  (let ((proc (apply #'dx-start-process nil 
                                     (append '(,dx-project-command-alias "deploy" "start" "--json") 
                                             (cons "-d" ',files)))))
                    (async-wait proc)
                    (if (eq (process-exit-status proc) 1)
                        (list :status 1 :error (dx--async-when-done proc))
                      (list :status 0 :json-instance (dx-parse-buffer-json (process-buffer proc))))))
               (lambda (result)
                 (when (eq (plist-get result :status) 0)
                   (alert (concat "Success deploy files:\n"
                                  (string-join files "\n"))
                          :title "DX Alert")))))

(defun dx-project--retrieve-multi-sources (files)
  "Push multi metadata files to org."
  (interactive (list (transient-args 'dx-project--deploy-files-menu)))
  (async-start `(lambda ()
                  ;; set default directory run command
                  (setq default-directory ,(projectile-project-root))
                  ;; loading library
                  ,(async-inject-variables "\\`load-path\\'")
                  (require 'async nil t)
                  (require 'dx-project nil t)
                  (require 'cl-macs nil t)
                  (let ((proc (apply #'dx-start-process nil 
                                     (append '(,dx-project-command-alias "retrieve" "start" "--json") 
                                             (cons "-d" ',files)))))
                    (async-wait proc)
                    (if (eq (process-exit-status proc) 1)
                        (list :status 1 :error (dx--async-when-done proc))
                      (list :status 0 :json-instance (dx-parse-buffer-json (process-buffer proc))))))
               (lambda (result)
                 (when (eq (plist-get result :status) 0)
                   (alert (concat "Success retrieve files:\n"
                                  (string-join files "\n"))
                          :title "DX Alert")))))

(defun dx-project--group-files-menu (files)
  "Group files on transient menu."
  (cl-loop for file in files
           if (and (string-match-p (regexp-quote dx-default-apex-class-path) file)
                   (not (member (dx-project--remove-xml-suffix file) classes)))
           collect (dx-project--remove-xml-suffix file) into classes
           else if (and (string-match-p (regexp-quote dx-default-vf-path) file)
                        (not (member (dx-project--remove-xml-suffix file) pages)))
           collect (dx-project--remove-xml-suffix file) into pages
           else if (string-match-p (concat dx-default-object-path "/[A-Za-z_]+/fields") file)
           collect file into fields
           else if (string-match-p (regexp-quote dx-default-object-path) file)
           collect (dx-project--remove-xml-suffix file) into objects
           ;; else 
           ;; collect file into other
           finally return (list (cons "classes" classes) 
                                (cons "pages" pages)
                                (cons "objects" objects)
                                (cons "fields" fields)
                                ;; (cons "Misc" other)
                                )))

(defun dx-project--remove-xml-suffix (original-name)
  "Format name of item display on transient menu."
  (string-replace "-meta.xml" "" original-name))

(defun dx-project--generate-files-menu (prefix-name files &rest sections)
  "Configuration deploy files change menu."
  `(transient-define-prefix ,(intern (concat "dx-project--" prefix-name)) ()
     "Files deploy menu."
     ,@(cl-loop for (name . items) in (dx-project--group-files-menu files)
                as section = (vconcat (list (capitalize name))
                                      (cl-loop for chunk in (dx-project--generate-files-section items (substring name 0 1))
                                               as col = (vconcat "" chunk)
                                               vconcat col))
                collect section)
     ,@sections))

(defun dx-project--generate-files-section (files prefix &optional max-row)
  "Generate column dilay files."
  (seq-split (cl-loop for index from 1
                      for file in files
                      as file-name = (file-name-base file)
                      as file-name-ext = (concat file-name (file-name-extension file))
                      when (not (string= file-name ""))
                      collect (list (format "%s%s" prefix index) file-name file :transient t)) 
             (or max-row 5)))

(defun dx-project--git-change-source-1 ()
"Deploy changed sources on local to org."
(require 'magit nil t)
(let ((target-branch (magit-read-local-branch "Branch" (magit-local-branch-at-point))))
  (async-start 
   `(lambda ()
      ;;,(async-inject-variables "\\`load-path\'")
      (setq default-directory ,(projectile-project-root))
      (shell-command-to-string (format "git diff $(git reflog --date=local %s | tail -n 1 | cut -d' ' -f 1) %s --name-only" ,target-branch ,target-branch)))
   (lambda (files-string)
     (let ((files (split-string files-string "\n")))
       (eval (dx-project--generate-files-menu "deploy-files-menu" files 
                                              ["" 
                                               ("d" "Push sources" dx-project--push-multi-sources)
                                               ("r" "Sync sources" dx-project--retrieve-multi-sources)]))
       (transient-setup 'dx-project--deploy-files-menu))))))

(defun dx-project-git-change-source ()
  "View all sources changed on version control."
  (interactive)
  (dx-project--git-change-source-1))

(defun dx-open-project-note ()
  "Open note for current project."
  (interactive)
  (if-let ((note-file (plist-get (cl-find-if (lambda (el)
                                               (string= (expand-file-name (plist-get el :project)) dx-project-root-dir))
                                             dx-project-config)
                                 :note-file)))

      (display-buffer-in-side-window (find-file-noselect
                                      (expand-file-name note-file))
                                     '((side . right)
                                       (window-width . 0.4)))
    (error "note file not found.")))

;; Select section to deploy
;; use command convert metadata in cache to deploy able data?
;; support apex only now

(defun dx-org-preview-metadata-change ()
  "diff source between local project and salesforce platform."
  (interactive)
  (let ((full-file-name (buffer-file-name)))

    (dx-source-backup
     (condition-case error
         (ediff (dx--find-backup-file (file-name-nondirectory full-file-name)
                                      new-dir-name)
                full-file-name
                `((lambda ()
                    (add-hook 'ediff-quit-hook #'dx-project--ediff-quit-hook)
                    (add-hook 'ediff-startup-hook #'dx-project--ediff-startup-hook))))
       (error
        (alert (format "%s" error)
               :title "DX Alert"
               :severity 'urgent))))))

(provide 'dx-project)
